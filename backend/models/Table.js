const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Table = sequelize.define('Table', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false
  },
  zoneId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: 'Zones', key: 'id' }
  },
  qrToken: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true
  },
  status: {
    type: DataTypes.ENUM('free', 'occupied', 'needsAttention'),
    defaultValue: 'free'
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  // ── Floor Plan Fields ──────────────────────────────────────────
  posX: {
    type: DataTypes.FLOAT,
    defaultValue: 0
  },
  posY: {
    type: DataTypes.FLOAT,
    defaultValue: 0
  },
  width: {
    type: DataTypes.FLOAT,
    defaultValue: 80
  },
  height: {
    type: DataTypes.FLOAT,
    defaultValue: 80
  },
  shape: {
    type: DataTypes.ENUM('square', 'circle', 'rectangle'),
    defaultValue: 'square'
  },
  rotation: {
    type: DataTypes.FLOAT,
    defaultValue: 0
  },
  capacity: {
    type: DataTypes.INTEGER,
    defaultValue: 4
  }
});

module.exports = Table;
