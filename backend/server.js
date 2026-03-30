require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const xssClean = require('xss-clean');
const hpp = require('hpp');
const sequelize = require('./config/database');
const errorHandler = require('./middleware/errorHandler');
require('./services/logs.service').install();

// Import models (this sets up associations)
require('./models');

const app = express();

// Trust proxy — required for rate-limiter behind ngrok/nginx/reverse proxy
app.set('trust proxy', 1);

// ═══════════════════════════════════════════════════════════════════
// SECURITY MIDDLEWARE
// ═══════════════════════════════════════════════════════════════════

// Helmet — HTTP security headers (XSS protection, HSTS, etc.)
app.use(helmet({
  contentSecurityPolicy: false,  // Disabled for Flutter web compatibility
  crossOriginEmbedderPolicy: false
}));

// CORS — Whitelist allowed origins
const allowedOrigins = (process.env.CORS_ORIGINS || '*').split(',').map(s => s.trim());
app.use(cors({
  origin: function(origin, callback) {
    // Allow requests with no origin (mobile apps, curl, server-to-server)
    if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true
}));

// Rate Limiting — General API routes
const generalLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 200,            // 200 requests per minute per IP
  standardHeaders: true,
  legacyHeaders: false,
  validate: { xForwardedForHeader: false },
  message: { success: false, error: 'Too many requests. Please try again later.' }
});

// Rate Limiting — Auth routes (stricter)
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 15,             // 15 login attempts per minute
  standardHeaders: true,
  legacyHeaders: false,
  validate: { xForwardedForHeader: false },
  message: { success: false, error: 'Too many login attempts. Please wait 1 minute.' }
});

// Apply rate limiting
app.use('/api', generalLimiter);
app.use('/api/auth', authLimiter);

// XSS — Sanitize all incoming request data
app.use(xssClean());

// HPP — Prevent HTTP parameter pollution
app.use(hpp());

// Body Parsing with size limits
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true, limit: '2mb' }));

// ═══════════════════════════════════════════════════════════════════
// API ROUTES
// ═══════════════════════════════════════════════════════════════════
app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/shifts', require('./routes/shifts.routes'));
app.use('/api/zones', require('./routes/zones.routes'));
app.use('/api/tables', require('./routes/tables.routes'));
app.use('/api/categories', require('./routes/categories.routes'));
app.use('/api/menu-items', require('./routes/menuItems.routes'));
app.use('/api/destinations', require('./routes/destinations.routes'));
app.use('/api/orders', require('./routes/orders.routes'));
app.use('/api/customer', require('./routes/customer.routes'));
app.use('/api/payments', require('./routes/payments.routes'));
app.use('/api/notifications', require('./routes/notifications.routes'));
app.use('/api/admin', require('./routes/admin.routes'));
app.use('/api/developer', require('./routes/developer.routes'));

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString(), uptime: process.uptime() });
});

// Error handler
app.use(errorHandler);

// ═══════════════════════════════════════════════════════════════════
// STATIC FRONTEND SERVING
// ═══════════════════════════════════════════════════════════════════
const path = require('path');
const frontendPath = path.join(__dirname, '../frontend/build/web');
app.use(express.static(frontendPath));

// Fallback for Flutter web routing (SPA)
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api')) return next();
  res.sendFile(path.join(frontendPath, 'index.html'));
});

// ═══════════════════════════════════════════════════════════════════
// SERVER START
// ═══════════════════════════════════════════════════════════════════
const PORT = process.env.PORT || 3000;

async function start() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    // Sync models (creates/alters tables)
    await sequelize.sync({ alter: process.env.NODE_ENV === 'development' });
    console.log('✅ Database synced');

    // Connect fiscal hardware bridge
    const fiscalService = require('./services/fiscal.service');
    await fiscalService.connect();

    const server = app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
      console.log(`📋 API: http://0.0.0.0:${PORT}/api`);
      console.log(`🔒 Security: Helmet, Rate-Limit, XSS-Clean, HPP enabled`);
    });

    // ── Graceful Shutdown ──────────────────────────────────────────
    const gracefulShutdown = async (signal) => {
      console.log(`\n⚠️  ${signal} received. Shutting down gracefully...`);
      server.close(async () => {
        try {
          await sequelize.close();
          console.log('✅ Database connections closed');
        } catch (e) { /* ignore */ }
        process.exit(0);
      });
      // Force shutdown after 10 seconds
      setTimeout(() => process.exit(1), 10000);
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

  } catch (err) {
    console.error('❌ Failed to start server:', err);
    process.exit(1);
  }
}

start();
