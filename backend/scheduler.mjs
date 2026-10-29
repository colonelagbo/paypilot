import { db } from './db.mjs';

let isRunning = false;

export async function checkAndExecutePayments() {
  if (isRunning) return { message: 'Scheduler is already running' };
  isRunning = true;

  try {
    const todayStr = new Date().toISOString().split('T')[0];

    // Find active user
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) {
      isRunning = false;
      return { message: 'No registered user found' };
    }

    // Find primary connected bank account
    let bankAccount = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? AND is_primary = 1 LIMIT 1').get(user.id);
    if (!bankAccount) {
      bankAccount = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(user.id);
    }

    if (!bankAccount) {
      isRunning = false;
      return { message: 'No connected bank account found. Please connect an account.' };
    }

    const currentBankBalance = bankAccount.balance || 0.0;

    // Find due payments
    const duePayments = db.prepare(`
      SELECT p.*, r.name as recipient_name, r.bank_name as recipient_bank_name, r.account_number as recipient_account_number
      FROM scheduled_payments p
      JOIN recipients r ON p.recipient_id = r.id
      WHERE p.user_id = ?
        AND p.payment_date <= ?
        AND p.status IN ('SCHEDULED', 'READY', 'INSUFFICIENT_FUNDS')
      ORDER BY p.payment_date ASC, p.created_at ASC
    `).all(user.id, todayStr);

    console.log(`\n[SCHEDULER] Running cycle for ${todayStr}. Due: ${duePayments.length} payment(s). Bank: ${bankAccount.bank_name} (${bankAccount.account_number}) Balance: ₦${currentBankBalance.toFixed(2)}`);

    if (duePayments.length === 0) {
      isRunning = false;
      return { message: 'No payments due', processed: 0 };
    }

    const totalDue = duePayments.reduce((sum, p) => sum + p.amount, 0);

    // Smart Pay Balance Check against connected bank balance
    if (currentBankBalance < totalDue) {
      const shortfall = totalDue - currentBankBalance;
      console.warn(`[SCHEDULER] ⚠️ Smart Pay Warning: Shortfall of ₦${shortfall.toFixed(2)}. Total Due: ₦${totalDue}, Bank Balance: ₦${currentBankBalance}`);

      for (const p of duePayments) {
        db.prepare(`
          UPDATE scheduled_payments
          SET status = 'INSUFFICIENT_FUNDS', shortfall_amount = ?, error_message = ?
          WHERE id = ?
        `).run(shortfall, `Insufficient balance in connected ${bankAccount.bank_name} account. Shortfall: ₦${shortfall.toFixed(2)}`, p.id);
      }

      isRunning = false;
      return {
        status: 'INSUFFICIENT_FUNDS',
        message: `Payments flagged due to insufficient bank balance. Shortfall: ₦${shortfall.toFixed(2)}`,
        totalDue,
        currentBankBalance,
        shortfall,
      };
    }

    // Balance is sufficient! Execute each transfer from connected bank
    let remainingBalance = currentBankBalance;
    const results = [];

    for (const payment of duePayments) {
      if (remainingBalance < payment.amount) {
        const itemShortfall = payment.amount - remainingBalance;
        db.prepare(`
          UPDATE scheduled_payments
          SET status = 'INSUFFICIENT_FUNDS', shortfall_amount = ?, error_message = 'Insufficient bank balance'
          WHERE id = ?
        `).run(itemShortfall, payment.id);
        continue;
      }

      console.log(`[SCHEDULER] Executing transfer ${payment.id} of ₦${payment.amount} to ${payment.recipient_name} via ${payment.recipient_bank_name}...`);

      db.prepare("UPDATE scheduled_payments SET status = 'PROCESSING' WHERE id = ?").run(payment.id);

      try {
        const txnReference = 'PP-TXN-' + Math.random().toString(36).substring(2, 10).toUpperCase();

        // Deduct from bank account balance
        remainingBalance -= payment.amount;

        db.prepare(`
          UPDATE bank_accounts
          SET balance = ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        `).run(remainingBalance, bankAccount.id);

        // Update payment status to SUCCESSFUL
        db.prepare(`
          UPDATE scheduled_payments
          SET status = 'SUCCESSFUL',
              bank_account_id = ?,
              reference = ?,
              executed_at = CURRENT_TIMESTAMP,
              shortfall_amount = 0,
              error_message = NULL
          WHERE id = ?
        `).run(bankAccount.id, txnReference, payment.id);

        // Insert Transaction record
        const txId = 'tx_' + Math.random().toString(36).substring(2, 11);
        db.prepare(`
          INSERT INTO transactions (id, scheduled_payment_id, bank_account_id, reference, amount, currency, status, recipient_name, recipient_bank, recipient_account, source_bank, description)
          VALUES (?, ?, ?, ?, ?, 'NGN', 'SUCCESSFUL', ?, ?, ?, ?, ?)
        `).run(
          txId,
          payment.id,
          bankAccount.id,
          txnReference,
          payment.amount,
          payment.recipient_name,
          payment.recipient_bank_name,
          payment.recipient_account_number,
          bankAccount.bank_name,
          payment.description || `Payment to ${payment.recipient_name}`
        );

        results.push({ id: payment.id, status: 'SUCCESSFUL', reference: txnReference });
        console.log(`[SCHEDULER] ✅ Transfer ${payment.id} completed. Reference: ${txnReference}`);
      } catch (execErr) {
        console.error(`[SCHEDULER] ❌ Error executing payment ${payment.id}:`, execErr.message);

        db.prepare(`
          UPDATE scheduled_payments
          SET status = 'FAILED', error_message = ?
          WHERE id = ?
        `).run(execErr.message, payment.id);

        results.push({ id: payment.id, status: 'FAILED', error: execErr.message });
      }
    }

    isRunning = false;
    return { status: 'SUCCESS', processed: results.length, results };
  } catch (err) {
    console.error('[SCHEDULER] Unexpected error in scheduler cycle:', err);
    isRunning = false;
    return { status: 'ERROR', error: err.message };
  }
}

// Start recurring scheduler timer (every 30 seconds)
export function startScheduler(intervalMs = 30000) {
  console.log(`[SCHEDULER] Started background bank payment scheduler (interval: ${intervalMs / 1000}s)`);
  setInterval(() => {
    checkAndExecutePayments().catch((e) => console.error('[SCHEDULER] Interval error:', e));
  }, intervalMs);
}
