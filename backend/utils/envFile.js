const fs = require('fs');

function parseEnv(text) {
  const lines = text.split(/\r?\n/);
  const entries = new Map();
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = line.indexOf('=');
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1);
    entries.set(key, value);
  }
  return { lines, entries };
}

function setEnvValues(text, updates) {
  const { lines, entries } = parseEnv(text);
  const keys = Object.keys(updates);

  const updated = lines.map((line) => {
    const idx = line.indexOf('=');
    if (idx === -1) return line;
    const key = line.slice(0, idx).trim();
    if (!keys.includes(key)) return line;
    entries.set(key, String(updates[key] ?? ''));
    return `${key}=${entries.get(key)}`;
  });

  for (const key of keys) {
    if (!entries.has(key)) {
      updated.push(`${key}=${String(updates[key] ?? '')}`);
      entries.set(key, String(updates[key] ?? ''));
    }
  }

  return updated.join('\n');
}

function readEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return '';
  return fs.readFileSync(filePath, 'utf8');
}

function writeEnvFile(filePath, text) {
  fs.writeFileSync(filePath, text, 'utf8');
}

module.exports = { parseEnv, setEnvValues, readEnvFile, writeEnvFile };

