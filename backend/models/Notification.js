const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Notification = sequelize.define('Notification', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  recipientId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: 'Users', key: 'id' }
  },
  zoneId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: 'Zones', key: 'id' }
  },
  type: {
    type: DataTypes.ENUM(
      'newOrder', 'orderReady', 'callWaiter',
      'requestBill', 'requestWater', 'zoneChange',
      'orderConfirmed', 'shiftStarted', 'shiftEnded'
    ),
    allowNull: false
  },
  title: {
    type: DataTypes.STRING,
    allowNull: false
  },
  message: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  data: {
    type: DataTypes.JSONB,
    allowNull: true
  },
  isRead: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  }
});

module.exports = Notification;
