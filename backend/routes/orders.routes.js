const express = require('express');
const router = express.Router();
const { Order, OrderItem, MenuItem, Category, TableSession, Table, Zone, User, Notification } = require('../models');
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError } = require('../utils/errors');
const sseService = require('../services/sse.service');
const { Op } = require('sequelize');
const sequelize = require('../config/database');

// GET /api/orders/zone/:zoneId - Get orders for a zone (waiter view)
router.get('/zone/:zoneId', authenticate, authorize('waiter', 'waiter_offtrack', 'admin', 'owner'), asyncHandler(async (req, res) => {
  const { status } = req.query;
  const where = {};
  if (status) where.status = status;

  const orders = await Order.findAll({
    where,
    include: [
      {
        model: TableSession,
        as: 'tableSession',
        required: true,
        include: [{
          model: Table,
          as: 'table',
          where: { zoneId: req.params.zoneId },
          include: [{ model: Zone, as: 'zone' }]
        }]
      },
      {
        model: OrderItem,
        as: 'items',
        include: [{ model: MenuItem, as: 'menuItem' }]
      },
      { model: User, as: 'waiter', attributes: ['id', 'name'] }
    ],
    order: [['createdAt', 'DESC']]
  });

  res.json({ success: true, data: { orders } });
}));

// GET /api/orders/:id - Get single order
router.get('/:id', authenticate, asyncHandler(async (req, res) => {
  const order = await Order.findByPk(req.params.id, {
    include: [
      {
        model: OrderItem,
        as: 'items',
        include: [
          { model: MenuItem, as: 'menuItem' },
          { model: require('../models/OrderDestination'), as: 'destination' }
        ]
      },
      {
        model: TableSession,
        as: 'tableSession',
        include: [{ model: Table, as: 'table', include: [{ model: Zone, as: 'zone' }] }]
      },
      { model: User, as: 'waiter', attributes: ['id', 'name'] }
    ]
  });
  if (!order) throw new NotFoundError('Order not found');

  res.json({ success: true, data: { order } });
}));

// POST /api/orders/:id/confirm - Waiter confirms/accepts order
router.post('/:id/confirm', authenticate, authorize('waiter', 'waiter_offtrack', 'admin'), asyncHandler(async (req, res) => {
  const order = await Order.findByPk(req.params.id, {
    include: [
      { model: OrderItem, as: 'items', include: [{ model: MenuItem, as: 'menuItem' }] },
      { model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] }
    ]
  });
  if (!order) throw new NotFoundError('Order not found');

  order.status = 'confirmed';
  order.waiterId = req.user.id;
  await order.save();

  // Mark the newOrder notification as read for this order
  const notifications = await Notification.findAll({
    where: { type: 'newOrder', isRead: false }
  });
  for (const notif of notifications) {
    if (notif.data && notif.data.orderId === order.id) {
      notif.isRead = true;
      await notif.save();
    }
  }

  // Items stay 'pending' (which means NEW to the kitchen)
  // because Order.status is now 'confirmed'

  // Notify kitchen/bar displays via SSE
  const items = await OrderItem.findAll({
    where: { orderId: order.id },
    include: [
      { model: MenuItem, as: 'menuItem' },
      { model: require('../models/OrderDestination'), as: 'destination' }
    ]
  });

  // Group items by destination and send SSE to each
  const byDestination = {};
  items.forEach(item => {
    const destId = item.destinationId;
    if (!byDestination[destId]) byDestination[destId] = [];
    byDestination[destId].push(item);
  });

  Object.entries(byDestination).forEach(([destId, destItems]) => {
    sseService.sendToDestination(destId, {
      type: 'newOrderItems',
      orderId: order.id,
      tableName: order.tableSession?.table?.name,
      items: destItems.map(i => ({
        id: i.id,
        name: i.menuItem.name,
        quantity: i.quantity,
        notes: i.notes
      }))
    });
  });

  res.json({ success: true, data: { order } });
}));

// POST /api/orders/items/:itemId/ready - Mark single item ready
router.post('/items/:itemId/ready', authenticate, asyncHandler(async (req, res) => {
  const item = await OrderItem.findByPk(req.params.itemId, {
    include: [
      { model: Order, as: 'order', include: [{ model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] }] },
      { model: MenuItem, as: 'menuItem' }
    ]
  });
  if (!item) throw new NotFoundError('Order item not found');

  item.status = 'ready';
  await item.save();

  // Check if all items in order are ready
  const allItems = await OrderItem.findAll({ where: { orderId: item.orderId } });
  const allReady = allItems.every(i => i.status === 'ready' || i.status === 'served');

  if (allReady) {
    await Order.update({ status: 'ready' }, { where: { id: item.orderId } });
  }

  // Notify the assigned waiter
  const order = item.order;
  if (order.waiterId) {
    sseService.sendToUser(order.waiterId, {
      type: 'itemReady',
      orderId: order.id,
      itemName: item.menuItem.name,
      tableName: order.tableSession?.table?.name,
      allReady
    });
  }

  res.json({ success: true, data: { item, allReady } });
}));

// PATCH /api/orders/items/:itemId/status - Kitchen/Bar drag-and-drop status update
router.patch('/items/:itemId/status', authenticate, asyncHandler(async (req, res) => {
  const { status } = req.body;
  
  if (!['pending', 'preparing', 'ready', 'served'].includes(status)) {
    throw new BadRequestError('Invalid status');
  }

  const item = await OrderItem.findByPk(req.params.itemId, {
    include: [
      { model: Order, as: 'order', include: [{ model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] }] },
      { model: MenuItem, as: 'menuItem' }
    ]
  });
  
  if (!item) throw new NotFoundError('Order item not found');

  item.status = status;
  await item.save();

  // If marked ready/served, check if entire order is ready
  let allReady = false;
  if (['ready', 'served'].includes(status)) {
    const allItems = await OrderItem.findAll({ where: { orderId: item.orderId } });
    allReady = allItems.every(i => i.status === 'ready' || i.status === 'served');
    if (allReady) {
      await Order.update({ status: 'ready' }, { where: { id: item.orderId } });
    }
  }

  // Notify the assigning waiter if marked reading
  const order = item.order;
  if (status === 'ready' && order.waiterId) {
    sseService.sendToUser(order.waiterId, {
      type: 'itemReady',
      orderId: order.id,
      itemName: item.menuItem.name,
      tableName: order.tableSession?.table?.name,
      allReady
    });
  }

  // Push SSE to the exact destination so all iPads instantly sync the drag-and-drop move
  if (item.destinationId) {
    sseService.sendToDestination(item.destinationId, {
      type: 'itemStatusChanged',
      itemId: item.id,
      status: status
    });
  }

  res.json({ success: true, data: { item, allReady } });
}));

// POST /api/orders/:id/served - Mark order as served
router.post('/:id/served', authenticate, authorize('waiter', 'waiter_offtrack', 'admin'), asyncHandler(async (req, res) => {
  const order = await Order.findByPk(req.params.id);
  if (!order) throw new NotFoundError('Order not found');

  order.status = 'served';
  await order.save();

  await OrderItem.update(
    { status: 'served' },
    { where: { orderId: order.id } }
  );

  res.json({ success: true, data: { order } });
}));

// GET /api/orders/queue/:destinationId - Kitchen/bar queue
router.get('/queue/:destinationId', authenticate, asyncHandler(async (req, res) => {
  const items = await OrderItem.findAll({
    where: {
      destinationId: req.params.destinationId,
      status: { [Op.in]: ['pending', 'preparing', 'ready'] }
    },
    include: [
      { model: MenuItem, as: 'menuItem' },
      {
        model: Order,
        as: 'order',
        where: { status: { [Op.notIn]: ['pending', 'cancelled'] } },
        include: [{
          model: TableSession,
          as: 'tableSession',
          include: [{ model: Table, as: 'table' }]
        }]
      }
    ],
    order: [['createdAt', 'ASC']]
  });

  res.json({ success: true, data: { items } });
}));

// POST /api/orders/:id/decline - Waiter declines/rejects a customer order
router.post('/:id/decline', authenticate, authorize('waiter', 'waiter_offtrack', 'admin'), asyncHandler(async (req, res) => {
  const { reason } = req.body;
  const order = await Order.findByPk(req.params.id, {
    include: [
      { model: OrderItem, as: 'items', include: [{ model: MenuItem, as: 'menuItem' }] },
      { model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] }
    ]
  });
  if (!order) throw new NotFoundError('Order not found');

  order.status = 'cancelled';
  order.notes = reason ? `Declined: ${reason}` : 'Declined by waiter';
  order.waiterId = req.user.id;
  await order.save();

  // Mark the newOrder notification as read for this order
  const notifications = await Notification.findAll({
    where: { type: 'newOrder', isRead: false }
  });
  for (const notif of notifications) {
    if (notif.data && notif.data.orderId === order.id) {
      notif.isRead = true;
      await notif.save();
    }
  }

  // Cancel all items
  await OrderItem.update(
    { status: 'cancelled' },
    { where: { orderId: order.id } }
  );

  // Notify the zone
  const tableName = order.tableSession?.table?.name || 'Unknown';
  sseService.sendToZone(order.tableSession?.table?.zoneId, {
    type: 'orderDeclined',
    orderId: order.id,
    tableName,
    message: `Order from ${tableName} was declined`
  });

  res.json({ success: true, data: { order } });
}));

// POST /api/orders/waiter-order - Waiter creates order for a table
router.post('/waiter-order', authenticate, authorize('waiter', 'waiter_offtrack', 'admin'), asyncHandler(async (req, res) => {
  const { tableId, items, notes } = req.body;

  if (!tableId || !items || items.length === 0) {
    throw new BadRequestError('Table ID and at least one item are required');
  }

  const table = await Table.findByPk(tableId, {
    include: [{ model: Zone, as: 'zone' }]
  });
  if (!table) throw new NotFoundError('Table not found');

  // Find or create active session
  let session = await TableSession.findOne({
    where: { tableId: table.id, isActive: true }
  });

  if (!session) {
    const qrService = require('../services/qr.service');
    session = await TableSession.create({
      tableId: table.id,
      qrToken: table.qrToken || qrService.generateNewToken()
    });
    await table.update({ status: 'occupied' });
  }

  const t = await sequelize.transaction();
  try {
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

    // Create order - already confirmed since waiter created it
    const order = await Order.create({
      tableSessionId: session.id,
      waiterId: req.user.id,
      totalAmount,
      notes,
      status: 'confirmed'
    }, { transaction: t });

    for (const item of orderItems) {
      await OrderItem.create({
        ...item,
        orderId: order.id,
        status: 'pending' // Waiter orders start as NEW (pending) for kitchen
      }, { transaction: t });
    }

    await t.commit();

    // Fetch full order
    const fullOrder = await Order.findByPk(order.id, {
      include: [{
        model: OrderItem,
        as: 'items',
        include: [
          { model: MenuItem, as: 'menuItem' },
          { model: require('../models/OrderDestination'), as: 'destination' }
        ]
      }]
    });

    // Send to kitchen/bar immediately
    const byDestination = {};
    fullOrder.items.forEach(item => {
      const destId = item.destinationId;
      if (!byDestination[destId]) byDestination[destId] = [];
      byDestination[destId].push(item);
    });

    Object.entries(byDestination).forEach(([destId, destItems]) => {
      sseService.sendToDestination(destId, {
        type: 'newOrderItems',
        orderId: order.id,
        tableName: table.name,
        items: destItems.map(i => ({
          id: i.id,
          name: i.menuItem.name,
          quantity: i.quantity,
          notes: i.notes
        }))
      });
    });

    res.status(201).json({ success: true, data: { order: fullOrder } });
  } catch (err) {
    await t.rollback();
    throw err;
  }
}));

// ═══════════════════════════════════════════════════════════════════
// KITCHEN/BAR DISPLAY — Item Status Management
// ═══════════════════════════════════════════════════════════════════

// PATCH /api/orders/items/:itemId/status — Update item preparation status
router.patch('/items/:itemId/status', authenticate, asyncHandler(async (req, res) => {
  const { status } = req.body;
  const validStatuses = ['pending', 'preparing', 'ready', 'served'];

  if (!status || !validStatuses.includes(status)) {
    throw new BadRequestError(`Invalid status. Must be one of: ${validStatuses.join(', ')}`);
  }

  const item = await OrderItem.findByPk(req.params.itemId, {
    include: [
      { model: MenuItem, as: 'menuItem' },
      {
        model: Order, as: 'order',
        include: [{
          model: TableSession, as: 'tableSession',
          include: [{ model: Table, as: 'table' }]
        }]
      }
    ]
  });

  if (!item) throw new NotFoundError('Order item not found');

  const oldStatus = item.status;
  item.status = status;
  await item.save();

  // Push SSE event to the Kitchen/Bar display
  const tableName = item.order?.tableSession?.table?.name || 'Unknown';
  sseService.sendToDestination(item.destinationId, {
    type: 'item_status_changed',
    data: {
      itemId: item.id,
      orderId: item.orderId,
      menuItemName: item.menuItem?.name || 'Item',
      quantity: item.quantity,
      notes: item.notes,
      oldStatus,
      newStatus: status,
      tableName,
      updatedAt: new Date().toISOString()
    }
  });

  // If item is now ready, notify the waiter
  if (status === 'ready') {
    const order = item.order;
    if (order && order.waiterId) {
      sseService.sendToUser(order.waiterId, {
        type: 'item_ready',
        data: {
          itemName: item.menuItem?.name || 'Item',
          tableName,
          orderId: order.id
        }
      });
    }
  }

  res.json({
    success: true,
    data: {
      item: {
        id: item.id,
        menuItemName: item.menuItem?.name,
        quantity: item.quantity,
        oldStatus,
        newStatus: status,
        tableName
      }
    }
  });
}));

// GET /api/orders/queue/:destinationId — Kitchen/Bar active queue
router.get('/queue/:destinationId', authenticate, asyncHandler(async (req, res) => {
  const items = await OrderItem.findAll({
    where: {
      destinationId: req.params.destinationId,
      status: { [Op.in]: ['pending', 'preparing', 'ready'] }
    },
    include: [
      { model: MenuItem, as: 'menuItem' },
      {
        model: Order, as: 'order',
        where: { status: { [Op.notIn]: ['pending', 'cancelled'] } },
        include: [{
          model: TableSession, as: 'tableSession',
          include: [{ model: Table, as: 'table' }]
        }]
      }
    ],
    order: [['createdAt', 'ASC']]
  });

  // Group items by order
  const orderMap = {};
  items.forEach(item => {
    const orderId = item.orderId;
    if (!orderMap[orderId]) {
      orderMap[orderId] = {
        orderId,
        tableName: item.order?.tableSession?.table?.name || 'Unknown',
        createdAt: item.order?.createdAt,
        items: []
      };
    }
    orderMap[orderId].items.push({
      id: item.id,
      name: item.menuItem?.name || 'Item',
      quantity: item.quantity,
      notes: item.notes,
      status: item.status,
      createdAt: item.createdAt
    });
  });

  const queue = Object.values(orderMap).sort((a, b) =>
    new Date(a.createdAt) - new Date(b.createdAt)
  );

  res.json({ success: true, data: { queue, totalItems: items.length } });
}));

module.exports = router;
