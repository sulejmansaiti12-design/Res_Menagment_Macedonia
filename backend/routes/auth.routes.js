const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { User, Shift } = require('../models');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, UnauthorizedError, NotFoundError } = require('../utils/errors');
const { Op } = require('sequelize');

// POST /api/auth/login
// Desktop: { password } only
// Mobile: { username, password }
router.post('/login', asyncHandler(async (req, res) => {
  const { username, password } = req.body;

  if (!password) {
    throw new BadRequestError('Password is required');
  }

  let user;
  if (username) {
    // Mobile login: username + password
    user = await User.findOne({ where: { username, isActive: true } });
  } else {
    throw new BadRequestError('Username is required');
  }

  if (!user) {
    throw new UnauthorizedError('Invalid credentials');
  }

  const isValid = await user.validatePassword(password);
  if (!isValid) {
    throw new UnauthorizedError('Invalid credentials');
  }

  // Check for active shift
  const activeShift = await Shift.findOne({
    where: { waiterId: user.id, endTime: null }
  });

  const token = jwt.sign(
    { id: user.id, username: user.username, role: user.role, name: user.name },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRY || '24h' }
  );

  res.json({
    success: true,
    data: {
      token,
      user: user.toSafeJSON(),
      activeShift: activeShift || null
    }
  });
}));

// GET /api/auth/waiters - Get list of waiters (for mobile login screen)
router.get('/waiters', asyncHandler(async (req, res) => {
  const waiters = await User.findAll({
    where: { role: { [Op.in]: ['waiter', 'waiter_offtrack'] }, isActive: true },
    attributes: ['id', 'username', 'name']
  });

  res.json({
    success: true,
    data: { waiters }
  });
}));

// GET /api/auth/me - Get current user info
const { authenticate } = require('../middleware/auth');
router.get('/me', authenticate, asyncHandler(async (req, res) => {
  const user = await User.findByPk(req.user.id);
  if (!user) throw new NotFoundError('User not found');

  res.json({
    success: true,
    data: { user: user.toSafeJSON() }
  });
}));

module.exports = router;
