const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const OrderItem = sequelize.define('OrderItem', {
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
  menuItemId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'MenuItems', key: 'id' }
  },
  quantity: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1
  },
  unitPrice: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  notes: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  destinationId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'OrderDestinations', key: 'id' }
  },
  status: {
    type: DataTypes.ENUM('pending', 'preparing', 'ready', 'served', 'cancelled'),
    defaultValue: 'pending'
  }
});

module.exports = OrderItem;
