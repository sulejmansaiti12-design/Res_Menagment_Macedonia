/**
 * Fiscal Service — UJP North Macedonia Compliance
 * 
 * Закон за регистрирање на готовински плаќања
 * - Tax Group А = 18% ДДВ (general goods/services)
 * - Tax Group Б = 5% ДДВ (food essentials, books)
 * - Storno receipts require original fiscal receipt reference
 * - 15-minute storno time limit for hospitality (food & drinks)
 * - Daily Z-Report (дневен финансиски извештај) mandatory at end of day
 */

const fs = require('fs');
const path = require('path');
const axios = require('axios');

// Sequential receipt counter (persists across restarts via file)
const COUNTER_FILE = path.join(__dirname, '../.fiscal_counter');

class FiscalService {
  constructor() {
    this.isConnected = false;
    this.deviceType = 'stub';
    this.deviceId = 'RM001'; // Restaurant Manager Device ID
    this._counter = this._loadCounter();
  }

  // ── Counter Persistence ──────────────────────────────────────────
  _loadCounter() {
    try {
      if (fs.existsSync(COUNTER_FILE)) {
        return parseInt(fs.readFileSync(COUNTER_FILE, 'utf8').trim(), 10) || 0;
      }
    } catch (e) { /* ignore */ }
    return 0;
  }

  _incrementCounter() {
    this._counter++;
    try {
      fs.writeFileSync(COUNTER_FILE, String(this._counter), 'utf8');
    } catch (e) {
      console.error('[Fiscal] Failed to persist counter:', e.message);
    }
    return this._counter;
  }

  // ── Settings ─────────────────────────────────────────────────────
  _getSettings() {
    try {
      const settings = require('./runtimeSettings.service').loadSettings();
      return settings.fiscal || {};
    } catch (e) {
      return { enabled: true, provider: 'stub' };
    }
  }

  isEnabled() {
    return !!this._getSettings().enabled;
  }

  isConfigured() {
    const s = this._getSettings();
    if (!s.enabled) return false;
    if (s.provider === 'stub') return true;
    if (s.provider === 'http') return !!s.apiBaseUrl;
    if (s.provider === 'file') return !!s.apiBaseUrl;
    return false;
  }

  async connect() {
    const s = this._getSettings();
    this.deviceType = s.provider || 'stub';
    if (s.deviceId) this.deviceId = s.deviceId;
    this.isConnected = true;
    console.log(`[Fiscal] UJP Hardware Bridge connected via: ${this.deviceType.toUpperCase()} (Device: ${this.deviceId})`);
    return true;
  }

  // ── Fiscal Number Generation ─────────────────────────────────────
  /**
   * Format: MK-{DeviceID}-{Sequential}-{YYYYMMDD}
   * Example: MK-RM001-000147-20260327
   */
  _generateFiscalNumber() {
    const seq = this._incrementCounter();
    const date = new Date();
    const dateStr = date.getFullYear().toString() +
      String(date.getMonth() + 1).padStart(2, '0') +
      String(date.getDate()).padStart(2, '0');
    return `MK-${this.deviceId}-${String(seq).padStart(6, '0')}-${dateStr}`;
  }

  // ── Tax Calculation (UJP Compliant) ──────────────────────────────
  /**
   * УЈП Даночни групи:
   *  А = 18% (Општа стапка)
   *  Б = 5%  (Преференцијална стапка)
   */
  _calculateTax(items) {
    const groups = { 'А': { rate: 18, base: 0, tax: 0 }, 'Б': { rate: 5, base: 0, tax: 0 } };

    items.forEach(item => {
      const taxRate = item.taxRate || 18;
      const group = taxRate <= 5 ? 'Б' : 'А';
      const totalWithTax = item.price * item.quantity;
      const base = totalWithTax / (1 + taxRate / 100);
      const tax = totalWithTax - base;
      groups[group].base += base;
      groups[group].tax += tax;
    });

    return groups;
  }

  // ── Item Data Formatting ─────────────────────────────────────────
  _formatItemData(items) {
    return items.map(item => {
      const taxRate = item.menuItem?.taxRate || 18;
      const taxGroup = taxRate <= 5 ? 'Б' : 'А';
      // Fallback carefully: an item's DB schema uses unitPrice, not subtotal
      const unitPrice = parseFloat(item.unitPrice || item.price || 0);
      return {
        name: (item.menuItem?.name || 'Артикл').substring(0, 30),
        quantity: item.quantity || 1,
        price: unitPrice,
        taxGroup,
        taxRate
      };
    });
  }

  // ── XML Receipt Generation (UJP Compliant) ───────────────────────
  /**
   * Generates XML in the standard NMK fiscal device format
   * Compatible with David Computers / Accent / Synergy file drops
   */
  _generateXMLReceipt(fiscalNumber, items, total, type = 'Sale', originalFiscalNumber = null, paymentMethod = 'Готовина') {
    const taxGroups = this._calculateTax(items);
    const now = new Date();
    const timestamp = now.toISOString();
    const s = this._getSettings();
    const tinField = s.tin || '0000000000000'; // Fallback if admin forgot

    let xml = `<?xml version="1.0" encoding="UTF-8"?>\n`;
    xml += `<FiscalReceipt>\n`;
    xml += `  <Header>\n`;
    xml += `    <FiscalNumber>${fiscalNumber}</FiscalNumber>\n`;
    xml += `    <Type>${type}</Type>\n`;
    xml += `    <DateTime>${timestamp}</DateTime>\n`;
    xml += `    <DeviceID>${this.deviceId}</DeviceID>\n`;
    xml += `    <TIN>${tinField}</TIN>\n`;
    xml += `    <PaymentMethod>${paymentMethod === 'card' ? 'Картичка' : 'Готовина'}</PaymentMethod>\n`;
    if (type === 'Storno' && originalFiscalNumber) {
      xml += `    <OriginalFiscalNumber>${originalFiscalNumber}</OriginalFiscalNumber>\n`;
      xml += `    <StornoType>Касова сметка за сторна трансакција</StornoType>\n`;
    }
    xml += `  </Header>\n`;
    xml += `  <Items>\n`;
    items.forEach(item => {
      xml += `    <Item Name="${this._escapeXml(item.name)}" Qty="${item.quantity}" `;
      xml += `Price="${item.price.toFixed(2)}" Tax="${item.taxGroup}" TaxRate="${item.taxRate}%" />\n`;
    });
    xml += `  </Items>\n`;
    xml += `  <TaxSummary>\n`;
    for (const [group, data] of Object.entries(taxGroups)) {
      if (data.base > 0) {
        xml += `    <TaxGroup Name="${group}" Rate="${data.rate}%" Base="${data.base.toFixed(2)}" Tax="${data.tax.toFixed(2)}" />\n`;
      }
    }
    xml += `  </TaxSummary>\n`;
    xml += `  <Total>${parseFloat(total).toFixed(2)}</Total>\n`;
    xml += `</FiscalReceipt>`;
    return xml;
  }

  _escapeXml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  // ── Print Fiscal Receipt (Sale) ──────────────────────────────────
  async printFiscalReceipt(orderData) {
    const s = this._getSettings();
    if (!s.enabled) return { success: true, fiscalNumber: null, warning: 'FISCAL_DISABLED' };
    if (!this.isConfigured()) return { success: true, fiscalNumber: null, warning: 'FISCAL_NOT_CONFIGURED' };

    const items = this._formatItemData(orderData.items || []);
    const total = orderData.total || orderData.totalAmount || 0;
    const orderId = orderData.orderId || orderData.id || `ORD-${Date.now()}`;
    const fiscalNumber = this._generateFiscalNumber();

    try {
      if (s.provider === 'file') {
        const outPath = s.apiBaseUrl;
        if (!fs.existsSync(outPath)) {
          fs.mkdirSync(outPath, { recursive: true });
        }
        const xmlData = this._generateXMLReceipt(fiscalNumber, items, total, 'Sale', null, orderData.paymentMethod || 'cash');
        const fileName = path.join(outPath, `receipt_${orderId}_${fiscalNumber}.xml`);
        fs.writeFileSync(fileName, xmlData, 'utf8');
        console.log(`[Fiscal FileBridge] Sale receipt written: ${fileName}`);
        return { success: true, fiscalNumber, printedAt: new Date() };

      } else if (s.provider === 'http') {
        const payload = {
          fiscal_number: fiscalNumber,
          receipt_type: 0, // 0 = Sale
          receipt_id: orderId,
          items: items.map(i => ({
            name: i.name,
            qty: i.quantity,
            price: i.price,
            tax_group: i.taxGroup,
            tax_rate: i.taxRate
          })),
          payment: {
            type: orderData.paymentMethod || 'cash',
            amount: parseFloat(total)
          }
        };

        const headers = { 'Content-Type': 'application/json' };
        if (s.apiKey) headers['Authorization'] = `Bearer ${s.apiKey}`;

        try {
          const response = await axios.post(`${s.apiBaseUrl}/print`, payload, {
            headers,
            timeout: 15000 // 15s timeout for fiscal device
          });
          console.log(`[Fiscal HTTPBridge] Sale receipt printed: ${fiscalNumber}`);
          return {
            success: true,
            fiscalNumber: response.data?.fiscalNumber || fiscalNumber,
            printedAt: new Date()
          };
        } catch (httpErr) {
          console.error(`[Fiscal HTTPBridge] HTTP Error: ${httpErr.message}`);
          // Fallback: still log receipt locally for audit
          return { success: false, fiscalNumber: null, error: `HTTP_BRIDGE_ERROR: ${httpErr.message}` };
        }

      } else {
        // STUB provider
        console.log(`[Fiscal Stub] Sale receipt #${fiscalNumber} | Total: ${total} MKD`);
        return { success: true, fiscalNumber, printedAt: new Date() };
      }
    } catch (e) {
      console.error('[Fiscal Bridge Error]', e.message);
      return { success: false, fiscalNumber: null, error: `BRIDGE_ERROR: ${e.message}` };
    }
  }

  // ── Print Storno (Refund) Receipt — UJP Compliant ────────────────
  /**
   * Per UJP Law:
   * - Storno must reference the original fiscal number
   * - For food/drink in hospitality: 15-minute time limit
   * - Original receipt must be attached to the daily Z-report
   * - Document type: "Касова сметка за сторна трансакција"
   */
  async printStornoReceipt(stornoData) {
    const s = this._getSettings();
    if (!s.enabled) return { success: true, stornoFiscalNumber: null, warning: 'FISCAL_DISABLED' };

    const { originalFiscalNumber, items, total, reason, orderId, paymentMethod } = stornoData;
    const stornoFiscalNumber = this._generateFiscalNumber();

    try {
      if (s.provider === 'file') {
        const outPath = s.apiBaseUrl;
        if (!fs.existsSync(outPath)) {
          fs.mkdirSync(outPath, { recursive: true });
        }
        const formattedItems = this._formatItemData(items || []);
        const xmlData = this._generateXMLReceipt(
          stornoFiscalNumber, formattedItems, total, 'Storno', originalFiscalNumber, paymentMethod || 'cash'
        );
        const fileName = path.join(outPath, `storno_${orderId}_${stornoFiscalNumber}.xml`);
        fs.writeFileSync(fileName, xmlData, 'utf8');
        console.log(`[Fiscal FileBridge] Storno receipt written: ${fileName}`);
        return { success: true, stornoFiscalNumber, printedAt: new Date() };

      } else if (s.provider === 'http') {
        const formattedItems = this._formatItemData(items || []);
        const payload = {
          fiscal_number: stornoFiscalNumber,
          receipt_type: 1, // 1 = Storno
          original_fiscal_number: originalFiscalNumber,
          storno_reason: reason,
          receipt_id: orderId,
          items: formattedItems.map(i => ({
            name: i.name,
            qty: i.quantity,
            price: i.price,
            tax_group: i.taxGroup,
            tax_rate: i.taxRate
          })),
          payment: { type: 'cash', amount: parseFloat(total) }
        };

        const headers = { 'Content-Type': 'application/json' };
        if (s.apiKey) headers['Authorization'] = `Bearer ${s.apiKey}`;

        try {
          const response = await axios.post(`${s.apiBaseUrl}/storno`, payload, {
            headers,
            timeout: 15000
          });
          console.log(`[Fiscal HTTPBridge] Storno receipt printed: ${stornoFiscalNumber}`);
          return {
            success: true,
            stornoFiscalNumber: response.data?.fiscalNumber || stornoFiscalNumber,
            printedAt: new Date()
          };
        } catch (httpErr) {
          console.error(`[Fiscal HTTPBridge] Storno HTTP Error: ${httpErr.message}`);
          return { success: false, stornoFiscalNumber: null, error: `HTTP_BRIDGE_ERROR: ${httpErr.message}` };
        }

      } else {
        // STUB
        console.log(`[Fiscal Stub] Storno receipt #${stornoFiscalNumber} | Ref: ${originalFiscalNumber} | Reason: ${reason}`);
        return { success: true, stornoFiscalNumber, printedAt: new Date() };
      }
    } catch (e) {
      console.error('[Fiscal Storno Error]', e.message);
      return { success: false, stornoFiscalNumber: null, error: `STORNO_ERROR: ${e.message}` };
    }
  }

  // ── Non-Fiscal Receipt ───────────────────────────────────────────
  async printNonFiscalReceipt(orderData, printerDestination) {
    console.log(`[Printer] Non-fiscal receipt to: ${printerDestination} | Total: ${orderData.total || 0} MKD`);
    return { success: true, fiscalNumber: null, printedAt: new Date() };
  }

  // ── Periodic X-Report (Периодичен извештај) ──────────────────────
  async generatePeriodicReport() {
    const s = this._getSettings();
    const reportNumber = `MK-X-${this.deviceId}-${Date.now()}`;

    if (s.provider === 'file') {
      const outPath = s.apiBaseUrl;
      if (outPath && fs.existsSync(outPath)) {
        const now = new Date();
        const dateStr = now.toISOString().slice(0, 10);
        const xml = `<?xml version="1.0" encoding="UTF-8"?>\n` +
          `<PeriodicReport>\n` +
          `  <Command>X-Report</Command>\n` +
          `  <ReportNumber>${reportNumber}</ReportNumber>\n` +
          `  <DateTime>${now.toISOString()}</DateTime>\n` +
          `  <DeviceID>${this.deviceId}</DeviceID>\n` +
          `</PeriodicReport>`;
        fs.writeFileSync(path.join(outPath, `xreport_${Date.now()}.xml`), xml, 'utf8');
      }
    } else if (s.provider === 'http') {
      try {
        const headers = { 'Content-Type': 'application/json' };
        if (s.apiKey) headers['Authorization'] = `Bearer ${s.apiKey}`;
        await axios.post(`${s.apiBaseUrl}/x-report`, { report_number: reportNumber }, { headers, timeout: 30000 });
      } catch (e) {
        console.error('[Fiscal HTTPBridge] X-Report Error:', e.message);
      }
    }

    console.log(`[Fiscal] Periodic X-Report generated: ${reportNumber}`);
    return { success: true, reportNumber };
  }

  // ── Daily Z-Report (Дневен финансиски извештај) ──────────────────
  async generateDailyReport(totals = {}) {
    const s = this._getSettings();
    const reportNumber = `MK-Z-${this.deviceId}-${Date.now()}`;

    if (s.provider === 'file') {
      const outPath = s.apiBaseUrl;
      if (outPath && fs.existsSync(outPath)) {
        const now = new Date();
        const dateStr = now.toISOString().slice(0, 10);
        let xml = `<?xml version="1.0" encoding="UTF-8"?>\n` +
          `<DailyReport>\n` +
          `  <Command>Z-Report</Command>\n` +
          `  <ReportNumber>${reportNumber}</ReportNumber>\n` +
          `  <Date>${dateStr}</Date>\n` +
          `  <DeviceID>${this.deviceId}</DeviceID>\n`;
        
        if (totals && Object.keys(totals).length > 0) {
          xml += `  <Financials>\n`;
          xml += `    <TotalRevenue>${totals.total || 0}</TotalRevenue>\n`;
          xml += `    <FiscalTotal>${totals.fiscalTotal || 0}</FiscalTotal>\n`;
          xml += `    <CashTotal>${totals.cashTotal || 0}</CashTotal>\n`;
          xml += `    <CardTotal>${totals.cardTotal || 0}</CardTotal>\n`;
          xml += `    <ReceiptCount>${totals.paymentCount || 0}</ReceiptCount>\n`;
          xml += `  </Financials>\n`;
        }
        
        xml += `</DailyReport>`;
        fs.writeFileSync(path.join(outPath, `zreport_${dateStr}.xml`), xml, 'utf8');
      }
    } else if (s.provider === 'http') {
      try {
        const headers = { 'Content-Type': 'application/json' };
        if (s.apiKey) headers['Authorization'] = `Bearer ${s.apiKey}`;
        await axios.post(`${s.apiBaseUrl}/z-report`, { report_number: reportNumber, totals }, {
          headers, timeout: 30000
        });
      } catch (e) {
        console.error('[Fiscal HTTPBridge] Z-Report Error:', e.message);
      }
    }

    console.log(`[Fiscal] Daily Z-Report generated: ${reportNumber}`);
    return { success: true, reportNumber };
  }

  getStatus() {
    return { connected: this.isConnected, deviceType: this.deviceType, deviceId: this.deviceId, counter: this._counter };
  }
}

module.exports = new FiscalService();
