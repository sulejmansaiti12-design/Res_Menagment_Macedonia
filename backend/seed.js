require('dotenv').config();
const sequelize = require('./config/database');
const { User, Zone, Table, OrderDestination, Category, MenuItem } = require('./models');
const qrService = require('./services/qr.service');

async function seed() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    // Sync (force: true will DROP existing tables)
    await sequelize.sync({ force: true });
    console.log('✅ Tables created');

    // 1. Create Owner
    const owner = await User.create({
      username: 'owner',
      password: 'owner123',
      name: 'Restaurant Owner',
      role: 'owner'
    });
    console.log('✅ Owner created (username: owner, password: owner123)');

    // 2. Create Admin
    const admin = await User.create({
      username: 'admin',
      password: 'admin123',
      name: 'Restaurant Admin',
      role: 'admin'
    });
    console.log('✅ Admin created (username: admin, password: admin123)');

    // 2.5 Create Developer
    const developer = await User.create({
      username: 'dev',
      password: 'dev',
      name: 'System Developer',
      role: 'developer'
    });
    console.log('✅ Developer created (username: dev, password: dev)');

    // 2.6 Create Kitchen Display User
    const kitchenUser = await User.create({
      username: 'kitchen',
      password: '1234',
      name: 'Kitchen Display',
      role: 'kitchen'
    });
    console.log('✅ Kitchen created (username: kitchen, PIN: 1234)');

    // 2.7 Create Bar Display User
    const barUser = await User.create({
      username: 'bar',
      password: '1234',
      name: 'Bar Display',
      role: 'bar'
    });
    console.log('✅ Bar created (username: bar, PIN: 1234)');

    // 3. Create Waiters
    const waiter1 = await User.create({
      username: 'waiter1',
      password: 'waiter123',
      name: 'Waiter 1',
      role: 'waiter'
    });
    const waiter2 = await User.create({
      username: 'waiter2',
      password: 'waiter123',
      name: 'Waiter 2',
      role: 'waiter'
    });
    console.log('✅ Waiters created (password: waiter123)');

    // 4. Create Zones
    const caffeZone = await Zone.create({
      name: 'Caffe Zone',
      welcomeMessage: 'Welcome to our Café! ☕ Browse our menu and order directly from your phone.'
    });
    const restaurantZone = await Zone.create({
      name: 'Restaurant Zone',
      welcomeMessage: 'Welcome to our Restaurant! 🍽️ Enjoy our delicious menu selection.'
    });
    const barZone = await Zone.create({
      name: 'Bar Zone',
      welcomeMessage: 'Welcome to the Bar! 🍸 Check out our drink specials.'
    });
    console.log('✅ Zones created');

    // 5. Create Order Destinations
    const kitchen = await OrderDestination.create({ name: 'Kitchen' });
    const bar = await OrderDestination.create({ name: 'Bar' });
    console.log('✅ Order destinations created (Kitchen, Bar)');

    // 6. Create Categories
    const food = await Category.create({ name: 'Food', destinationId: kitchen.id, sortOrder: 1 });
    const drinks = await Category.create({ name: 'Drinks', destinationId: bar.id, sortOrder: 2 });
    const smoothies = await Category.create({ name: 'Smoothies', destinationId: bar.id, sortOrder: 3 });
    const desserts = await Category.create({ name: 'Desserts', destinationId: kitchen.id, sortOrder: 4 });
    const coffee = await Category.create({ name: 'Coffee', destinationId: bar.id, sortOrder: 5 });
    console.log('✅ Categories created');

    // 7. Create Menu Items
    // Food
    await MenuItem.create({ name: 'Hamburger', description: 'Classic beef hamburger with fries', price: 250, categoryId: food.id });
    await MenuItem.create({ name: 'Pizza Margherita', description: 'Traditional Italian pizza', price: 350, categoryId: food.id });
    await MenuItem.create({ name: 'Caesar Salad', description: 'Fresh romaine with caesar dressing', price: 200, categoryId: food.id });
    await MenuItem.create({ name: 'Pasta Carbonara', description: 'Creamy pasta with bacon', price: 300, categoryId: food.id });
    await MenuItem.create({ name: 'Grilled Chicken', description: 'Grilled chicken breast with vegetables', price: 280, categoryId: food.id });

    // Drinks
    await MenuItem.create({ name: 'Coca Cola', description: '330ml can', price: 80, categoryId: drinks.id });
    await MenuItem.create({ name: 'Fanta', description: '330ml can', price: 80, categoryId: drinks.id });
    await MenuItem.create({ name: 'Water', description: '500ml bottle', price: 50, categoryId: drinks.id });
    await MenuItem.create({ name: 'Fresh Orange Juice', description: 'Freshly squeezed', price: 120, categoryId: drinks.id });

    // Smoothies
    await MenuItem.create({ name: 'Strawberry Smoothie', description: 'Fresh strawberry blend', price: 150, categoryId: smoothies.id });
    await MenuItem.create({ name: 'Banana Smoothie', description: 'Banana with milk', price: 150, categoryId: smoothies.id });
    await MenuItem.create({ name: 'Mixed Berry Smoothie', description: 'Mixed berries blend', price: 180, categoryId: smoothies.id });

    // Desserts
    await MenuItem.create({ name: 'Chocolate Cake', description: 'Rich chocolate cake slice', price: 160, categoryId: desserts.id });
    await MenuItem.create({ name: 'Tiramisu', description: 'Classic Italian tiramisu', price: 180, categoryId: desserts.id });

    // Coffee
    await MenuItem.create({ name: 'Espresso', description: 'Double shot', price: 60, categoryId: coffee.id });
    await MenuItem.create({ name: 'Cappuccino', description: 'Espresso with foamed milk', price: 90, categoryId: coffee.id });
    await MenuItem.create({ name: 'Latte', description: 'Espresso with steamed milk', price: 100, categoryId: coffee.id });
    await MenuItem.create({ name: 'Turkish Coffee', description: 'Traditional Turkish style', price: 50, categoryId: coffee.id });

    console.log('✅ Menu items created');

    // 8. Create Tables
    const tables = [];
    for (let i = 1; i <= 5; i++) {
      const t = await Table.create({
        name: `Table ${i}`,
        zoneId: caffeZone.id,
        qrToken: qrService.generateNewToken()
      });
      tables.push(t);
    }
    for (let i = 6; i <= 10; i++) {
      const t = await Table.create({
        name: `Table ${i}`,
        zoneId: restaurantZone.id,
        qrToken: qrService.generateNewToken()
      });
      tables.push(t);
    }
    for (let i = 11; i <= 13; i++) {
      const t = await Table.create({
        name: `Table ${i}`,
        zoneId: barZone.id,
        qrToken: qrService.generateNewToken()
      });
      tables.push(t);
    }
    console.log('✅ Tables created (13 tables across 3 zones)');

    console.log('\n🎉 Database seeded successfully!');
    console.log('\nLogin credentials:');
    console.log('  Owner:   username=owner, password=owner123');
    console.log('  Admin:   username=admin, password=admin123');
    console.log('  Kitchen: username=kitchen, PIN=1234');
    console.log('  Bar:     username=bar, PIN=1234');
    console.log('  Waiter1: username=waiter1, password=waiter123');
    console.log('  Waiter2: username=waiter2, password=waiter123');

    process.exit(0);
  } catch (err) {
    console.error('❌ Seed failed:', err);
    process.exit(1);
  }
}

seed();
