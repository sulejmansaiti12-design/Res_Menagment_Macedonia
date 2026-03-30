const express = require('express');
const router = express.Router();
const { Shift, User, Zone, Table, Order, Payment, TableSession } = require('../models');
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError, ConflictError } = require('../utils/errors');
const sseService = require('../services/sse.service');
const { Op } = require('sequelize');

// POST /api/shifts/start - Start a new shift
router.post('/start', authenticate, authorize('waiter', 'waiter_offtrack'), asyncHandler(async (req, res) => {
  const { zoneId } = req.body;
  const waiterId = req.user.id;

  if (!zoneId) throw new BadRequestError('Zone ID is required');

  // Check zone exists
  const zone = await Zone.findByPk(zoneId);
  if (!zone) throw new NotFoundError('Zone not found');

  // Check no active shift
  const activeShift = await Shift.findOne({
    where: { waiterId, endTime: null }
  });
  if (activeShift) throw new ConflictError('You already have an active shift');

  const shift = await Shift.create({
    waiterId,
    zoneId,
    startTime: new Date()
  });

  // Get tables in this zone
  const tables = await Table.findAll({
    where: { zoneId, isActive: true },
    include: [{ model: Zone, as: 'zone' }]
  });

  res.status(201).json({
    success: true,
    data: {
      shift,
      zone,
      tables
    }
  });
}));

// POST /api/shifts/end - End current shift
router.post('/end', authenticate, authorize('waiter', 'waiter_offtrack'), asyncHandler(async (req, res) => {
  const waiterId = req.user.id;

  const activeShift = await Shift.findOne({
    where: { waiterId, endTime: null }
  });
  if (!activeShift) throw new NotFoundError('No active shift found');

  // Check for unpaid tables in this zone
  const unpaidOrders = await Order.findAll({
    where: {
      waiterId,
      status: { [Op.notIn]: ['paid', 'cancelled'] }
    },
    include: [{
      model: TableSession,
      as: 'tableSession',
      include: [{ model: Table, as: 'table' }]
    }]
  });

  if (unpaidOrders.length > 0) {
    return res.json({
      success: false,
      error: {
        code: 'UNPAID_TABLES',
        message: `You have ${unpaidOrders.length} unpaid order(s). Please close them before ending your shift.`,
        data: {
          unpaidOrders: unpaidOrders.map(o => ({
            orderId: o.id,
            tableName: o.tableSession?.table?.name,
            amount: o.totalAmount
          }))
        }
      }
    });
  }

  activeShift.endTime = new Date();
  await activeShift.save();

  res.json({
    success: true,
    data: { shift: activeShift }
  });
}));

// GET /api/shifts/active - Get current active shift
router.get('/active', authenticate, asyncHandler(async (req, res) => {
  const activeShift = await Shift.findOne({
    where: { waiterId: req.user.id, endTime: null },
    include: [
      { model: Zone, as: 'zone' },
      { model: User, as: 'waiter', attributes: ['id', 'name', 'username'] }
    ]
  });

  res.json({
    success: true,
    data: { shift: activeShift }
  });
}));

// GET /api/shifts/history - Shift history (admin/owner)
router.get('/history', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { waiterId, startDate, endDate, page = 1, limit = 50 } = req.query;

  const where = {};
  if (waiterId) where.waiterId = waiterId;
  if (startDate || endDate) {
    where.startTime = {};
    if (startDate) where.startTime[Op.gte] = new Date(startDate);
    if (endDate) where.startTime[Op.lte] = new Date(endDate);
  }

  const { count, rows: shifts } = await Shift.findAndCountAll({
    where,
    include: [
      { model: User, as: 'waiter', attributes: ['id', 'name', 'username'] },
      { model: Zone, as: 'zone', attributes: ['id', 'name'] },
      { model: Payment, as: 'payments' }
    ],
    order: [['startTime', 'DESC']],
    limit: parseInt(limit),
    offset: (parseInt(page) - 1) * parseInt(limit)
  });

  res.json({
    success: true,
    data: {
      shifts,
      pagination: {
        total: count,
        page: parseInt(page),
        totalPages: Math.ceil(count / parseInt(limit))
      }
    }
  });
}));

// GET /api/shifts/all-active - All active shifts (admin/owner)
router.get('/all-active', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const activeShifts = await Shift.findAll({
    where: { endTime: null },
    include: [
      { model: User, as: 'waiter', attributes: ['id', 'name', 'username'] },
      { model: Zone, as: 'zone', attributes: ['id', 'name'] },
      { model: Payment, as: 'payments' }
    ],
    order: [['startTime', 'DESC']]
  });

  res.json({
    success: true,
    data: { shifts: activeShifts }
  });
}));

module.exports = router;
