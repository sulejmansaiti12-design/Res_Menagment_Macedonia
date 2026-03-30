const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Order = sequelize.define('Order', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  tableSessionId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'TableSessions', key: 'id' }
  },
  waiterId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: 'Users', key: 'id' }
  },
  status: {
    type: DataTypes.ENUM('pending', 'confirmed', 'preparing', 'ready', 'served', 'paid', 'cancelled'),
    defaultValue: 'pending'
  },
  totalAmount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  orderNumber: {
    type: DataTypes.INTEGER,
    allowNull: true
  }
});

module.exports = Order;
