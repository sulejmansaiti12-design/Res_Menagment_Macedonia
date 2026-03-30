const express = require('express');
const router = express.Router();
const { User, Shift, Zone, Payment, Order, OrderItem, Table, TableSession, MenuItem, Notification, Printer, EndOfDayClose, OrderDestination, Category } = require('../models');
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError, ConflictError } = require('../utils/errors');
const sseService = require('../services/sse.service');
const bcrypt = require('bcryptjs');
const { Op } = require('sequelize');
const sequelize = require('../config/database');
const fiscalService = require('../services/fiscal.service');

// ==================== WAITER MANAGEMENT ====================

// GET /api/admin/waiters - All waiters with current cash
router.get('/waiters', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const waiters = await User.findAll({
    where: { role: { [Op.in]: ['waiter', 'waiter_offtrack'] } },
    attributes: { exclude: ['password'] },
    include: [{
      model: Shift,
      as: 'shifts',
      where: { endTime: null },
      required: false,
      include: [
        { model: Zone, as: 'zone' },
        { model: Payment, as: 'payments' }
      ]
    }]
  });

  const waiterData = waiters.map(w => {
    const activeShift = w.shifts?.[0];
    return {
      ...w.toSafeJSON(),
      activeShift: activeShift ? {
        id: activeShift.id,
        zone: activeShift.zone,
        startTime: activeShift.startTime,
        isOffTrack: activeShift.isOffTrack,
        totalCashCollected: activeShift.totalCashCollected,
        totalFiscal: activeShift.totalFiscal,
        totalOffTrack: activeShift.totalOffTrack
      } : null
    };
  });

  res.json({ success: true, data: { waiters: waiterData } });
}));

// POST /api/admin/waiters - Register new waiter
router.post('/waiters', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { username, password, name, role = 'waiter' } = req.body;
  if (!username || !password || !name) {
    throw new BadRequestError('Username, password, and name are required');
  }
  if (!['waiter', 'waiter_offtrack'].includes(role)) {
    throw new BadRequestError('Invalid role for waiter creation');
  }

  const existing = await User.findOne({ where: { username } });
  if (existing) throw new ConflictError('Username already exists');

  const waiter = await User.create({ username, password, name, role });
  res.status(201).json({ success: true, data: { waiter: waiter.toSafeJSON() } });
}));

// PUT /api/admin/waiters/:id - Edit waiter
router.put('/waiters/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const waiter = await User.findByPk(req.params.id);
  if (!waiter || !['waiter', 'waiter_offtrack'].includes(waiter.role)) throw new NotFoundError('Waiter not found');

  const { username, password, name, isActive, role } = req.body;
  const updates = {};
  if (username) updates.username = username;
  if (name) updates.name = name;
  if (role && ['waiter', 'waiter_offtrack'].includes(role)) updates.role = role;
  if (isActive !== undefined) updates.isActive = isActive;
  if (password) {
    updates.password = await bcrypt.hash(password, 12);
  }

  await waiter.update(updates);
  res.json({ success: true, data: { waiter: waiter.toSafeJSON() } });
}));

// DELETE /api/admin/waiters/:id - Delete waiter
router.delete('/waiters/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const waiter = await User.findByPk(req.params.id);
  if (!waiter || !['waiter', 'waiter_offtrack'].includes(waiter.role)) throw new NotFoundError('Waiter not found');

  await waiter.update({ isActive: false });
  res.json({ success: true, message: 'Waiter deactivated' });
}));

// GET /api/admin/waiters/:id/details - Detailed waiter view
router.get('/waiters/:id/details', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const waiter = await User.findByPk(req.params.id, {
    attributes: { exclude: ['password'] }
  });
  if (!waiter) throw new NotFoundError('Waiter not found');

  // Active shift
  const activeShift = await Shift.findOne({
    where: { waiterId: waiter.id, endTime: null },
    include: [
      { model: Zone, as: 'zone' },
      { model: Payment, as: 'payments' }
    ]
  });

  // Recent payments
  const recentPayments = await Payment.findAll({
    where: { waiterId: waiter.id },
    include: [{
      model: Order, as: 'order',
      include: [{ model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] }]
    }],
    order: [['paidAt', 'DESC']],
    limit: 20
  });

  // Totals
  const totals = {
    fiscal: activeShift ? parseFloat(activeShift.totalFiscal || 0) : 0,
    offTrack: activeShift ? parseFloat(activeShift.totalOffTrack || 0) : 0,
    total: activeShift ? parseFloat(activeShift.totalCashCollected || 0) : 0
  };

  res.json({
    success: true,
    data: {
      waiter: waiter.toSafeJSON(),
      activeShift,
      recentPayments,
      totals
    }
  });
}));

// ==================== ZONE CHANGES ====================

// POST /api/admin/waiters/:id/change-zone - Change waiter's zone
router.post('/waiters/:id/change-zone', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { newZoneId } = req.body;
  if (!newZoneId) throw new BadRequestError('New zone ID is required');

  const waiter = await User.findByPk(req.params.id);
  if (!waiter) throw new NotFoundError('Waiter not found');

  const newZone = await Zone.findByPk(newZoneId);
  if (!newZone) throw new NotFoundError('Zone not found');

  const activeShift = await Shift.findOne({
    where: { waiterId: waiter.id, endTime: null }
  });
  if (!activeShift) throw new BadRequestError('Waiter has no active shift');

  // Check for unpaid tables in current zone
  const unpaidOrders = await Order.findAll({
    where: {
      waiterId: waiter.id,
      status: { [Op.notIn]: ['paid', 'cancelled'] }
    },
    include: [{
      model: TableSession, as: 'tableSession',
      include: [{ model: Table, as: 'table' }]
    }]
  });

  if (unpaidOrders.length > 0) {
    return res.json({
      success: false,
      error: {
        code: 'UNPAID_TABLES',
        message: `Waiter has ${unpaidOrders.length} unpaid table(s)`,
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

  // Update shift zone
  activeShift.zoneId = newZoneId;
  await activeShift.save();

  // Notify waiter via SSE
  sseService.sendToUser(waiter.id, {
    type: 'zoneChange',
    newZone: newZone.name,
    newZoneId,
    message: `Your zone has been changed to ${newZone.name}`
  });
  sseService.updateClientZone(waiter.id, newZoneId);

  res.json({ success: true, data: { shift: activeShift, newZone } });
}));

// ==================== OFF-TRACK MANAGEMENT ====================

// POST /api/admin/waiters/:id/off-track - Enable off-track mode
router.post('/waiters/:id/off-track', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { enable } = req.body; // true = enable off-track, false = disable

  const waiter = await User.findByPk(req.params.id);
  if (!waiter) throw new NotFoundError('Waiter not found');

  const activeShift = await Shift.findOne({
    where: { waiterId: waiter.id, endTime: null }
  });
  if (!activeShift) throw new BadRequestError('Waiter has no active shift');

  // Off-track can only be enabled if waiter hasn't done anything yet
  if (enable) {
    const paymentCount = await Payment.count({ where: { shiftId: activeShift.id } });
    if (paymentCount > 0) {
      throw new BadRequestError('Cannot enable off-track mode - waiter already has processed payments this shift');
    }

    const orderCount = await Order.count({
      where: { waiterId: waiter.id },
      include: [{
        model: TableSession, as: 'tableSession',
        where: { isActive: true }
      }]
    });
    // Note: We only check payments, not orders, since orders might exist but not be paid yet
  }

  activeShift.isOffTrack = enable;
  await activeShift.save();

  sseService.sendToUser(waiter.id, {
    type: 'offTrackChanged',
    isOffTrack: enable,
    message: enable ? 'Off-track mode enabled' : 'Off-track mode disabled'
  });

  res.json({ success: true, data: { shift: activeShift } });
}));

// ==================== REVENUE & REPORTS ====================

// GET /api/admin/revenue - Real-time revenue
router.get('/revenue', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { date, startDate, endDate } = req.query;

  const where = {};
  if (date) {
    const d = new Date(date);
    where.paidAt = {
      [Op.gte]: new Date(d.setHours(0, 0, 0, 0)),
      [Op.lte]: new Date(d.setHours(23, 59, 59, 999))
    };
  } else if (startDate && endDate) {
    where.paidAt = {
      [Op.gte]: new Date(startDate),
      [Op.lte]: new Date(endDate)
    };
  } else {
    // Today by default
    const today = new Date();
    where.paidAt = {
      [Op.gte]: new Date(today.setHours(0, 0, 0, 0)),
      [Op.lte]: new Date(new Date().setHours(23, 59, 59, 999))
    };
  }

  const payments = await Payment.findAll({
    where,
    include: [
      { model: User, as: 'waiter', attributes: ['id', 'name', 'username'] }
    ]
  });

  const totalRevenue = payments.reduce((sum, p) => sum + parseFloat(p.amount), 0);
  const fiscalRevenue = payments.filter(p => p.isFiscal).reduce((sum, p) => sum + parseFloat(p.amount), 0);
  const offTrackRevenue = payments.filter(p => !p.isFiscal).reduce((sum, p) => sum + parseFloat(p.amount), 0);
  const cashPayments = payments.filter(p => p.paymentMethod === 'cash').reduce((sum, p) => sum + parseFloat(p.amount), 0);
  const cardPayments = payments.filter(p => p.paymentMethod === 'card').reduce((sum, p) => sum + parseFloat(p.amount), 0);

  // Per-waiter breakdown
  const byWaiter = {};
  payments.forEach(p => {
    const wid = p.waiterId;
    if (!byWaiter[wid]) {
      byWaiter[wid] = {
        waiter: p.waiter,
        total: 0,
        fiscal: 0,
        offTrack: 0,
        count: 0
      };
    }
    byWaiter[wid].total += parseFloat(p.amount);
    if (p.isFiscal) byWaiter[wid].fiscal += parseFloat(p.amount);
    else byWaiter[wid].offTrack += parseFloat(p.amount);
    byWaiter[wid].count++;
  });

  res.json({
    success: true,
    data: {
      totalRevenue,
      fiscalRevenue,
      offTrackRevenue,
      cashPayments,
      cardPayments,
      paymentCount: payments.length,
      byWaiter: Object.values(byWaiter)
    }
  });
}));

// GET /api/admin/reports/print - Printable report
router.get('/reports/print', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { waiterId, date, startDate, endDate } = req.query;

  const shiftWhere = {};
  if (waiterId) shiftWhere.waiterId = waiterId;
  if (date) {
    const d = new Date(date);
    shiftWhere.startTime = {
      [Op.gte]: new Date(d.getFullYear(), d.getMonth(), d.getDate()),
      [Op.lte]: new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59)
    };
  } else if (startDate && endDate) {
    shiftWhere.startTime = {
      [Op.gte]: new Date(startDate),
      [Op.lte]: new Date(endDate)
    };
  }

  const shifts = await Shift.findAll({
    where: shiftWhere,
    include: [
      { model: User, as: 'waiter', attributes: ['id', 'name', 'username'] },
      { model: Zone, as: 'zone' },
      {
        model: Payment, as: 'payments',
        include: [{
          model: Order, as: 'order',
          include: [
            { model: OrderItem, as: 'items', include: [{ model: MenuItem, as: 'menuItem' }] },
            { model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] }
          ]
        }]
      }
    ],
    order: [['startTime', 'DESC']]
  });

  res.json({ success: true, data: { shifts } });
}));

// GET /api/admin/active-shifts - All currently active shifts
router.get('/active-shifts', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const shifts = await Shift.findAll({
    where: { endTime: null },
    include: [
      { model: User, as: 'waiter', attributes: ['id', 'name', 'username'] },
      { model: Zone, as: 'zone' },
      { model: Payment, as: 'payments' }
    ],
    order: [['startTime', 'ASC']]
  });

  const data = shifts.map(s => ({
    id: s.id,
    waiter: s.waiter,
    zone: s.zone,
    startTime: s.startTime,
    isOffTrack: s.isOffTrack,
    totalCashCollected: s.totalCashCollected,
    totalFiscal: s.totalFiscal,
    totalOffTrack: s.totalOffTrack,
    paymentCount: s.payments ? s.payments.length : 0
  }));

  res.json({ success: true, data: { shifts: data } });
}));

// GET /api/admin/zone-tables/:zoneId - Get tables with QR tokens for a zone
router.get('/zone-tables/:zoneId', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const zone = await Zone.findByPk(req.params.zoneId);
  if (!zone) throw new NotFoundError('Zone not found');

  const tables = await Table.findAll({
    where: { zoneId: req.params.zoneId, isActive: true },
    order: [['name', 'ASC']]
  });

  res.json({ success: true, data: { zone, tables } });
}));

// ==================== OPERATIONS ====================

// GET /api/admin/operations/table-map - Zones/tables + active session/orders + pending requests
router.get('/operations/table-map', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const zones = await Zone.findAll({ order: [['name', 'ASC']] });
  const tables = await Table.findAll({
    where: { isActive: true },
    order: [['name', 'ASC']],
  });

  const activeSessions = await TableSession.findAll({
    where: { isActive: true },
  });

  const sessionsByTable = new Map(activeSessions.map((s) => [s.tableId, s]));

  // Open orders per active session
  const openOrders = await Order.findAll({
    where: { status: { [Op.notIn]: ['paid', 'cancelled'] } },
    attributes: ['id', 'tableSessionId', 'status', 'totalAmount', 'createdAt'],
  });
  const ordersBySession = new Map();
  for (const o of openOrders) {
    if (!ordersBySession.has(o.tableSessionId)) ordersBySession.set(o.tableSessionId, []);
    ordersBySession.get(o.tableSessionId).push(o);
  }

  // Pending requests (unread notifications for table)
  const requestTypes = ['callWaiter', 'requestBill', 'requestWater'];
  const pendingNotifs = await Notification.findAll({
    where: { type: { [Op.in]: requestTypes }, isRead: false },
    order: [['createdAt', 'DESC']],
  });
  const notifCountByTable = new Map();
  for (const n of pendingNotifs) {
    const tid = n.data?.tableId;
    if (!tid) continue;
    notifCountByTable.set(tid, (notifCountByTable.get(tid) || 0) + 1);
  }

  const tablesByZone = new Map();
  for (const t of tables) {
    if (!tablesByZone.has(t.zoneId)) tablesByZone.set(t.zoneId, []);
    const session = sessionsByTable.get(t.id) || null;
    const sessionOrders = session ? (ordersBySession.get(session.id) || []) : [];
    const openTotal = sessionOrders.reduce((sum, o) => sum + parseFloat(o.totalAmount || 0), 0);
    tablesByZone.get(t.zoneId).push({
      id: t.id,
      name: t.name,
      status: t.status,
      qrToken: t.qrToken,
      activeSession: session ? { id: session.id, startedAt: session.startedAt } : null,
      openOrdersCount: sessionOrders.length,
      openOrdersTotal: openTotal,
      pendingRequestsCount: notifCountByTable.get(t.id) || 0,
    });
  }

  res.json({
    success: true,
    data: {
      zones: zones.map((z) => ({
        id: z.id,
        name: z.name,
        tables: tablesByZone.get(z.id) || [],
      })),
    },
  });
}));

// GET /api/admin/operations/requests - pending customer requests (call waiter / bill / water)
router.get('/operations/requests', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { zoneId, unreadOnly = 'true', limit = 100 } = req.query;
  const where = {
    type: { [Op.in]: ['callWaiter', 'requestBill', 'requestWater'] },
  };
  if (zoneId) where.zoneId = zoneId;
  if (unreadOnly === 'true') where.isRead = false;

  const notifications = await Notification.findAll({
    where,
    order: [['createdAt', 'DESC']],
    limit: parseInt(limit),
  });

  res.json({ success: true, data: { notifications } });
}));

// GET /api/admin/operations/destinations - list kitchen/bar destinations
router.get('/operations/destinations', authenticate, authorize('admin', 'owner', 'kitchen', 'bar'), asyncHandler(async (req, res) => {
  const destinations = await OrderDestination.findAll({ order: [['name', 'ASC']] });
  res.json({ success: true, data: { destinations } });
}));

// ==================== PRINTER SETUP ====================

router.get('/printers', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const printers = await Printer.findAll({
    where: { isActive: true },
    include: [{ model: OrderDestination, as: 'destination' }],
    order: [['name', 'ASC']],
  });
  res.json({ success: true, data: { printers } });
}));

router.post('/printers', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { name, type = 'stub', destinationId, ip, port, config } = req.body || {};
  if (!name) throw new BadRequestError('Printer name is required');
  if (destinationId) {
    const dest = await OrderDestination.findByPk(destinationId);
    if (!dest) throw new NotFoundError('Destination not found');
  }

  const printer = await Printer.create({ name, type, destinationId: destinationId || null, ip: ip || null, port: port || null, config: config || null });
  res.status(201).json({ success: true, data: { printer } });
}));

router.put('/printers/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const printer = await Printer.findByPk(req.params.id);
  if (!printer) throw new NotFoundError('Printer not found');

  const { name, type, destinationId, ip, port, config, isActive } = req.body || {};
  if (destinationId) {
    const dest = await OrderDestination.findByPk(destinationId);
    if (!dest) throw new NotFoundError('Destination not found');
  }

  await printer.update({
    ...(name !== undefined ? { name } : {}),
    ...(type !== undefined ? { type } : {}),
    ...(destinationId !== undefined ? { destinationId } : {}),
    ...(ip !== undefined ? { ip } : {}),
    ...(port !== undefined ? { port } : {}),
    ...(config !== undefined ? { config } : {}),
    ...(isActive !== undefined ? { isActive } : {}),
  });
  res.json({ success: true, data: { printer } });
}));

router.delete('/printers/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const printer = await Printer.findByPk(req.params.id);
  if (!printer) throw new NotFoundError('Printer not found');
  await printer.update({ isActive: false });
  res.json({ success: true, message: 'Printer deactivated' });
}));

// ==================== DASHBOARD SUMMARY ====================

router.get('/dashboard/summary', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const businessDate = String(req.query.date || new Date().toISOString().slice(0, 10));
  const { start, end } = _dateRangeForBusinessDate(businessDate);

  const payments = await Payment.findAll({
    where: { paidAt: { [Op.between]: [start, end] } },
    include: [{ model: User, as: 'waiter', attributes: ['id', 'name', 'username'] }],
  });

  const totals = {
    total: 0,
    fiscal: 0,
    offTrack: 0,
  };

  const waiterStatsMap = {};

  payments.forEach(p => {
    const amount = parseFloat(p.amount) || 0;
    totals.total += amount;
    if (p.isFiscal) totals.fiscal += amount;
    else totals.offTrack += amount;

    if (p.waiter) {
      if (!waiterStatsMap[p.waiter.id]) {
        waiterStatsMap[p.waiter.id] = { name: p.waiter.name, total: 0, fiscal: 0, offTrack: 0 };
      }
      waiterStatsMap[p.waiter.id].total += amount;
      if (p.isFiscal) waiterStatsMap[p.waiter.id].fiscal += amount;
      else waiterStatsMap[p.waiter.id].offTrack += amount;
    }
  });

  const waiters = Object.values(waiterStatsMap).sort((a, b) => b.total - a.total);

  res.json({
    success: true,
    data: {
      totals,
      waiters
    }
  });
}));

// ==================== END OF DAY (X/Z + RECONCILIATION) ====================

function _dateRangeForBusinessDate(businessDate) {
  // businessDate = YYYY-MM-DD
  const start = new Date(`${businessDate}T00:00:00`);
  const end = new Date(`${businessDate}T23:59:59.999`);
  return { start, end };
}

router.get('/end-of-day/summary', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const businessDate = String(req.query.date || new Date().toISOString().slice(0, 10));
  const { start, end } = _dateRangeForBusinessDate(businessDate);

  const payments = await Payment.findAll({
    where: { paidAt: { [Op.between]: [start, end] } },
  });

  const totals = {
    businessDate,
    paymentCount: payments.length,
    total: payments.reduce((s, p) => s + parseFloat(p.amount), 0),
    fiscalTotal: payments.filter((p) => p.isFiscal).reduce((s, p) => s + parseFloat(p.amount), 0),
    offTrackTotal: payments.filter((p) => !p.isFiscal).reduce((s, p) => s + parseFloat(p.amount), 0),
    cashTotal: payments.filter((p) => p.paymentMethod === 'cash').reduce((s, p) => s + parseFloat(p.amount), 0),
    cardTotal: payments.filter((p) => p.paymentMethod === 'card').reduce((s, p) => s + parseFloat(p.amount), 0),
    fiscalCash: payments.filter((p) => p.isFiscal && p.paymentMethod === 'cash').reduce((s, p) => s + parseFloat(p.amount), 0),
    fiscalCard: payments.filter((p) => p.isFiscal && p.paymentMethod === 'card').reduce((s, p) => s + parseFloat(p.amount), 0),
    offTrackCash: payments.filter((p) => !p.isFiscal && p.paymentMethod === 'cash').reduce((s, p) => s + parseFloat(p.amount), 0),
    offTrackCard: payments.filter((p) => !p.isFiscal && p.paymentMethod === 'card').reduce((s, p) => s + parseFloat(p.amount), 0),
  };

  const existingClose = await EndOfDayClose.findOne({ where: { businessDate } });

  res.json({
    success: true,
    data: {
      summary: totals,
      alreadyClosed: !!existingClose,
      closeRecord: existingClose || null,
    },
  });
}));

router.post('/end-of-day/close', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const businessDate = String(req.body?.date || new Date().toISOString().slice(0, 10));
  const actualCash = req.body?.actualCash;
  if (actualCash === undefined || actualCash === null) throw new BadRequestError('actualCash is required');

  const existingClose = await EndOfDayClose.findOne({ where: { businessDate } });
  if (existingClose) throw new ConflictError('This day is already closed');

  const { start, end } = _dateRangeForBusinessDate(businessDate);
  const payments = await Payment.findAll({ where: { paidAt: { [Op.between]: [start, end] } } });
  const expectedCash = payments.filter((p) => p.paymentMethod === 'cash').reduce((s, p) => s + parseFloat(p.amount), 0);
  const actual = parseFloat(actualCash);
  const diff = actual - expectedCash;

  const summary = {
    businessDate,
    paymentCount: payments.length,
    total: payments.reduce((s, p) => s + parseFloat(p.amount), 0),
    fiscalTotal: payments.filter((p) => p.isFiscal).reduce((s, p) => s + parseFloat(p.amount), 0),
    offTrackTotal: payments.filter((p) => !p.isFiscal).reduce((s, p) => s + parseFloat(p.amount), 0),
    cashTotal: expectedCash,
    cardTotal: payments.filter((p) => p.paymentMethod === 'card').reduce((s, p) => s + parseFloat(p.amount), 0),
  };

  let fiscalZReport = null;
  if (fiscalService.isEnabled() && fiscalService.isConfigured()) {
    fiscalZReport = await fiscalService.generateDailyReport(summary);
  }

  const closeRecord = await EndOfDayClose.create({
    businessDate,
    expectedCash,
    actualCash: actual,
    difference: diff,
    summary,
    closedByUserId: req.user.id,
    fiscalZReport,
  });

  res.status(201).json({ success: true, data: { close: closeRecord } });
}));

router.post('/end-of-day/print-z', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  if (!fiscalService.isEnabled() || !fiscalService.isConfigured()) {
    throw new BadRequestError('Fiscal service is not configured or disabled');
  }
  
  // Re-fetch totals for the printing
  const businessDate = String(req.body?.date || new Date().toISOString().slice(0, 10));
  const { start, end } = _dateRangeForBusinessDate(businessDate);
  const payments = await Payment.findAll({ where: { paidAt: { [Op.between]: [start, end] } } });
  
  const summary = {
    paymentCount: payments.length,
    total: payments.reduce((s, p) => s + parseFloat(p.amount), 0),
    fiscalTotal: payments.filter((p) => p.isFiscal).reduce((s, p) => s + parseFloat(p.amount), 0),
    cashTotal: payments.filter((p) => p.paymentMethod === 'cash').reduce((s, p) => s + parseFloat(p.amount), 0),
    cardTotal: payments.filter((p) => p.paymentMethod === 'card').reduce((s, p) => s + parseFloat(p.amount), 0),
  };

  const report = await fiscalService.generateDailyReport(summary);
  res.json({ success: true, message: 'Z-Report (with totals) successfully sent to fiscal printer', data: report });
}));

router.post('/end-of-day/print-x', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  if (!fiscalService.isEnabled() || !fiscalService.isConfigured()) {
    throw new BadRequestError('Fiscal service is not configured or disabled');
  }
  const report = await fiscalService.generatePeriodicReport();
  res.json({ success: true, message: 'X-Report command successfully sent to fiscal printer', data: report });
}));

// ==================== ANALYTICS & REPORTING ====================

// GET /api/admin/analytics/waiters - Waiter performance metrics
router.get('/analytics/waiters', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { startDate, endDate } = req.query;
  const where = {};
  if (startDate && endDate) {
    where.startTime = { [Op.between]: [new Date(startDate), new Date(endDate)] };
  }

  const shifts = await Shift.findAll({
    where,
    include: [
      { model: User, as: 'waiter', attributes: ['id', 'name', 'username'] },
      { model: Payment, as: 'payments', include: [{ model: Order, as: 'order' }] }
    ],
    order: [['startTime', 'DESC']]
  });

  const waiterStats = {};
  shifts.forEach(shift => {
    const wid = shift.waiterId;
    if (!waiterStats[wid]) {
      waiterStats[wid] = {
        waiter: shift.waiter,
        totalShifts: 0,
        totalRevenue: 0,
        fiscalRevenue: 0,
        offTrackRevenue: 0,
        totalPayments: 0,
        totalOrders: 0,
        avgOrderValue: 0
      };
    }
    waiterStats[wid].totalShifts++;
    
    const payments = shift.payments || [];
    payments.forEach(p => {
      const amount = parseFloat(p.amount);
      waiterStats[wid].totalRevenue += amount;
      waiterStats[wid].totalPayments++;
      if (p.isFiscal) waiterStats[wid].fiscalRevenue += amount;
      else waiterStats[wid].offTrackRevenue += amount;
      if (p.order) waiterStats[wid].totalOrders++;
    });
  });

  // Calculate averages
  Object.values(waiterStats).forEach(stat => {
    stat.avgOrderValue = stat.totalOrders > 0 ? stat.totalRevenue / stat.totalOrders : 0;
    stat.avgRevenuePerShift = stat.totalShifts > 0 ? stat.totalRevenue / stat.totalShifts : 0;
  });

  res.json({
    success: true,
    data: {
      waiters: Object.values(waiterStats).sort((a, b) => b.totalRevenue - a.totalRevenue),
      period: { startDate, endDate }
    }
  });
}));

// GET /api/admin/analytics/sales - Sales trends and hourly breakdowns
router.get('/analytics/sales', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { startDate, endDate } = req.query;
  const where = {};
  if (startDate && endDate) {
    where.paidAt = { [Op.between]: [new Date(startDate), new Date(endDate)] };
  } else {
    // Last 7 days by default
    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - 7);
    where.paidAt = { [Op.between]: [start, end] };
  }

  const payments = await Payment.findAll({
    where,
    include: [{ model: User, as: 'waiter', attributes: ['id', 'name'] }],
    order: [['paidAt', 'ASC']]
  });

  // Hourly breakdown
  const hourlyStats = {};
  const dailyStats = {};
  let totalRevenue = 0;
  let fiscalRevenue = 0;
  let offTrackRevenue = 0;
  let cashTotal = 0;
  let cardTotal = 0;

  payments.forEach(p => {
    const date = new Date(p.paidAt);
    const hour = date.getHours();
    const dayKey = date.toISOString().slice(0, 10);
    const amount = parseFloat(p.amount);

    totalRevenue += amount;
    if (p.isFiscal) fiscalRevenue += amount;
    else offTrackRevenue += amount;
    if (p.paymentMethod === 'cash') cashTotal += amount;
    else if (p.paymentMethod === 'card') cardTotal += amount;

    // Hourly
    if (!hourlyStats[hour]) hourlyStats[hour] = { hour, revenue: 0, count: 0 };
    hourlyStats[hour].revenue += amount;
    hourlyStats[hour].count++;

    // Daily
    if (!dailyStats[dayKey]) dailyStats[dayKey] = { date: dayKey, revenue: 0, count: 0 };
    dailyStats[dayKey].revenue += amount;
    dailyStats[dayKey].count++;
  });

  // Find peak hour
  const hourlyArray = Object.values(hourlyStats).sort((a, b) => b.revenue - a.revenue);
  const peakHour = hourlyArray[0] || { hour: 0, revenue: 0 };

  res.json({
    success: true,
    data: {
      summary: { totalRevenue, fiscalRevenue, offTrackRevenue, cashTotal, cardTotal, paymentCount: payments.length },
      peakHour,
      hourlyBreakdown: hourlyArray,
      dailyBreakdown: Object.values(dailyStats).sort((a, b) => a.date.localeCompare(b.date))
    }
  });
}));

// GET /api/admin/analytics/items - Top menu items performance
router.get('/analytics/items', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { startDate, endDate } = req.query;
  
  let orderWhere = {};
  if (startDate && endDate) {
    orderWhere.createdAt = { [Op.between]: [new Date(startDate), new Date(endDate)] };
  }

  const orderItems = await OrderItem.findAll({
    include: [
      { 
        model: Order, 
        as: 'order', 
        where: { ...orderWhere, status: { [Op.not]: 'cancelled' } },
        required: true
      },
      { model: MenuItem, as: 'menuItem', include: [{ model: Category, as: 'category' }] }
    ]
  });

  const itemStats = {};
  const categoryStats = {};

  orderItems.forEach(oi => {
    const item = oi.menuItem;
    if (!item) return;

    const itemId = item.id;
    if (!itemStats[itemId]) {
      itemStats[itemId] = {
        item: {
          id: item.id,
          name: item.name,
          price: item.price,
          category: item.category?.name
        },
        quantitySold: 0,
        revenue: 0
      };
    }
    itemStats[itemId].quantitySold += oi.quantity;
    itemStats[itemId].revenue += parseFloat(oi.unitPrice) * oi.quantity;

    // Category stats
    const catId = item.categoryId;
    if (catId) {
      if (!categoryStats[catId]) {
        categoryStats[catId] = {
          category: item.category?.name || 'Unknown',
          itemCount: 0,
          revenue: 0
        };
      }
      categoryStats[catId].itemCount += oi.quantity;
      categoryStats[catId].revenue += parseFloat(oi.unitPrice) * oi.quantity;
    }
  });

  const topItems = Object.values(itemStats)
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 20);

  const categoryArray = Object.values(categoryStats).sort((a, b) => b.revenue - a.revenue);

  res.json({
    success: true,
    data: {
      topItems,
      categoryBreakdown: categoryArray,
      totalItemsSold: orderItems.reduce((sum, oi) => sum + oi.quantity, 0)
    }
  });
}));

// GET /api/admin/history - Chronological Order/Payment History
router.get('/history', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { limit = 100, offset = 0 } = req.query;

  const payments = await Payment.findAll({
    limit: parseInt(limit, 10),
    offset: parseInt(offset, 10),
    order: [['createdAt', 'DESC']],
    include: [
      { model: User, as: 'waiter', attributes: ['id', 'name', 'username', 'role'] },
      { 
        model: Order, as: 'order',
        include: [
          {
            model: TableSession, as: 'tableSession',
            include: [
              { model: Table, as: 'table', include: [{ model: Zone, as: 'zone' }] }
            ]
          },
          {
            model: OrderItem, as: 'items',
            include: [{ model: MenuItem, as: 'menuItem' }]
          }
        ]
      }
    ]
  });

  res.json({ success: true, data: { history: payments } });
}));

// GET /api/admin/analytics/tables - Table turnover metrics
router.get('/analytics/tables', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { startDate, endDate } = req.query;
  
  let where = {};
  if (startDate && endDate) {
    where.startedAt = { [Op.between]: [new Date(startDate), new Date(endDate)] };
  }

  const sessions = await TableSession.findAll({
    where,
    include: [
      { model: Table, as: 'table', include: [{ model: Zone, as: 'zone' }] },
      { model: Order, as: 'orders', where: { status: { [Op.not]: 'cancelled' } }, required: false }
    ]
  });

  const tableStats = {};
  const zoneStats = {};
  let totalDuration = 0;
  let sessionCount = 0;

  sessions.forEach(session => {
    const tableId = session.tableId;
    const zoneId = session.table?.zoneId;

    if (!tableStats[tableId]) {
      tableStats[tableId] = {
        table: {
          id: session.table?.id,
          name: session.table?.name,
          zone: session.table?.zone?.name
        },
        sessions: 0,
        totalRevenue: 0,
        totalOrders: 0,
        avgSessionDuration: 0,
        totalDuration: 0
      };
    }

    tableStats[tableId].sessions++;
    const orders = session.orders || [];
    orders.forEach(o => {
      tableStats[tableId].totalRevenue += parseFloat(o.totalAmount || 0);
      tableStats[tableId].totalOrders++;
    });

    // Calculate session duration
    if (session.endedAt) {
      const duration = new Date(session.endedAt) - new Date(session.startedAt);
      tableStats[tableId].totalDuration += duration;
      totalDuration += duration;
      sessionCount++;
    }

    // Zone stats
    if (zoneId) {
      if (!zoneStats[zoneId]) {
        zoneStats[zoneId] = {
          zone: session.table?.zone?.name,
          sessions: 0,
          revenue: 0,
          orders: 0
        };
      }
      zoneStats[zoneId].sessions++;
      zoneStats[zoneId].revenue += tableStats[tableId].totalRevenue;
      zoneStats[zoneId].orders += orders.length;
    }
  });

  // Calculate averages
  Object.values(tableStats).forEach(stat => {
    stat.avgSessionDuration = stat.sessions > 0 ? Math.round(stat.totalDuration / stat.sessions / 60000) : 0; // in minutes
    stat.avgRevenuePerSession = stat.sessions > 0 ? stat.totalRevenue / stat.sessions : 0;
  });

  const avgTurnover = sessionCount > 0 ? Math.round(totalDuration / sessionCount / 60000) : 0;

  res.json({
    success: true,
    data: {
      summary: {
        totalSessions: sessions.length,
        avgTurnoverMinutes: avgTurnover,
        totalRevenue: Object.values(tableStats).reduce((sum, t) => sum + t.totalRevenue, 0)
      },
      tables: Object.values(tableStats).sort((a, b) => b.totalRevenue - a.totalRevenue),
      zones: Object.values(zoneStats).sort((a, b) => b.revenue - a.revenue)
    }
  });
}));

// GET /api/admin/reports/export - Export reports to CSV format
router.get('/reports/export', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { type, startDate, endDate, waiterId } = req.query;
  
  if (!type || !['payments', 'shifts', 'orders'].includes(type)) {
    throw new BadRequestError('Valid type required: payments, shifts, or orders');
  }

  let data = [];
  let headers = [];

  if (type === 'payments') {
    const where = {};
    if (startDate && endDate) where.paidAt = { [Op.between]: [new Date(startDate), new Date(endDate)] };
    if (waiterId) where.waiterId = waiterId;
    
    const payments = await Payment.findAll({
      where,
      include: [
        { model: User, as: 'waiter', attributes: ['name'] },
        { model: Order, as: 'order', include: [{ model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] }] }
      ],
      order: [['paidAt', 'DESC']]
    });

    headers = ['Date', 'Time', 'Waiter', 'Table', 'Amount', 'Method', 'Type', 'Order ID'];
    data = payments.map(p => [
      new Date(p.paidAt).toLocaleDateString(),
      new Date(p.paidAt).toLocaleTimeString(),
      p.waiter?.name || 'Unknown',
      p.order?.tableSession?.table?.name || 'N/A',
      p.amount,
      p.paymentMethod,
      p.isFiscal ? 'Fiscal' : 'Off-Track',
      p.orderId
    ]);
  } else if (type === 'shifts') {
    const where = {};
    if (startDate && endDate) where.startTime = { [Op.between]: [new Date(startDate), new Date(endDate)] };
    if (waiterId) where.waiterId = waiterId;
    
    const shifts = await Shift.findAll({
      where,
      include: [
        { model: User, as: 'waiter', attributes: ['name'] },
        { model: Zone, as: 'zone' },
        { model: Payment, as: 'payments' }
      ],
      order: [['startTime', 'DESC']]
    });

    headers = ['Start Date', 'Start Time', 'End Date', 'End Time', 'Waiter', 'Zone', 'Total Cash', 'Fiscal', 'Off-Track', 'Payments', 'Status'];
    data = shifts.map(s => {
      const start = new Date(s.startTime);
      const end = s.endTime ? new Date(s.endTime) : null;
      return [
        start.toLocaleDateString(),
        start.toLocaleTimeString(),
        end ? end.toLocaleDateString() : '',
        end ? end.toLocaleTimeString() : '',
        s.waiter?.name || 'Unknown',
        s.zone?.name || 'N/A',
        s.totalCashCollected,
        s.totalFiscal,
        s.totalOffTrack,
        s.payments?.length || 0,
        s.endTime ? 'Closed' : 'Active'
      ];
    });
  } else if (type === 'orders') {
    let where = { status: { [Op.not]: 'cancelled' } };
    if (startDate && endDate) where.createdAt = { [Op.between]: [new Date(startDate), new Date(endDate)] };
    if (waiterId) where.waiterId = waiterId;
    
    const orders = await Order.findAll({
      where,
      include: [
        { model: User, as: 'waiter', attributes: ['name'] },
        { model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] },
        { model: OrderItem, as: 'items' }
      ],
      order: [['createdAt', 'DESC']]
    });

    headers = ['Date', 'Time', 'Table', 'Waiter', 'Status', 'Item Count', 'Total Amount', 'Order ID'];
    data = orders.map(o => [
      new Date(o.createdAt).toLocaleDateString(),
      new Date(o.createdAt).toLocaleTimeString(),
      o.tableSession?.table?.name || 'N/A',
      o.waiter?.name || 'Unassigned',
      o.status,
      o.items?.length || 0,
      o.totalAmount,
      o.id
    ]);
  }

  // Convert to CSV
  const csvRows = [headers.join(','), ...data.map(row => row.map(cell => `"${cell}"`).join(','))];
  const csv = csvRows.join('\n');

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', `attachment; filename="${type}_report_${new Date().toISOString().slice(0,10)}.csv"`);
  res.send(csv);
}));

module.exports = router;
