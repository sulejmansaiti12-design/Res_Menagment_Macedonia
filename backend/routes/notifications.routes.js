const express = require('express');
const router = express.Router();
const { Notification } = require('../models');
const { authenticate } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const sseService = require('../services/sse.service');
const { Op } = require('sequelize');

// GET /api/notifications - Get notifications for current user/zone
router.get('/', authenticate, asyncHandler(async (req, res) => {
  const { unreadOnly, zoneId, limit = 50 } = req.query;
  const where = {};

  if (zoneId) where.zoneId = zoneId;
  if (['waiter', 'waiter_offtrack'].includes(req.user.role) && !zoneId) {
    // Waiter sees only their notifications
    where[Op.or] = [
      { recipientId: req.user.id },
      { zoneId: { [Op.ne]: null } }
    ];
  }
  if (unreadOnly === 'true') where.isRead = false;

  const notifications = await Notification.findAll({
    where,
    order: [['createdAt', 'DESC']],
    limit: parseInt(limit)
  });

  res.json({ success: true, data: { notifications } });
}));

// PUT /api/notifications/:id/read - Mark notification as read
router.put('/:id/read', authenticate, asyncHandler(async (req, res) => {
  const notification = await Notification.findByPk(req.params.id);
  if (notification) {
    notification.isRead = true;
    await notification.save();
  }

  res.json({ success: true });
}));

// PUT /api/notifications/read-all - Mark all notifications as read
router.put('/read-all', authenticate, asyncHandler(async (req, res) => {
  const { zoneId } = req.body;
  const where = { isRead: false };
  if (zoneId) where.zoneId = zoneId;

  await Notification.update({ isRead: true }, { where });
  res.json({ success: true });
}));

// GET /api/notifications/sse - SSE endpoint for real-time notifications
router.get('/sse', authenticate, (req, res) => {
  const { zoneId } = req.query;
  sseService.addClient(req.user.id, zoneId, res);
});

// GET /api/notifications/sse/destination/:destinationId - SSE for kitchen/bar displays
router.get('/sse/destination/:destinationId', (req, res) => {
  sseService.addDestinationClient(req.params.destinationId, res);
});

module.exports = router;
