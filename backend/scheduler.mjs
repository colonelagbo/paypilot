import { db } from './db.mjs';
import { executeTransferProposal, getAccountBalances } from './bmoni.mjs';

let isRunning = false;

export async function checkAndExecutePayments() {
  if (isRunning) return { message: 'Scheduler is already running' };
  isRunning = true;

  try {
    const todayStr = new Date().toISOString().split('T')[0];
    
    // Find active user and wallet
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) {
      isRunning = false;
      return { message: 'No registered user found' };
    }

    const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ? LIMIT 1').get(user.id);
    if (!wallet) {
      isRunning = false;
      return { message: 'No wallet found for user' };
    }

    // Fetch live BMONI balance
    const bmoniBalances = await getAccountBalances(user.bmoni_user_id);
    let onchainBalance = 0;
    if (bmoniBalances.balances && Array.isArray(bmoniBalances.balances)) {
      const match = bmoniBalances.balances.find((b) => b.smartWalletId === wallet.bmoni_wallet_id);
      if (match && match.balance) {
        onchainBalance = parseFloat(match.balance) || 0;
      }
    }

    // Effective balance includes test sandbox credits
    const totalWalletBalance = onchainBalance + (wallet.sandbox_funded_balance || 0);

    // Update wallet table with latest balance
    db.prepare('UPDATE wallets SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(totalWalletBalance, wallet.id);

    // Find due payments
    const duePayments = db.prepare(`
      SELECT p.*, r.name as recipient_name, r.wallet_address as recipient_wallet, r.account_number, r.bank_name
      FROM scheduled_payments p
      JOIN recipients r ON p.recipient_id = r.id
      WHERE p.user_id = ?
        AND p.payment_date <= ?
        AND p.status IN ('SCHEDULED', 'READY', 'INSUFFICIENT_FUNDS')
      ORDER BY p.payment_date ASC, p.created_at ASC
    `).all(user.id, todayStr);

    console.log(`\n[SCHEDULER] Running cycle for ${todayStr}. Found ${duePayments.length} due payment(s). Wallet Balance: ₦${totalWalletBalance}`);

    if (duePayments.length === 0) {
      isRunning = false;
      return { message: 'No payments due', processed: 0 };
    }

    const totalDue = duePayments.reduce((sum, p) => sum + p.amount, 0);

    // Smart Pay Balance Check
    if (totalWalletBalance < totalDue) {
      const shortfall = totalDue - totalWalletBalance;
      console.warn(`[SCHEDULER] ⚠️ Smart Pay Warning: Shortfall of ₦${shortfall.toFixed(2)}. Total Due: ₦${totalDue}, Balance: ₦${totalWalletBalance}`);
      
      for (const p of duePayments) {
        db.prepare(`
          UPDATE scheduled_payments
          SET status = 'INSUFFICIENT_FUNDS', shortfall_amount = ?, error_message = ?
          WHERE id = ?
        `).run(shortfall, `Insufficient wallet balance. Shortfall: ₦${shortfall.toFixed(2)}`, p.id);
      }

      isRunning = false;
      return {
        status: 'INSUFFICIENT_FUNDS',
        message: `Payments flagged due to insufficient balance. Shortfall: ₦${shortfall.toFixed(2)}`,
        totalDue,
        totalWalletBalance,
        shortfall,
      };
    }

    // Balance is sufficient! Execute each payment via BMONI
    let currentBalance = totalWalletBalance;
    const results = [];

    for (const payment of duePayments) {
      if (currentBalance < payment.amount) {
        const itemShortfall = payment.amount - currentBalance;
        db.prepare(`
          UPDATE scheduled_payments
          SET status = 'INSUFFICIENT_FUNDS', shortfall_amount = ?
          WHERE id = ?
        `).run(itemShortfall, payment.id);
        continue;
      }

      console.log(`[SCHEDULER] Executing payment ${payment.id} of ₦${payment.amount} to ${payment.recipient_name}...`);

      db.prepare("UPDATE scheduled_payments SET status = 'PROCESSING' WHERE id = ?").run(payment.id);

      const targetAddress = payment.recipient_wallet || '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';

      try {
        const bmoniResult = await executeTransferProposal({
          bmoniUserId: user.bmoni_user_id,
          smartWalletId: wallet.bmoni_wallet_id,
          toAddress: targetAddress,
          amount: payment.amount,
          currency: 'CNGN',
          description: payment.description || `PayPilot payment to ${payment.recipient_name}`,
          signingPrivateKey: user.owner_private_key,
        });

        // Deduct from sandbox_funded_balance
        const newFundedBalance = Math.max(0, (wallet.sandbox_funded_balance || 0) - payment.amount);
        currentBalance -= payment.amount;

        db.prepare('UPDATE wallets SET sandbox_funded_balance = ?, balance = ? WHERE id = ?').run(
          newFundedBalance,
          currentBalance,
          wallet.id
        );

        // Update payment status to SUCCESSFUL
        db.prepare(`
          UPDATE scheduled_payments
          SET status = 'SUCCESSFUL',
              bmoni_proposal_id = ?,
              bmoni_reference = ?,
              executed_at = CURRENT_TIMESTAMP,
              shortfall_amount = 0
          WHERE id = ?
        `).run(bmoniResult.proposalId, bmoniResult.reference, payment.id);

        // Log transaction
        const txId = 'tx_' + Math.random().toString(36).substring(2, 11);
        db.prepare(`
          INSERT INTO transactions (id, scheduled_payment_id, bmoni_reference, amount, currency, status, recipient_name, description)
          VALUES (?, ?, ?, ?, 'CNGN', 'SUCCESSFUL', ?, ?)
        `).run(
          txId,
          payment.id,
          bmoniResult.reference,
          payment.amount,
          payment.recipient_name,
          payment.description || `Payment to ${payment.recipient_name}`
        );

        results.push({ id: payment.id, status: 'SUCCESSFUL', bmoniResult });
        console.log(`[SCHEDULER] ✅ Payment ${payment.id} completed. Reference: ${bmoniResult.reference}`);
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
  console.log(`[SCHEDULER] Started background payment scheduler (interval: ${intervalMs / 1000}s)`);
  setInterval(() => {
    checkAndExecutePayments().catch((e) => console.error('[SCHEDULER] Interval error:', e));
  }, intervalMs);
}
