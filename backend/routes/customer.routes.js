const express = require('express');
const router = express.Router();
const { Table, TableSession, Zone, Category, MenuItem, Order, OrderItem, OrderDestination, Notification, Shift } = require('../models');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError } = require('../utils/errors');
const sseService = require('../services/sse.service');
const sequelize = require('../config/database');

// GET /api/customer/table/:qrToken - Scan QR code / enter table
router.get('/table/:qrToken', asyncHandler(async (req, res) => {
  const table = await Table.findOne({
    where: { qrToken: req.params.qrToken, isActive: true },
    include: [{ model: Zone, as: 'zone' }]
  });
  if (!table) throw new NotFoundError('Invalid QR code or table not found');

  // Find or create active session
  let session = await TableSession.findOne({
    where: { tableId: table.id, isActive: true }
  });

  if (!session) {
    session = await TableSession.create({
      tableId: table.id,
      qrToken: table.qrToken
    });
    // Mark table as occupied
    await table.update({ status: 'occupied' });
  }

  // Get existing orders for this session
  const existingOrders = await Order.findAll({
    where: { tableSessionId: session.id, status: { [require('sequelize').Op.notIn]: ['paid', 'cancelled'] } },
    include: [{
      model: OrderItem,
      as: 'items',
      include: [{ model: MenuItem, as: 'menuItem' }]
    }],
    order: [['createdAt', 'DESC']]
  });

  res.json({
    success: true,
    data: {
      table: {
        id: table.id,
        name: table.name,
        zone: table.zone
      },
      welcomeMessage: table.zone?.welcomeMessage || '',
      session: {
        id: session.id,
        isActive: session.isActive
      },
      existingOrders
    }
  });
}));

// GET /api/customer/menu - Get full menu organized by categories
router.get('/menu', asyncHandler(async (req, res) => {
  const categories = await Category.findAll({
    where: { isActive: true },
    include: [{
      model: MenuItem,
      as: 'items',
      where: { isAvailable: true },
      required: false
    }],
    order: [['sortOrder', 'ASC'], ['name', 'ASC']]
  });

  res.json({ success: true, data: { categories } });
}));

// POST /api/customer/order - Place an order
router.post('/order', asyncHandler(async (req, res) => {
  const { sessionId, items, notes } = req.body;

  if (!sessionId || !items || items.length === 0) {
    throw new BadRequestError('Session ID and at least one item are required');
  }

  const session = await TableSession.findByPk(sessionId, {
    include: [{ model: Table, as: 'table', include: [{ model: Zone, as: 'zone' }] }]
  });
  if (!session || !session.isActive) {
    throw new NotFoundError('Invalid or expired session');
  }

  const t = await sequelize.transaction();
  try {
    // Calculate total and validate items
    let totalAmount = 0;
    const orderItems = [];

    for (const item of items) {
      const menuItem = await MenuItem.findByPk(item.menuItemId, {
        include: [{ model: Category, as: 'category' }]
      });
      if (!menuItem || !menuItem.isAvailable) {
        throw new BadRequestError(`Menu item ${item.menuItemId} not found or unavailable`);
      }

      const subtotal = parseFloat(menuItem.price) * (item.quantity || 1);
      totalAmount += subtotal;

      orderItems.push({
        menuItemId: menuItem.id,
        quantity: item.quantity || 1,
        unitPrice: menuItem.price,
        notes: item.notes || null,
        destinationId: menuItem.category.destinationId
      });
    }

    // Create order
    const order = await Order.create({
      tableSessionId: sessionId,
      totalAmount,
      notes,
      status: 'pending'
    }, { transaction: t });

    // Create order items
    for (const item of orderItems) {
      await OrderItem.create({
        ...item,
        orderId: order.id
      }, { transaction: t });
    }

    await t.commit();

    // Fetch full order for response
    const fullOrder = await Order.findByPk(order.id, {
      include: [{
        model: OrderItem,
        as: 'items',
        include: [{ model: MenuItem, as: 'menuItem' }]
      }]
    });

    // Send SSE notification to the zone's waiter
    const zoneId = session.table.zoneId;
    const tableName = session.table.name;

    // Create notification record
    await Notification.create({
      zoneId,
      type: 'newOrder',
      title: `${tableName} - Order Confirmation`,
      message: `New order from ${tableName} with ${items.length} item(s)`,
      data: { orderId: order.id, tableId: session.table.id, tableName }
    });

    // Push via SSE to zone
    sseService.sendToZone(zoneId, {
      type: 'newOrder',
      orderId: order.id,
      tableName,
      itemCount: items.length,
      totalAmount,
      message: `${tableName} - Order Confirmation`
    });

    res.status(201).json({
      success: true,
      data: { order: fullOrder }
    });
  } catch (err) {
    await t.rollback();
    throw err;
  }
}));

// POST /api/customer/call-waiter
router.post('/call-waiter', asyncHandler(async (req, res) => {
  const { sessionId } = req.body;
  if (!sessionId) throw new BadRequestError('Session ID is required');

  const session = await TableSession.findByPk(sessionId, {
    include: [{ model: Table, as: 'table', include: [{ model: Zone, as: 'zone' }] }]
  });
  if (!session) throw new NotFoundError('Session not found');

  const table = session.table;
  await table.update({ status: 'needsAttention' });

  await Notification.create({
    zoneId: table.zoneId,
    type: 'callWaiter',
    title: `${table.name} - Waiter Requested`,
    message: `Customer at ${table.name} is calling for a waiter`,
    data: { tableId: table.id, tableName: table.name }
  });

  sseService.sendToZone(table.zoneId, {
    type: 'callWaiter',
    tableName: table.name,
    tableId: table.id,
    message: `${table.name} - Waiter Requested`
  });

  res.json({ success: true, message: 'Waiter has been notified' });
}));

// POST /api/customer/request-bill
router.post('/request-bill', asyncHandler(async (req, res) => {
  const { sessionId } = req.body;
  if (!sessionId) throw new BadRequestError('Session ID is required');

  const session = await TableSession.findByPk(sessionId, {
    include: [{ model: Table, as: 'table', include: [{ model: Zone, as: 'zone' }] }]
  });
  if (!session) throw new NotFoundError('Session not found');

  const table = session.table;
  await table.update({ status: 'needsAttention' });

  await Notification.create({
    zoneId: table.zoneId,
    type: 'requestBill',
    title: `${table.name} - Bill Requested`,
    message: `Customer at ${table.name} is requesting the bill`,
    data: { tableId: table.id, tableName: table.name, sessionId }
  });

  sseService.sendToZone(table.zoneId, {
    type: 'requestBill',
    tableName: table.name,
    tableId: table.id,
    message: `${table.name} - Bill Requested`
  });

  res.json({ success: true, message: 'Bill request sent to waiter' });
}));

// POST /api/customer/request-water
router.post('/request-water', asyncHandler(async (req, res) => {
  const { sessionId } = req.body;
  if (!sessionId) throw new BadRequestError('Session ID is required');

  const session = await TableSession.findByPk(sessionId, {
    include: [{ model: Table, as: 'table', include: [{ model: Zone, as: 'zone' }] }]
  });
  if (!session) throw new NotFoundError('Session not found');

  const table = session.table;
  await table.update({ status: 'needsAttention' });

  await Notification.create({
    zoneId: table.zoneId,
    type: 'requestWater',
    title: `${table.name} - Water Requested`,
    message: `Customer at ${table.name} is requesting water`,
    data: { tableId: table.id, tableName: table.name }
  });

  sseService.sendToZone(table.zoneId, {
    type: 'requestWater',
    tableName: table.name,
    tableId: table.id,
    message: `${table.name} - Water Requested`
  });

  res.json({ success: true, message: 'Water request sent to waiter' });
}));

module.exports = router;
