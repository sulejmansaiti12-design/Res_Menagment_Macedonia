require('dotenv').config();
const sequelize = require('./config/database');

// Load all models (this sets up associations + includes the new taxRate field)
require('./models');

async function reset() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    // Force: true = DROP all tables then recreate from current models
    await sequelize.sync({ force: true });
    console.log('✅ All tables dropped and recreated (clean slate)');

    // Seed default accounts — password is auto-hashed by the model's beforeCreate hook
    const { User } = require('./models');

    await User.create({ username: 'developer', password: 'dev123', name: 'Developer', role: 'developer' });
    await User.create({ username: 'admin', password: 'admin123', name: 'Admin', role: 'admin' });
    await User.create({ username: 'owner', password: 'owner123', name: 'Owner', role: 'owner' });

    console.log('✅ Default accounts seeded:');
    console.log('   developer / dev123');
    console.log('   admin     / admin123');
    console.log('   owner     / owner123');

    process.exit(0);
  } catch (err) {
    console.error('❌ Reset failed:', err);
    process.exit(1);
  }
}

reset();
