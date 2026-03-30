const express = require('express');
const router = express.Router();
const { Zone, Table } = require('../models');
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError } = require('../utils/errors');

// GET /api/zones
router.get('/', authenticate, asyncHandler(async (req, res) => {
  const zones = await Zone.findAll({
    where: { isActive: true },
    include: [{ model: Table, as: 'tables' }],
    order: [['name', 'ASC']]
  });

  res.json({ success: true, data: { zones } });
}));

// GET /api/zones/:id
router.get('/:id', authenticate, asyncHandler(async (req, res) => {
  const zone = await Zone.findByPk(req.params.id, {
    include: [{ model: Table, as: 'tables' }]
  });
  if (!zone) throw new NotFoundError('Zone not found');

  res.json({ success: true, data: { zone } });
}));

// POST /api/zones
router.post('/', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { name, welcomeMessage } = req.body;
  if (!name) throw new BadRequestError('Zone name is required');

  const zone = await Zone.create({ name, welcomeMessage });
  res.status(201).json({ success: true, data: { zone } });
}));

// PUT /api/zones/:id
router.put('/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const zone = await Zone.findByPk(req.params.id);
  if (!zone) throw new NotFoundError('Zone not found');

  const { name, welcomeMessage, isActive } = req.body;
  await zone.update({ name, welcomeMessage, isActive });

  res.json({ success: true, data: { zone } });
}));

// DELETE /api/zones/:id
router.delete('/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const zone = await Zone.findByPk(req.params.id);
  if (!zone) throw new NotFoundError('Zone not found');

  await zone.update({ isActive: false });
  res.json({ success: true, message: 'Zone deactivated' });
}));

module.exports = router;
