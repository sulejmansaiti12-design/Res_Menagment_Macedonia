const jwt = require('jsonwebtoken');
const { UnauthorizedError } = require('../utils/errors');

function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new UnauthorizedError('No token provided');
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    throw new UnauthorizedError('Invalid or expired token');
  }
}

function authorize(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      throw new UnauthorizedError('Not authenticated');
    }
    if (!roles.includes(req.user.role)) {
      const { ForbiddenError } = require('../utils/errors');
      throw new ForbiddenError('Insufficient permissions');
    }
    next();
  };
}

module.exports = { authenticate, authorize };
