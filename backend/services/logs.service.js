const { EventEmitter } = require('events');

const DEFAULT_BUFFER_SIZE = 500;

class LogsService {
  constructor() {
    this._installed = false;
    this._emitter = new EventEmitter();
    this._buffer = [];
    this._max = DEFAULT_BUFFER_SIZE;
    this._orig = null;
  }

  install() {
    if (this._installed) return;
    this._installed = true;

    this._orig = {
      log: console.log,
      info: console.info,
      warn: console.warn,
      error: console.error,
    };

    const wrap = (level) => {
      return (...args) => {
        try {
          const msg = args
            .map((a) => {
              if (typeof a === 'string') return a;
              try {
                return JSON.stringify(a);
              } catch (_) {
                return String(a);
              }
            })
            .join(' ');
          this._push({
            ts: new Date().toISOString(),
            level,
            message: msg,
          });
        } catch (_) {
          // Never break logging
        }
        this._orig[level](...args);
      };
    };

    console.log = wrap('log');
    console.info = wrap('info');
    console.warn = wrap('warn');
    console.error = wrap('error');
  }

  _push(entry) {
    this._buffer.push(entry);
    if (this._buffer.length > this._max) {
      this._buffer.splice(0, this._buffer.length - this._max);
    }
    this._emitter.emit('log', entry);
  }

  getRecent(limit = 100) {
    const n = Math.max(0, Math.min(Number(limit) || 0, this._max));
    if (n === 0) return [];
    return this._buffer.slice(-n);
  }

  subscribe(onLog) {
    this._emitter.on('log', onLog);
    return () => this._emitter.off('log', onLog);
  }
}

module.exports = new LogsService();

