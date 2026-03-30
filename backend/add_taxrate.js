const sequelize = require('./config/database');

async function migrate() {
  try {
    await sequelize.query('ALTER TABLE "MenuItems" ADD COLUMN "taxRate" DECIMAL(5, 2) NOT NULL DEFAULT 18.00;');
    console.log('Successfully added taxRate column to MenuItems.');
  } catch (e) {
    if (e.message.includes('already exists')) {
      console.log('Column taxRate already exists.');
    } else {
      console.error('Error adding column:', e.message);
    }
  }
  process.exit();
}

migrate();
