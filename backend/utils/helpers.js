const { v4: uuidv4 } = require('uuid');

function generateUUID() {
  return uuidv4();
}

function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

function generateRandomToken(length = 32) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

function formatCurrency(amount, currency = 'MKD') {
  return `${Number(amount).toFixed(2)} ${currency}`;
}

module.exports = {
  generateUUID,
  asyncHandler,
  generateRandomToken,
  formatCurrency
};
