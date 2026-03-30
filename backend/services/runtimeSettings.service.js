const fs = require('fs');
const path = require('path');

const SETTINGS_PATH = path.join(__dirname, '..', 'config', 'runtime-settings.json');

const DEFAULT_SETTINGS = {
  fiscal: {
    enabled: false,
    country: 'MK',
    provider: 'stub',
    apiBaseUrl: '',
    apiKey: '',
    deviceId: '',
    tin: '',
    extra: {},
  },
};

function _ensureDir() {
  const dir = path.dirname(SETTINGS_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function loadSettings() {
  _ensureDir();
  if (!fs.existsSync(SETTINGS_PATH)) return { ...DEFAULT_SETTINGS };
  try {
    const parsed = JSON.parse(fs.readFileSync(SETTINGS_PATH, 'utf8'));
    return {
      ...DEFAULT_SETTINGS,
      ...parsed,
      fiscal: { ...DEFAULT_SETTINGS.fiscal, ...(parsed.fiscal || {}) },
    };
  } catch (_) {
    return { ...DEFAULT_SETTINGS };
  }
}

function saveSettings(next) {
  _ensureDir();
  const merged = {
    ...DEFAULT_SETTINGS,
    ...next,
    fiscal: { ...DEFAULT_SETTINGS.fiscal, ...(next.fiscal || {}) },
  };
  fs.writeFileSync(SETTINGS_PATH, JSON.stringify(merged, null, 2), 'utf8');
  return merged;
}

module.exports = {
  loadSettings,
  saveSettings,
  SETTINGS_PATH,
  DEFAULT_SETTINGS,
};

