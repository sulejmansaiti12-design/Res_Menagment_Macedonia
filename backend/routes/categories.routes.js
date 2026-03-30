const express = require('express');
const router = express.Router();
const { Category, OrderDestination, MenuItem } = require('../models');
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError } = require('../utils/errors');

// GET /api/categories
router.get('/', asyncHandler(async (req, res) => {
  const categories = await Category.findAll({
    where: { isActive: true },
    include: [
      { model: OrderDestination, as: 'destination' },
      { model: MenuItem, as: 'items', where: { isAvailable: true }, required: false }
    ],
    order: [['sortOrder', 'ASC'], ['name', 'ASC']]
  });

  res.json({ success: true, data: { categories } });
}));

// GET /api/categories/:id
router.get('/:id', asyncHandler(async (req, res) => {
  const category = await Category.findByPk(req.params.id, {
    include: [
      { model: OrderDestination, as: 'destination' },
      { model: MenuItem, as: 'items' }
    ]
  });
  if (!category) throw new NotFoundError('Category not found');

  res.json({ success: true, data: { category } });
}));

// POST /api/categories
router.post('/', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { name, destinationId, sortOrder } = req.body;
  if (!name || !destinationId) throw new BadRequestError('Category name and destination are required');

  const destination = await OrderDestination.findByPk(destinationId);
  if (!destination) throw new NotFoundError('Order destination not found');

  const category = await Category.create({ name, destinationId, sortOrder: sortOrder || 0 });
  res.status(201).json({ success: true, data: { category } });
}));

// PUT /api/categories/:id
router.put('/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const category = await Category.findByPk(req.params.id);
  if (!category) throw new NotFoundError('Category not found');

  const { name, destinationId, sortOrder, isActive } = req.body;
  if (destinationId) {
    const destination = await OrderDestination.findByPk(destinationId);
    if (!destination) throw new NotFoundError('Order destination not found');
  }

  await category.update({ name, destinationId, sortOrder, isActive });
  res.json({ success: true, data: { category } });
}));

// DELETE /api/categories/:id
router.delete('/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const category = await Category.findByPk(req.params.id);
  if (!category) throw new NotFoundError('Category not found');

  await category.update({ isActive: false });
  res.json({ success: true, message: 'Category deactivated' });
}));

module.exports = router;
