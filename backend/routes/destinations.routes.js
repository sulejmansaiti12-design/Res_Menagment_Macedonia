const express = require('express');
const router = express.Router();
const { OrderDestination } = require('../models');
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError } = require('../utils/errors');

// GET /api/destinations
router.get('/', authenticate, asyncHandler(async (req, res) => {
  const destinations = await OrderDestination.findAll({
    where: { isActive: true },
    order: [['name', 'ASC']]
  });

  res.json({ success: true, data: { destinations } });
}));

// POST /api/destinations
router.post('/', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { name } = req.body;
  if (!name) throw new BadRequestError('Destination name is required');

  const destination = await OrderDestination.create({ name });
  res.status(201).json({ success: true, data: { destination } });
}));

// PUT /api/destinations/:id
router.put('/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const destination = await OrderDestination.findByPk(req.params.id);
  if (!destination) throw new NotFoundError('Destination not found');

  await destination.update(req.body);
  res.json({ success: true, data: { destination } });
}));

// DELETE /api/destinations/:id
router.delete('/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const destination = await OrderDestination.findByPk(req.params.id);
  if (!destination) throw new NotFoundError('Destination not found');

  await destination.update({ isActive: false });
  res.json({ success: true, message: 'Destination deactivated' });
}));

module.exports = router;
