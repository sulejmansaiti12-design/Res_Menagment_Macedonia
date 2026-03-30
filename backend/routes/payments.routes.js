const express = require('express');
const router = express.Router();
const { Payment, Order, OrderItem, Shift, TableSession, Table, User, Notification, Printer } = require('../models');
const { authenticate, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../utils/helpers');
const { BadRequestError, NotFoundError } = require('../utils/errors');
const fiscalService = require('../services/fiscal.service');
const qrService = require('../services/qr.service');
const sequelize = require('../config/database');

// ── Auto-Print Router ─────────────────────────────────────────────
// Finds printers matching a given scope and dispatches a print job.
async function _autoRoutePrint(scope, receiptData) {
  try {
    const printers = await Printer.findAll({ where: { isActive: true } });
    const matching = printers.filter(p => {
      const ps = p.config?.printScope;
      return ps === scope || ps === 'both';
    });
    for (const printer of matching) {
      // Stub printers just get a log entry; real printers would get a network request
      if (printer.type === 'network' && printer.ip) {
        console.log(`[AutoPrint] Dispatching ${scope} receipt to ${printer.name} at ${printer.ip}:${printer.port || 9100}`);
        // Network printing would go here (ESC/POS over TCP, etc.)
      } else {
        console.log(`[AutoPrint] ${scope.toUpperCase()} receipt routed to printer "${printer.name}" (${printer.type}) — Total: ${receiptData.total} MKD`);
      }
    }
    if (matching.length === 0) {
      console.log(`[AutoPrint] No printer configured for scope "${scope}". Receipt not auto-printed.`);
    }
  } catch (e) {
    console.error('[AutoPrint] Error routing print job:', e.message);
  }
}

// POST /api/payments - Process payment
router.post('/', authenticate, authorize('waiter', 'waiter_offtrack', 'admin'), asyncHandler(async (req, res) => {
  const { orderId, tableId, paymentMethod = 'cash' } = req.body;

  if (!orderId && !tableId) throw new BadRequestError('Either Order ID or Table ID is required');

  // Get active shift
  const shift = await Shift.findOne({
    where: { waiterId: req.user.id, endTime: null }
  });
  if (!shift) throw new BadRequestError('You must have an active shift to process payments');

  let targetOrders = [];
  let tableSessionId = null;

  if (tableId) {
    const session = await TableSession.findOne({
      where: { tableId, isActive: true },
      include: [{ model: Table, as: 'table' }]
    });
    if (!session) throw new BadRequestError('No active session for this table');
    tableSessionId = session.id;

    targetOrders = await Order.findAll({
      where: { 
        tableSessionId: session.id,
        status: { [require('sequelize').Op.notIn]: ['paid', 'cancelled'] }
      },
      include: [
        { model: OrderItem, as: 'items' },
        {
          model: TableSession,
          as: 'tableSession',
          include: [{ model: Table, as: 'table' }]
        }
      ]
    });

    if (targetOrders.length === 0) {
      throw new BadRequestError('No unpaid orders for this table');
    }
  } else {
    const order = await Order.findByPk(orderId, {
      include: [
        { model: OrderItem, as: 'items' },
        {
          model: TableSession,
          as: 'tableSession',
          include: [{ model: Table, as: 'table' }]
        }
      ]
    });
    if (!order) throw new NotFoundError('Order not found');
    if (['paid', 'cancelled'].includes(order.status)) {
      throw new BadRequestError('Order is already paid or cancelled');
    }
    targetOrders = [order];
    tableSessionId = order.tableSessionId;
  }

  const t = await sequelize.transaction();
  try {
    const isFiscal = req.user.role !== 'waiter_offtrack';
    let fiscalNumber = null;
    let receiptPrinted = false;

    // Combine items for the receipt
    let allItems = [];
    let grandTotal = 0;
    for (const ord of targetOrders) {
      allItems = allItems.concat(ord.items || []);
      grandTotal += parseFloat(ord.totalAmount);
    }

    if (isFiscal) {
      if (!fiscalService.isConfigured()) {
         console.warn('[Payments] Fiscal is enabled but not configured. Receipt will use stub provider.');
      }
      const receipt = await fiscalService.printFiscalReceipt({
        items: allItems,
        total: grandTotal,
        paymentMethod,
        orderId: tableId ? `TBL-${tableId}` : targetOrders[0].id
      });
      if (!receipt.success) {
        throw new BadRequestError(`Fiscal print failed: ${receipt.error || 'UNKNOWN'}`);
      }
      fiscalNumber = receipt.fiscalNumber;
      receiptPrinted = receipt.success;
    } else {
      const receipt = await fiscalService.printNonFiscalReceipt({
        items: allItems,
        total: grandTotal,
        paymentMethod,
        orderId: tableId ? `TBL-${tableId}` : targetOrders[0].id
      }, 'Counter/Cashier');
      receiptPrinted = receipt.success;
    }

    const createdPayments = [];

    // Process each order
    for (const currentOrder of targetOrders) {
      const payment = await Payment.create({
        orderId: currentOrder.id,
        waiterId: req.user.id,
        shiftId: shift.id,
        amount: currentOrder.totalAmount,
        paymentMethod,
        isFiscal,
        fiscalNumber,
        receiptPrinted,
        paidAt: new Date()
      }, { transaction: t });
      
      createdPayments.push(payment);

      currentOrder.status = 'paid';
      await currentOrder.save({ transaction: t });
    }

    // Update shift totals
    if (isFiscal) {
      shift.totalFiscal = parseFloat(shift.totalFiscal || 0) + grandTotal;
    } else {
      shift.totalOffTrack = parseFloat(shift.totalOffTrack || 0) + grandTotal;
    }
    shift.totalCashCollected = parseFloat(shift.totalCashCollected || 0) + grandTotal;
    await shift.save({ transaction: t });

    // Check if ALL orders for this session are paid
    const unpaidCount = await Order.count({
      where: {
        tableSessionId: tableSessionId,
        status: { [require('sequelize').Op.notIn]: ['paid', 'cancelled'] }
      },
      transaction: t
    });

    let tableCleared = false;
    if (unpaidCount === 0) {
      tableCleared = true;
      const session = targetOrders[0].tableSession;
      session.isActive = false;
      session.endedAt = new Date();
      await session.save({ transaction: t });

      const table = session.table;
      table.qrToken = qrService.generateNewToken();
      table.status = 'free';
      await table.save({ transaction: t });

      await Notification.update(
        { isRead: true },
        { 
          where: require('sequelize').literal(`"data"->>'tableId' = '${table.id}' AND "isRead" = false`),
          transaction: t 
        }
      );
    }

    await t.commit();

    // ── Auto-route the receipt to the correct printer ──
    const printScope = isFiscal ? 'fiscal' : 'off_track';
    _autoRoutePrint(printScope, { total: grandTotal, orderId: targetOrders[0].id, paymentMethod }).catch(() => {});

    res.json({
      success: true,
      data: {
        payments: createdPayments,
        isFiscal,
        fiscalNumber,
        receiptPrinted,
        tableCleared
      }
    });

  } catch (err) {
    await t.rollback();
    throw err;
  }
}));

// GET /api/payments/shift/:shiftId - Get all payments for a shift
router.get('/shift/:shiftId', authenticate, asyncHandler(async (req, res) => {
  const payments = await Payment.findAll({
    where: { shiftId: req.params.shiftId },
    include: [
      {
        model: Order,
        as: 'order',
        include: [
          { model: OrderItem, as: 'items', include: [{ model: require('../models/MenuItem'), as: 'menuItem' }] },
          { model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] }
        ]
      }
    ],
    order: [['paidAt', 'DESC']]
  });

  const totals = {
    total: payments.reduce((sum, p) => sum + parseFloat(p.amount), 0),
    fiscal: payments.filter(p => p.isFiscal && !p.isStorno).reduce((sum, p) => sum + parseFloat(p.amount), 0),
    offTrack: payments.filter(p => !p.isFiscal && !p.isStorno).reduce((sum, p) => sum + parseFloat(p.amount), 0),
    storno: payments.filter(p => p.isStorno).reduce((sum, p) => sum + parseFloat(p.amount), 0),
    count: payments.length
  };

  res.json({ success: true, data: { payments, totals } });
}));

// ═══════════════════════════════════════════════════════════════════
// POST /api/payments/storno — UJP Storno (Refund) Receipt
// Per UJP Law: 15-minute time limit for food/drink in hospitality
// ═══════════════════════════════════════════════════════════════════
router.post('/storno', authenticate, authorize('waiter', 'waiter_offtrack', 'admin', 'owner'), asyncHandler(async (req, res) => {
  const { paymentId, reason } = req.body;

  if (!paymentId) throw new BadRequestError('Payment ID is required');
  if (!reason || reason.trim().length < 3) throw new BadRequestError('Storno reason is required (min 3 characters)');

  const originalPayment = await Payment.findByPk(paymentId, {
    include: [{
      model: Order,
      as: 'order',
      include: [
        { model: OrderItem, as: 'items', include: [{ model: require('../models/MenuItem'), as: 'menuItem' }] },
        { model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] }
      ]
    }]
  });

  if (!originalPayment) throw new NotFoundError('Original payment not found');
  if (originalPayment.isStorno) throw new BadRequestError('Cannot storno a storno receipt');

  // Check if already stornoed
  const existingStorno = await Payment.findOne({
    where: { originalPaymentId: paymentId, isStorno: true }
  });
  if (existingStorno) throw new BadRequestError('This payment has already been stornoed');

  // ── 15-Minute Time Limit (UJP Hospitality Rule) ──────────────
  const paidAt = new Date(originalPayment.paidAt);
  const now = new Date();
  const diffMinutes = (now.getTime() - paidAt.getTime()) / (1000 * 60);

  if (diffMinutes > 15 && req.user.role !== 'owner') {
    throw new BadRequestError(
      `Storno time limit exceeded. Per UJP law, hospitality storno must be within 15 minutes. ` +
      `Elapsed: ${Math.round(diffMinutes)} minutes. Only the owner can override this.`
    );
  }

  const t = await sequelize.transaction();
  try {
    let stornoFiscalNumber = null;

    // Print storno fiscal receipt if original was fiscal
    if (originalPayment.isFiscal && originalPayment.fiscalNumber) {
      const stornoResult = await fiscalService.printStornoReceipt({
        originalFiscalNumber: originalPayment.fiscalNumber,
        items: originalPayment.order?.items || [],
        total: originalPayment.amount,
        reason: reason.trim(),
        orderId: originalPayment.orderId,
        paymentMethod: originalPayment.paymentMethod
      });

      if (!stornoResult.success) {
        throw new BadRequestError(`Fiscal storno failed: ${stornoResult.error || 'UNKNOWN'}`);
      }
      stornoFiscalNumber = stornoResult.stornoFiscalNumber;
    }

    // Create storno payment record (negative amount)
    const stornoPayment = await Payment.create({
      orderId: originalPayment.orderId,
      waiterId: req.user.id,
      shiftId: originalPayment.shiftId,
      amount: -Math.abs(parseFloat(originalPayment.amount)),
      paymentMethod: originalPayment.paymentMethod,
      isFiscal: originalPayment.isFiscal,
      fiscalNumber: originalPayment.fiscalNumber,
      receiptPrinted: !!stornoFiscalNumber,
      paidAt: new Date(),
      isStorno: true,
      stornoReason: reason.trim(),
      originalPaymentId: paymentId,
      stornoFiscalNumber
    }, { transaction: t });

    // Revert the order status back to 'confirmed' so it can be re-paid
    const order = originalPayment.order;
    if (order) {
      order.status = 'confirmed';
      await order.save({ transaction: t });
    }

    // Adjust shift totals
    const shift = await Shift.findByPk(originalPayment.shiftId, { transaction: t });
    if (shift) {
      const refundAmount = Math.abs(parseFloat(originalPayment.amount));
      if (originalPayment.isFiscal) {
        shift.totalFiscal = Math.max(0, parseFloat(shift.totalFiscal || 0) - refundAmount);
      } else {
        shift.totalOffTrack = Math.max(0, parseFloat(shift.totalOffTrack || 0) - refundAmount);
      }
      shift.totalCashCollected = Math.max(0, parseFloat(shift.totalCashCollected || 0) - refundAmount);
      await shift.save({ transaction: t });
    }

    await t.commit();

    res.json({
      success: true,
      data: {
        stornoPayment,
        stornoFiscalNumber,
        originalFiscalNumber: originalPayment.fiscalNumber,
        timeElapsed: `${Math.round(diffMinutes)} minutes`,
        message: 'Storno receipt issued successfully per UJP regulations'
      }
    });

  } catch (err) {
    await t.rollback();
    throw err;
  }
}));

// GET /api/payments/storno-history — Admin audit trail
router.get('/storno-history', authenticate, authorize('admin', 'owner'), asyncHandler(async (req, res) => {
  const stornos = await Payment.findAll({
    where: { isStorno: true },
    include: [
      {
        model: Order,
        as: 'order',
        include: [
          { model: OrderItem, as: 'items', include: [{ model: require('../models/MenuItem'), as: 'menuItem' }] },
          { model: TableSession, as: 'tableSession', include: [{ model: Table, as: 'table' }] }
        ]
      },
      { model: User, as: 'waiter', attributes: ['id', 'name', 'role'] }
    ],
    order: [['paidAt', 'DESC']]
  });

  res.json({ success: true, data: { stornos, count: stornos.length } });
}));

module.exports = router;
