require('dotenv').config();
const seq = require('./config/database');

async function migrate() {
  try {
    await seq.authenticate();
    console.log('Connected to database');
    
    await seq.query(
      "ALTER TYPE \"enum_OrderItems_status\" ADD VALUE IF NOT EXISTS 'cancelled';"
    );
    
    console.log('SUCCESS: cancelled added to OrderItems status enum');
    process.exit(0);
  } catch (e) {
    if (e.message && e.message.includes('already exists')) {
      console.log('Value already exists, skipping');
      process.exit(0);
    }
    console.error('ERROR:', e.message);
    process.exit(1);
  }
}

migrate();
