const User = require('./User');
const Zone = require('./Zone');
const Table = require('./Table');
const TableSession = require('./TableSession');
const OrderDestination = require('./OrderDestination');
const Category = require('./Category');
const MenuItem = require('./MenuItem');
const Order = require('./Order');
const OrderItem = require('./OrderItem');
const Shift = require('./Shift');
const Payment = require('./Payment');
const Notification = require('./Notification');
const Printer = require('./Printer');
const EndOfDayClose = require('./EndOfDayClose');

// Zone <-> Table
Zone.hasMany(Table, { foreignKey: 'zoneId', as: 'tables' });
Table.belongsTo(Zone, { foreignKey: 'zoneId', as: 'zone' });

// Table <-> TableSession
Table.hasMany(TableSession, { foreignKey: 'tableId', as: 'sessions' });
TableSession.belongsTo(Table, { foreignKey: 'tableId', as: 'table' });

// TableSession <-> Order
TableSession.hasMany(Order, { foreignKey: 'tableSessionId', as: 'orders' });
Order.belongsTo(TableSession, { foreignKey: 'tableSessionId', as: 'tableSession' });

// User (waiter) <-> Order
User.hasMany(Order, { foreignKey: 'waiterId', as: 'orders' });
Order.belongsTo(User, { foreignKey: 'waiterId', as: 'waiter' });

// Order <-> OrderItem
Order.hasMany(OrderItem, { foreignKey: 'orderId', as: 'items' });
OrderItem.belongsTo(Order, { foreignKey: 'orderId', as: 'order' });

// MenuItem <-> OrderItem
MenuItem.hasMany(OrderItem, { foreignKey: 'menuItemId', as: 'orderItems' });
OrderItem.belongsTo(MenuItem, { foreignKey: 'menuItemId', as: 'menuItem' });

// Category <-> MenuItem
Category.hasMany(MenuItem, { foreignKey: 'categoryId', as: 'items' });
MenuItem.belongsTo(Category, { foreignKey: 'categoryId', as: 'category' });

// OrderDestination <-> Category
OrderDestination.hasMany(Category, { foreignKey: 'destinationId', as: 'categories' });
Category.belongsTo(OrderDestination, { foreignKey: 'destinationId', as: 'destination' });

// OrderDestination <-> OrderItem
OrderDestination.hasMany(OrderItem, { foreignKey: 'destinationId', as: 'orderItems' });
OrderItem.belongsTo(OrderDestination, { foreignKey: 'destinationId', as: 'destination' });

// User (waiter) <-> Shift
User.hasMany(Shift, { foreignKey: 'waiterId', as: 'shifts' });
Shift.belongsTo(User, { foreignKey: 'waiterId', as: 'waiter' });

// Zone <-> Shift
Zone.hasMany(Shift, { foreignKey: 'zoneId', as: 'shifts' });
Shift.belongsTo(Zone, { foreignKey: 'zoneId', as: 'zone' });

// Order <-> Payment
Order.hasOne(Payment, { foreignKey: 'orderId', as: 'payment' });
Payment.belongsTo(Order, { foreignKey: 'orderId', as: 'order' });

// User (waiter) <-> Payment
User.hasMany(Payment, { foreignKey: 'waiterId', as: 'payments' });
Payment.belongsTo(User, { foreignKey: 'waiterId', as: 'waiter' });

// Shift <-> Payment
Shift.hasMany(Payment, { foreignKey: 'shiftId', as: 'payments' });
Payment.belongsTo(Shift, { foreignKey: 'shiftId', as: 'shift' });

// Notification <-> User
User.hasMany(Notification, { foreignKey: 'recipientId', as: 'notifications' });
Notification.belongsTo(User, { foreignKey: 'recipientId', as: 'recipient' });

// Notification <-> Zone
Zone.hasMany(Notification, { foreignKey: 'zoneId', as: 'notifications' });
Notification.belongsTo(Zone, { foreignKey: 'zoneId', as: 'zone' });

// Printer <-> OrderDestination (optional)
OrderDestination.hasMany(Printer, { foreignKey: 'destinationId', as: 'printers' });
Printer.belongsTo(OrderDestination, { foreignKey: 'destinationId', as: 'destination' });

// EndOfDayClose <-> User (optional)
User.hasMany(EndOfDayClose, { foreignKey: 'closedByUserId', as: 'endOfDayCloses' });
EndOfDayClose.belongsTo(User, { foreignKey: 'closedByUserId', as: 'closedBy' });

module.exports = {
  User,
  Zone,
  Table,
  TableSession,
  OrderDestination,
  Category,
  MenuItem,
  Order,
  OrderItem,
  Shift,
  Payment,
  Notification,
  Printer,
  EndOfDayClose
};
