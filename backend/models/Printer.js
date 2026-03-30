const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Printer = sequelize.define('Printer', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false
  },
  type: {
    type: DataTypes.ENUM('network', 'usb', 'stub'),
    defaultValue: 'stub'
  },
  destinationId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: 'OrderDestinations', key: 'id' }
  },
  ip: {
    type: DataTypes.STRING,
    allowNull: true
  },
  port: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  config: {
    type: DataTypes.JSONB,
    allowNull: true
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
});

module.exports = Printer;

