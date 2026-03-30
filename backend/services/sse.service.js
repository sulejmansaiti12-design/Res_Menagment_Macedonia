/**
 * SSE (Server-Sent Events) Service — Production Grade
 * 
 * Manages real-time connections for:
 * - Waiter notifications (per user/zone)
 * - Kitchen/Bar displays (per destination)
 * 
 * Features:
 * - Heartbeat pings every 30s to keep connections alive
 * - Connection pool limit (max 200 clients)
 * - Graceful disconnect handling
 * - Event buffering for destination channels
 */

const MAX_CLIENTS = 200;

// Map<clientId, { res, zoneId?, destinationId?, lastActivity }>
const clients = new Map();

// ── Heartbeat ──────────────────────────────────────────────────────
// Send a comment ping every 30s to keep SSE connections alive through proxies
setInterval(() => {
  const now = Date.now();
  clients.forEach((client, clientId) => {
    try {
      client.res.write(`:heartbeat ${now}\n\n`);
      client.lastActivity = now;
    } catch (e) {
      // Connection is dead, clean up
      clients.delete(clientId);
    }
  });
}, 30000);

// ── Connection Management ──────────────────────────────────────────

function _setupSSEHeaders(res) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no', // Disable nginx buffering
    'Access-Control-Allow-Origin': '*'
  });
  // Flush headers immediately
  res.flushHeaders();
}

function addClient(userId, zoneId, res) {
  if (clients.size >= MAX_CLIENTS) {
    console.warn(`[SSE] Max clients reached (${MAX_CLIENTS}). Rejecting connection for user ${userId}`);
    res.status(503).json({ error: 'Server busy. Too many active connections.' });
    return false;
  }

  _setupSSEHeaders(res);

  // Send initial connection event with retry hint
  res.write(`retry: 5000\n`);
  res.write(`data: ${JSON.stringify({ type: 'connected', message: 'SSE connected', userId })}\n\n`);

  // Remove existing connection for this user (prevent duplicates)
  if (clients.has(userId)) {
    try { clients.get(userId).res.end(); } catch (e) { /* ignore */ }
    clients.delete(userId);
  }

  clients.set(userId, { res, zoneId, lastActivity: Date.now() });

  req_cleanup(userId, res);
  return true;
}

function addDestinationClient(destinationId, res) {
  if (clients.size >= MAX_CLIENTS) {
    res.status(503).json({ error: 'Server busy. Too many active connections.' });
    return false;
  }

  _setupSSEHeaders(res);

  const clientId = `dest_${destinationId}_${Date.now()}`;
  res.write(`retry: 5000\n`);
  res.write(`data: ${JSON.stringify({ type: 'connected', message: 'Kitchen/Bar display connected', destinationId })}\n\n`);

  clients.set(clientId, { res, destinationId, lastActivity: Date.now() });

  req_cleanup(clientId, res);
  return true;
}

function req_cleanup(clientId, res) {
  res.on('close', () => {
    clients.delete(clientId);
  });
  res.on('error', () => {
    clients.delete(clientId);
  });
}

// ── Event Sending ──────────────────────────────────────────────────

function _flush(res) {
  // Pad with 1KB of whitespace to force Nginx/proxies/Android HTTP to push through small buffers
  res.write(': ' + ' '.repeat(1024) + '\n\n');
  if (typeof res.flush === 'function') res.flush();
}

function sendToUser(userId, event) {
  const client = clients.get(userId);
  if (client) {
    try {
      client.res.write(`data: ${JSON.stringify(event)}\n\n`);
      _flush(client.res);
      client.lastActivity = Date.now();
      return true;
    } catch (e) {
      clients.delete(userId);
      return false;
    }
  }
  return false;
}

function sendToZone(zoneId, event) {
  let sent = 0;
  clients.forEach((client, clientId) => {
    if (client.zoneId === zoneId) {
      try {
        client.res.write(`data: ${JSON.stringify(event)}\n\n`);
        _flush(client.res);
        client.lastActivity = Date.now();
        sent++;
      } catch (e) {
        clients.delete(clientId);
      }
    }
  });
  return sent;
}

function sendToDestination(destinationId, event) {
  let sent = 0;
  clients.forEach((client, clientId) => {
    if (client.destinationId === destinationId) {
      try {
        client.res.write(`data: ${JSON.stringify(event)}\n\n`);
        _flush(client.res);
        client.lastActivity = Date.now();
        sent++;
      } catch (e) {
        clients.delete(clientId);
      }
    }
  });
  return sent;
}

function sendToAll(event) {
  clients.forEach((client, clientId) => {
    try {
      client.res.write(`data: ${JSON.stringify(event)}\n\n`);
    } catch (e) {
      clients.delete(clientId);
    }
  });
}

function updateClientZone(userId, newZoneId) {
  const client = clients.get(userId);
  if (client) {
    client.zoneId = newZoneId;
  }
}

function getConnectedClients() {
  const result = [];
  clients.forEach((client, clientId) => {
    result.push({
      clientId,
      zoneId: client.zoneId || null,
      destinationId: client.destinationId || null,
      lastActivity: client.lastActivity
    });
  });
  return result;
}

function getClientCount() {
  return clients.size;
}

module.exports = {
  addClient,
  sendToUser,
  sendToZone,
  sendToDestination,
  addDestinationClient,
  sendToAll,
  updateClientZone,
  getConnectedClients,
  getClientCount,
  MAX_CLIENTS
};
