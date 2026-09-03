import { db } from './db.mjs';
import { getAccountBalances, createNigerianOfframp } from './bmoni.mjs';

let isRunning = false;

function walletBalance(balances, walletId) {
  const list = balances?.balances || balances?.data?.balances || [];
  const match = Array.isArray(list) ? list.find((b) => b.smartWalletId === walletId) : null;
  return Number(match?.balance || 0);
}

export async function checkAndExecutePayments() {
  if (isRunning) return { message: 'Scheduler is already running' };
  isRunning = true;
  try {
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return { message: 'No registered user found' };
    const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ? LIMIT 1').get(user.id);
    if (!wallet) return { message: 'No wallet found for user' };

    const balances = await getAccountBalances(user.bmoni_user_id);
    const balance = walletBalance(balances, wallet.bmoni_wallet_id);
    db.prepare('UPDATE wallets SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(balance, wallet.id);

    const now = new Date();
    const today = now.toISOString().slice(0, 10);
    const currentTime = now.toTimeString().slice(0, 5);
    const due = db.prepare(`
      SELECT p.*, r.name recipient_name, r.account_number, r.bank_name, r.bmoni_withdrawal_account_id
      FROM scheduled_payments p JOIN recipients r ON r.id=p.recipient_id
      WHERE p.user_id=? AND p.status='SCHEDULED' AND (p.payment_date < ? OR (p.payment_date=? AND COALESCE(p.payment_time,'00:00')<=?))
      ORDER BY p.payment_date, COALESCE(p.payment_time,'00:00'), p.created_at
    `).all(user.id, today, today, currentTime);

    const results = [];
    for (const payment of due) {
      if (!payment.bmoni_withdrawal_account_id) {
        db.prepare(`UPDATE scheduled_payments SET status='FAILED', error_message=? WHERE id=?`)
          .run('Recipient bank account has not been verified with BMONI.', payment.id);
        results.push({ id: payment.id, status: 'FAILED', error: 'Recipient is not BMONI-verified' });
        continue;
      }
      if (balance < payment.amount) {
        db.prepare(`UPDATE scheduled_payments SET status='INSUFFICIENT_FUNDS', shortfall_amount=?, error_message=? WHERE id=?`)
          .run(payment.amount - balance, `Insufficient BMONI CNGN balance. Shortfall: ₦${(payment.amount-balance).toFixed(2)}`, payment.id);
        results.push({ id: payment.id, status: 'INSUFFICIENT_FUNDS' });
        continue;
      }

      try {
        const res = await createNigerianOfframp({
          bmoniUserId: user.bmoni_user_id,
          smartWalletId: wallet.bmoni_wallet_id,
          withdrawalAccountId: payment.bmoni_withdrawal_account_id,
          amount: payment.amount,
          description: payment.description || `PayPilot payment to ${payment.recipient_name}`,
        });
        const proposal = res.proposal || res.data?.proposal || res.data || res;
        const proposalId = proposal.id || proposal.proposalId;
        const reference = proposal.reference || `BMONI-${payment.id}`;
        db.prepare(`UPDATE scheduled_payments SET status='AWAITING_SIGNATURE', bmoni_proposal_id=?, bmoni_reference=?, error_message=NULL WHERE id=?`)
          .run(proposalId || null, reference, payment.id);
        results.push({ id: payment.id, status: 'AWAITING_SIGNATURE', proposalId, reference });
      } catch (e) {
        db.prepare(`UPDATE scheduled_payments SET status='FAILED', error_message=? WHERE id=?`).run(e.message, payment.id);
        results.push({ id: payment.id, status: 'FAILED', error: e.message });
      }
    }
    return { status: 'SUCCESS', balance, processed: results.length, results };
  } catch (e) {
    console.error('[SCHEDULER]', e);
    return { status: 'ERROR', error: e.message };
  } finally { isRunning = false; }
}

export function startScheduler(intervalMs = 30000) {
  if (process.env.DISABLE_SCHEDULER === 'true') return;
  setInterval(() => checkAndExecutePayments().catch(console.error), intervalMs);
  console.log(`[SCHEDULER] Started (${intervalMs / 1000}s)`);
}
