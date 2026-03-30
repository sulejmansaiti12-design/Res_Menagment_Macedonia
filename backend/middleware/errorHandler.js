const { formatErrorResponse } = require('../utils/errors');

function errorHandler(err, req, res, next) {
  console.error('Error:', err);

  if (err.isOperational) {
    return res.status(err.statusCode).json(formatErrorResponse(err));
  }

  // Sequelize validation errors
  if (err.name === 'SequelizeValidationError') {
    return res.status(422).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Validation failed',
        errors: err.errors.map(e => ({
          field: e.path,
          message: e.message
        }))
      }
    });
  }

  // Sequelize unique constraint
  if (err.name === 'SequelizeUniqueConstraintError') {
    return res.status(409).json({
      success: false,
      error: {
        code: 'CONFLICT',
        message: 'Resource already exists',
        errors: err.errors.map(e => ({
          field: e.path,
          message: e.message
        }))
      }
    });
  }

  // Default 500
  return res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
    }
  });
}

module.exports = errorHandler;
