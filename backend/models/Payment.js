const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Payment = sequelize.define('Payment', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  orderId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Orders', key: 'id' }
  },
  waiterId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Users', key: 'id' }
  },
  shiftId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Shifts', key: 'id' }
  },
  amount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  paymentMethod: {
    type: DataTypes.ENUM('cash', 'card'),
    defaultValue: 'cash'
  },
  isFiscal: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  fiscalNumber: {
    type: DataTypes.STRING,
    allowNull: true
  },
  receiptPrinted: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  paidAt: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  // --- UJP Storno Compliance Fields ---
  isStorno: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  stornoReason: {
    type: DataTypes.STRING,
    allowNull: true
  },
  originalPaymentId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: 'Payments', key: 'id' }
  },
  stornoFiscalNumber: {
    type: DataTypes.STRING,
    allowNull: true
  }
});

module.exports = Payment;
