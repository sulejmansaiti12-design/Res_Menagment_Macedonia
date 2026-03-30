const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Shift = sequelize.define('Shift', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  waiterId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Users', key: 'id' }
  },
  zoneId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Zones', key: 'id' }
  },
  isOffTrack: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  startTime: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW
  },
  endTime: {
    type: DataTypes.DATE,
    allowNull: true
  },
  totalCashCollected: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0
  },
  totalFiscal: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0
  },
  totalOffTrack: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0
  }
});

module.exports = Shift;
