const express = require('express');
const path = require('path');
const { Sequelize } = require('sequelize');
const bcrypt = require('bcryptjs');

const router = express.Router();
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError, ConflictError } = require('../utils/errors');
const { User } = require('../models');
const logsService = require('../services/logs.service');
const runtimeSettings = require('../services/runtimeSettings.service');
const { readEnvFile, writeEnvFile, setEnvValues, parseEnv } = require('../utils/envFile');

router.use(authenticate, authorize('developer'));

const ENV_PATH = path.join(__dirname, '..', '.env');

function maskEnvValue(v) {
  if (!v) return '';
  const s = String(v);
  if (s.length <= 2) return '*'.repeat(s.length);
  return `${s[0]}***${s[s.length - 1]}`;
}

// -------------------- DB ENV SETTINGS --------------------

router.get('/db-env', asyncHandler(async (req, res) => {
  const text = readEnvFile(ENV_PATH);
  const { entries } = parseEnv(text);

  res.json({
    success: true,
    data: {
      filePath: ENV_PATH,
      db: {
        host: entries.get('DB_HOST') || process.env.DB_HOST || '',
        port: entries.get('DB_PORT') || process.env.DB_PORT || '',
        name: entries.get('DB_NAME') || process.env.DB_NAME || '',
        user: entries.get('DB_USER') || process.env.DB_USER || '',
        passwordMasked: maskEnvValue(entries.get('DB_PASSWORD') || process.env.DB_PASSWORD || ''),
      },
      note: 'Changing DB settings updates backend/.env. Restart backend to apply.',
    },
  });
}));

router.post('/db-env/test', asyncHandler(async (req, res) => {
  const { host, port, name, user, password } = req.body || {};
  if (!host || !port || !name || !user) {
    throw new BadRequestError('host, port, name, user are required');
  }

  const testSequelize = new Sequelize(name, user, password || '', {
    host,
    port,
    dialect: 'postgres',
    logging: false,
    pool: { max: 1, min: 0, acquire: 10000, idle: 5000 },
  });

  try {
    await testSequelize.authenticate();
  } finally {
    await testSequelize.close().catch(() => {});
  }

  res.json({ success: true, data: { ok: true } });
}));

router.put('/db-env', asyncHandler(async (req, res) => {
  const { host, port, name, user, password } = req.body || {};
  if (!host || !port || !name || !user) {
    throw new BadRequestError('host, port, name, user are required');
  }

  const existing = readEnvFile(ENV_PATH);
  const nextText = setEnvValues(existing, {
    DB_HOST: host,
    DB_PORT: port,
    DB_NAME: name,
    DB_USER: user,
    ...(password !== undefined ? { DB_PASSWORD: password } : {}),
  });
  writeEnvFile(ENV_PATH, nextText);

  res.json({
    success: true,
    data: {
      saved: true,
      filePath: ENV_PATH,
      restartRequired: true,
      note: 'Restart backend server to apply new DB settings.',
    },
  });
}));

// -------------------- ADMIN/OWNER MANAGEMENT --------------------

function assertRoleAllowed(role) {
  if (!['admin', 'owner'].includes(role)) {
    throw new BadRequestError('Only admin/owner roles can be managed here');
  }
}

router.get('/users', asyncHandler(async (req, res) => {
  const role = String(req.query.role || '');
  assertRoleAllowed(role);

  const users = await User.findAll({
    where: { role },
    attributes: { exclude: ['password'] },
    order: [['createdAt', 'DESC']],
  });

  res.json({ success: true, data: { users } });
}));

router.post('/users', asyncHandler(async (req, res) => {
  const { username, password, name, role } = req.body || {};
  if (!username || !password || !name || !role) {
    throw new BadRequestError('username, password, name, role are required');
  }
  assertRoleAllowed(role);

  const existing = await User.findOne({ where: { username } });
  if (existing) throw new ConflictError('Username already exists');

  const userCreated = await User.create({ username, password, name, role });
  res.status(201).json({ success: true, data: { user: userCreated.toSafeJSON() } });
}));

router.put('/users/:id', asyncHandler(async (req, res) => {
  const user = await User.findByPk(req.params.id);
  if (!user) throw new NotFoundError('User not found');
  if (!['admin', 'owner'].includes(user.role)) throw new BadRequestError('Only admin/owner can be updated here');

  const { username, password, name, isActive, role } = req.body || {};
  if (role !== undefined) assertRoleAllowed(role);

  const updates = {};
  if (username && username !== user.username) {
    const existing = await User.findOne({ where: { username } });
    if (existing) throw new ConflictError('Username already exists');
    updates.username = username;
  }
  if (name) updates.name = name;
  if (isActive !== undefined) updates.isActive = isActive;
  if (role) updates.role = role;
  if (password) updates.password = await bcrypt.hash(password, 12);

  await user.update(updates);
  res.json({ success: true, data: { user: user.toSafeJSON() } });
}));

router.delete('/users/:id', asyncHandler(async (req, res) => {
  const user = await User.findByPk(req.params.id);
  if (!user) throw new NotFoundError('User not found');
  if (!['admin', 'owner'].includes(user.role)) throw new BadRequestError('Only admin/owner can be deactivated here');
  await user.update({ isActive: false });
  res.json({ success: true, message: 'User deactivated' });
}));

// -------------------- REAL-TIME LOGS --------------------

router.get('/logs', asyncHandler(async (req, res) => {
  const limit = Number(req.query.limit || 200);
  res.json({ success: true, data: { logs: logsService.getRecent(limit) } });
}));

router.get('/logs/sse', asyncHandler(async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  const send = (event, data) => {
    res.write(`event: ${event}\n`);
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  // Send recent logs immediately
  send('snapshot', { logs: logsService.getRecent(200) });

  const unsub = logsService.subscribe((entry) => {
    send('log', entry);
  });

  req.on('close', () => {
    unsub();
  });
}));

// -------------------- FISCAL (NORTH MACEDONIA) SETTINGS --------------------

router.get('/fiscal/providers', asyncHandler(async (req, res) => {
  // This is intentionally a simple list. When you decide the real device/API,
  // we can expand this schema (required fields, connection type, etc.).
  res.json({
    success: true,
    data: {
      providers: [
        { id: 'stub', label: 'Stub (No printing)' },
        { id: 'http', label: 'HTTP Middleware (Synergy/FHP)' },
        { id: 'file', label: 'XML File Drop (Accent/David)' },
      ],
    },
  });
}));

router.get('/fiscal/settings', asyncHandler(async (req, res) => {
  const settings = runtimeSettings.loadSettings();
  const fiscal = settings.fiscal || {};
  res.json({
    success: true,
    data: {
      fiscal: {
        ...fiscal,
        apiKeyMasked: maskEnvValue(fiscal.apiKey || ''),
      },
    },
  });
}));

router.put('/fiscal/settings', asyncHandler(async (req, res) => {
  const { enabled, country, provider, apiBaseUrl, apiKey, deviceId, tin, extra } = req.body || {};
  const current = runtimeSettings.loadSettings();

  const next = runtimeSettings.saveSettings({
    ...current,
    fiscal: {
      ...current.fiscal,
      ...(enabled !== undefined ? { enabled: !!enabled } : {}),
      ...(country !== undefined ? { country } : {}),
      ...(provider !== undefined ? { provider } : {}),
      ...(apiBaseUrl !== undefined ? { apiBaseUrl } : {}),
      ...(apiKey !== undefined ? { apiKey } : {}),
      ...(deviceId !== undefined ? { deviceId } : {}),
      ...(tin !== undefined ? { tin } : {}),
      ...(extra !== undefined ? { extra } : {}),
    },
  });

  res.json({ success: true, data: { fiscal: next.fiscal } });
}));

router.post('/fiscal/test', asyncHandler(async (req, res) => {
  const settings = runtimeSettings.loadSettings();
  if (!settings.fiscal?.enabled) {
    throw new BadRequestError('Fiscal integration is disabled');
  }

  // For now, just a smoke test through the fiscal service stub.
  const receipt = await require('../services/fiscal.service').printFiscalReceipt({
    items: [{ name: 'TEST ITEM', price: 1, quantity: 1 }],
    total: 1,
    paymentMethod: 'cash',
    orderId: 'TEST',
  });

  res.json({ success: true, data: { receipt } });
}));

module.exports = router;

