const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const TableSession = sequelize.define('TableSession', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  tableId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Tables', key: 'id' }
  },
  qrToken: {
    type: DataTypes.STRING,
    allowNull: false
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  startedAt: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  endedAt: {
    type: DataTypes.DATE,
    allowNull: true
  }
});

module.exports = TableSession;
