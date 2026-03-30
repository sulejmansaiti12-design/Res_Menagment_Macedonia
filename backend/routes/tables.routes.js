const express = require('express');
const router = express.Router();
const { Table, Zone, TableSession } = require('../models');
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError } = require('../utils/errors');
const qrService = require('../services/qr.service');

// GET /api/tables
router.get('/', authenticate, asyncHandler(async (req, res) => {
  const { zoneId } = req.query;
  const where = { isActive: true };
  if (zoneId) where.zoneId = zoneId;

  const tables = await Table.findAll({
    where,
    include: [
      { model: Zone, as: 'zone' },
      {
        model: TableSession, as: 'sessions',
        where: { isActive: true },
        required: false
      }
    ],
    order: [['name', 'ASC']]
  });

  res.json({ success: true, data: { tables } });
}));

// GET /api/tables/:id
router.get('/:id', authenticate, asyncHandler(async (req, res) => {
  const table = await Table.findByPk(req.params.id, {
    include: [
      { model: Zone, as: 'zone' },
      {
        model: TableSession, as: 'sessions',
        where: { isActive: true },
        required: false
      }
    ]
  });
  if (!table) throw new NotFoundError('Table not found');

  res.json({ success: true, data: { table } });
}));

// POST /api/tables
router.post('/', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { name, zoneId } = req.body;
  if (!name || !zoneId) throw new BadRequestError('Table name and zone ID are required');

  const zone = await Zone.findByPk(zoneId);
  if (!zone) throw new NotFoundError('Zone not found');

  const qrToken = qrService.generateNewToken();
  const table = await Table.create({ name, zoneId, qrToken });

  // Generate QR code
  const qr = await qrService.generateQRCode(table.id, qrToken);

  res.status(201).json({
    success: true,
    data: { table, qrCode: qr.qrImage }
  });
}));

// PUT /api/tables/:id
router.put('/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const table = await Table.findByPk(req.params.id);
  if (!table) throw new NotFoundError('Table not found');

  const { name, zoneId, isActive } = req.body;
  if (zoneId) {
    const zone = await Zone.findByPk(zoneId);
    if (!zone) throw new NotFoundError('Zone not found');
  }

  await table.update({ name, zoneId, isActive });
  res.json({ success: true, data: { table } });
}));

// DELETE /api/tables/:id
router.delete('/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const table = await Table.findByPk(req.params.id);
  if (!table) throw new NotFoundError('Table not found');

  await table.update({ isActive: false });
  res.json({ success: true, message: 'Table deactivated' });
}));

// GET /api/tables/:id/qr - Regenerate QR code
router.get('/:id/qr', authenticate, asyncHandler(async (req, res) => {
  const table = await Table.findByPk(req.params.id);
  if (!table) throw new NotFoundError('Table not found');

  const qr = await qrService.generateQRCode(table.id, table.qrToken);
  res.json({ success: true, data: { qrCode: qr.qrImage, qrData: qr.qrData } });
}));

// GET /api/tables/:id/alerts - Fetch pending orders and notifications
router.get('/:id/alerts', authenticate, asyncHandler(async (req, res) => {
  const { Order, Notification, OrderItem, MenuItem } = require('../models');
  
  const pendingOrders = await Order.findAll({
    where: { status: 'pending' },
    include: [
      {
        model: require('../models').TableSession,
        as: 'tableSession',
        where: { tableId: req.params.id, isActive: true }
      },
      {
        model: OrderItem,
        as: 'items',
        include: [{ model: MenuItem, as: 'menuItem' }]
      }
    ],
    order: [['createdAt', 'DESC']]
  });

  const table = await Table.findByPk(req.params.id);
  const notifications = await Notification.findAll({
    where: { 
      zoneId: table ? table.zoneId : null,
      isRead: false,
    },
    order: [['createdAt', 'DESC']]
  });

  const tableNotifications = notifications.filter(n => n.data && n.data.tableId === req.params.id);

  res.json({ success: true, data: { pendingOrders, notifications: tableNotifications } });
}));

// GET /api/tables/:id/session - Fetch current session and existing orders
router.get('/:id/session', authenticate, asyncHandler(async (req, res) => {
  const { Order, OrderItem, MenuItem } = require('../models');

  const session = await TableSession.findOne({
    where: { tableId: req.params.id, isActive: true }
  });

  if (!session) {
    return res.json({ success: true, data: { session: null, existingOrders: [] } });
  }

  const existingOrders = await Order.findAll({
    where: { 
      tableSessionId: session.id,
      status: { [require('sequelize').Op.notIn]: ['paid', 'cancelled'] }
    },
    include: [{
      model: OrderItem,
      as: 'items',
      include: [{ model: MenuItem, as: 'menuItem' }]
    }],
    order: [['createdAt', 'DESC']]
  });

  res.json({ success: true, data: { session, existingOrders } });
}));

// ═══════════════════════════════════════════════════════════════════
// FLOOR PLAN — Position Management
// ═══════════════════════════════════════════════════════════════════

// PATCH /api/tables/:id/position — Update single table position
router.patch('/:id/position', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { posX, posY, width, height, shape, rotation, capacity } = req.body;
  const table = await Table.findByPk(req.params.id);
  if (!table) throw new NotFoundError('Table not found');

  if (posX !== undefined) table.posX = posX;
  if (posY !== undefined) table.posY = posY;
  if (width !== undefined) table.width = width;
  if (height !== undefined) table.height = height;
  if (shape !== undefined) table.shape = shape;
  if (rotation !== undefined) table.rotation = rotation;
  if (capacity !== undefined) table.capacity = capacity;

  await table.save();
  res.json({ success: true, data: { table } });
}));

// PATCH /api/tables/bulk-positions — Save entire floor layout at once
router.patch('/bulk-positions', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { tables } = req.body; // Array of { id, posX, posY, width, height, shape, rotation }
  if (!Array.isArray(tables) || tables.length === 0) {
    throw new BadRequestError('Tables array is required');
  }

  const sequelize = require('../config/database');
  const t = await sequelize.transaction();
  try {
    for (const item of tables) {
      await Table.update(
        {
          posX: item.posX,
          posY: item.posY,
          width: item.width,
          height: item.height,
          shape: item.shape,
          rotation: item.rotation
        },
        { where: { id: item.id }, transaction: t }
      );
    }
    await t.commit();
    res.json({ success: true, message: `Updated ${tables.length} table positions` });
  } catch (err) {
    await t.rollback();
    throw err;
  }
}));

module.exports = router;
