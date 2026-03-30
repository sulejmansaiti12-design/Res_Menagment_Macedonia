const express = require('express');
const router = express.Router();
const { MenuItem, Category } = require('../models');
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError } = require('../utils/errors');

// GET /api/menu-items
router.get('/', asyncHandler(async (req, res) => {
  const { categoryId } = req.query;
  const where = { isAvailable: true };
  if (categoryId) where.categoryId = categoryId;

  const items = await MenuItem.findAll({
    where,
    include: [{ model: Category, as: 'category' }],
    order: [['name', 'ASC']]
  });

  res.json({ success: true, data: { items } });
}));

// GET /api/menu-items/:id
router.get('/:id', asyncHandler(async (req, res) => {
  const item = await MenuItem.findByPk(req.params.id, {
    include: [{ model: Category, as: 'category' }]
  });
  if (!item) throw new NotFoundError('Menu item not found');

  res.json({ success: true, data: { item } });
}));

// POST /api/menu-items
router.post('/', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const { name, description, price, categoryId, imageUrl, taxRate } = req.body;
  if (!name || !price || !categoryId) throw new BadRequestError('Name, price, and category are required');

  const category = await Category.findByPk(categoryId);
  if (!category) throw new NotFoundError('Category not found');

  const item = await MenuItem.create({ name, description, price, categoryId, imageUrl, taxRate });
  res.status(201).json({ success: true, data: { item } });
}));

// PUT /api/menu-items/:id
router.put('/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const item = await MenuItem.findByPk(req.params.id);
  if (!item) throw new NotFoundError('Menu item not found');

  const { name, description, price, categoryId, imageUrl, isAvailable, taxRate } = req.body;
  if (categoryId) {
    const category = await Category.findByPk(categoryId);
    if (!category) throw new NotFoundError('Category not found');
  }

  await item.update({ name, description, price, categoryId, imageUrl, isAvailable, taxRate });
  res.json({ success: true, data: { item } });
}));

// DELETE /api/menu-items/:id
router.delete('/:id', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const item = await MenuItem.findByPk(req.params.id);
  if (!item) throw new NotFoundError('Menu item not found');

  await item.update({ isAvailable: false });
  res.json({ success: true, message: 'Menu item deactivated' });
}));

module.exports = router;
