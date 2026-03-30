const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

// Z-close record (end-of-day close + reconciliation snapshot)
const EndOfDayClose = sequelize.define('EndOfDayClose', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  businessDate: {
    // YYYY-MM-DD in local time
    type: DataTypes.STRING,
    allowNull: false,
    unique: true
  },
  expectedCash: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  actualCash: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  difference: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  summary: {
    // JSON snapshot: totals by method + fiscal/off-track + counts
    type: DataTypes.JSONB,
    allowNull: false
  },
  closedByUserId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: { model: 'Users', key: 'id' }
  },
  fiscalZReport: {
    // provider/device response (if any)
    type: DataTypes.JSONB,
    allowNull: true
  }
});

module.exports = EndOfDayClose;

