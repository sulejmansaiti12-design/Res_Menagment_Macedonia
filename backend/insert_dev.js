require('dotenv').config();
const sequelize = require('./config/database');
const { User } = require('./models');

async function insertSystemUsers() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    // Developer user
    const existingDev = await User.findOne({ where: { username: 'dev' } });
    if (!existingDev) {
      await User.create({
        username: 'dev',
        password: 'dev',
        name: 'System Developer',
        role: 'developer'
      });
      console.log('✅ Developer user inserted (username: dev, password: dev)');
    } else {
      console.log('ℹ️  Developer user already exists');
    }

    // Kitchen user (for Kitchen Display PIN login)
    const existingKitchen = await User.findOne({ where: { username: 'kitchen' } });
    if (!existingKitchen) {
      await User.create({
        username: 'kitchen',
        password: '1234',
        name: 'Kitchen Display',
        role: 'kitchen'
      });
      console.log('✅ Kitchen user inserted (username: kitchen, PIN: 1234)');
    } else {
      console.log('ℹ️  Kitchen user already exists');
    }

    // Bar user (for Bar Display PIN login)
    const existingBar = await User.findOne({ where: { username: 'bar' } });
    if (!existingBar) {
      await User.create({
        username: 'bar',
        password: '1234',
        name: 'Bar Display',
        role: 'bar'
      });
      console.log('✅ Bar user inserted (username: bar, PIN: 1234)');
    } else {
      console.log('ℹ️  Bar user already exists');
    }

    console.log('\n🎉 System users check complete!');
    console.log('  Kitchen PIN: 1234');
    console.log('  Bar PIN:     1234');
  } catch(e) {
    console.error('❌ Error:', e.message);
  } finally {
    process.exit(0);
  }
}

insertSystemUsers();
