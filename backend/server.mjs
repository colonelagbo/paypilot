import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import { db } from './db.mjs';
import { checkAndExecutePayments, startScheduler } from './scheduler.mjs';

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

// List of supported Nigerian & International banks
const STANDARD_BANKS = [
  { bankName: 'Guaranty Trust Bank (GTBank)', bankCode: '058' },
  { bankName: 'Access Bank', bankCode: '044' },
  { bankName: 'Zenith Bank', bankCode: '057' },
  { bankName: 'First Bank of Nigeria', bankCode: '011' },
  { bankName: 'United Bank for Africa (UBA)', bankCode: '033' },
  { bankName: 'Kuda Microfinance Bank', bankCode: '50211' },
  { bankName: 'Moniepoint MFB', bankCode: '50515' },
  { bankName: 'OPay Digital Services', bankCode: '999992' },
  { bankName: 'Stanbic IBTC Bank', bankCode: '221' },
  { bankName: 'First City Monument Bank (FCMB)', bankCode: '214' },
  { bankName: 'Sterling Bank', bankCode: '232' },
  { bankName: 'Fidelity Bank', bankCode: '070' },
  { bankName: 'Union Bank of Nigeria', bankCode: '032' },
  { bankName: 'Wema Bank (ALAT)', bankCode: '035' },
  { bankName: 'Providus Bank', bankCode: '101' },
  { bankName: 'Ecobank Nigeria', bankCode: '050' },
  { bankName: 'Standard Chartered Bank', bankCode: '068' },
  { bankName: 'Polaris Bank', bankCode: '076' },
  { bankName: 'Keystone Bank', bankCode: '082' },
  { bankName: 'Jaiz Bank', bankCode: '301' },
  { bankName: 'Taj Bank', bankCode: '302' },
  { bankName: 'Other / Custom Bank', bankCode: '000' },
];

// 1. Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    app: 'PayPilot Automated Payment Scheduling',
    timestamp: new Date().toISOString(),
  });
});

// 2. Create User Account
app.post('/api/users/create-account', (req, res) => {
  try {
    const { name, businessName, email, password } = req.body;

    if (!name || !businessName || !email) {
      return res.status(400).json({ error: 'Name, business name, and email are required.' });
    }

    const userId = 'usr_' + Math.random().toString(36).substring(2, 11);

    db.prepare(`
      INSERT INTO users (id, name, business_name, email, password_hash)
      VALUES (?, ?, ?, ?, ?)
    `).run(
      userId,
      name.trim(),
      businessName.trim(),
      email.trim().toLowerCase(),
      password || 'secure_pass'
    );

    const user = db.prepare('SELECT id, name, business_name, email, created_at FROM users WHERE id = ?').get(userId);

    console.log(`[API] Created User Account: ${user.name} (${user.business_name}) [${user.email}]`);

    res.status(201).json({
      success: true,
      user,
      message: 'Account created successfully. You can now connect your bank account.',
    });
  } catch (err) {
    if (err.message.includes('UNIQUE constraint failed')) {
      return res.status(409).json({ error: 'An account with this email already exists.' });
    }
    console.error('[API] Create user error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Alias for backwards compatibility with onboarding
app.post('/api/users/onboard', (req, res) => {
  const { name, businessName, email } = req.body;
  if (!name || !email) {
    return res.status(400).json({ error: 'Name and email are required' });
  }

  // Check if user already exists
  let user = db.prepare('SELECT * FROM users WHERE email = ?').get(email.trim().toLowerCase());
  if (!user) {
    const userId = 'usr_' + Math.random().toString(36).substring(2, 11);
    db.prepare(`
      INSERT INTO users (id, name, business_name, email, password_hash)
      VALUES (?, ?, ?, ?, ?)
    `).run(
      userId,
      name.trim(),
      (businessName || 'Business').trim(),
      email.trim().toLowerCase(),
      'secure_pass'
    );
    user = db.prepare('SELECT id, name, business_name, email, created_at FROM users WHERE id = ?').get(userId);
  }

  const primaryBank = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? AND is_primary = 1').get(user.id);

  res.status(201).json({
    success: true,
    user,
    bankAccount: primaryBank || null,
    wallet: primaryBank ? {
      walletAddress: primaryBank.account_number,
      totalBalance: primaryBank.balance,
      balance: primaryBank.balance,
      bankName: primaryBank.bank_name,
    } : null,
  });
});

// 3. Get Current User and Bank Account
app.get('/api/user', (req, res) => {
  const user = db.prepare('SELECT id, name, business_name, email, created_at FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) {
    return res.status(404).json({ error: 'No active user found. Please create an account first.' });
  }

  const bankAccounts = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? ORDER BY is_primary DESC, created_at DESC').all(user.id);
  const primaryBank = bankAccounts.find((b) => b.is_primary === 1) || bankAccounts[0] || null;

  res.json({
    user,
    bankAccount: primaryBank,
    bankAccounts,
    // Backwards-compatible wallet object for any components expecting balance
    wallet: primaryBank ? {
      id: primaryBank.id,
      bankName: primaryBank.bank_name,
      accountNumber: primaryBank.account_number,
      accountName: primaryBank.account_name,
      balance: primaryBank.balance,
      totalBalance: primaryBank.balance,
      currency: 'NGN',
    } : null,
  });
});

// 4. Connect Bank Account (From ANY Bank)
app.post('/api/bank-accounts/connect', (req, res) => {
  try {
    const { bankName, bankCode, accountNumber, accountName, accountType, initialBalance } = req.body;

    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) {
      return res.status(404).json({ error: 'Please create an account first.' });
    }

    if (!bankName || !accountNumber || !accountName) {
      return res.status(400).json({ error: 'Bank name, account number, and account name are required.' });
    }

    const cleanAccNumber = accountNumber.trim().replace(/\s+/g, '');
    const cleanBankName = bankName.trim();
    const cleanAccName = accountName.trim();

    // Check if user already has connected accounts
    const existingAccounts = db.prepare('SELECT COUNT(*) as count FROM bank_accounts WHERE user_id = ?').get(user.id);
    const isFirst = existingAccounts.count === 0;

    const bankAccountId = 'bank_' + Math.random().toString(36).substring(2, 11);
    const balance = parseFloat(initialBalance) || 250000.0; // Default simulated starting balance

    db.prepare(`
      INSERT INTO bank_accounts (id, user_id, bank_name, bank_code, account_number, account_name, account_type, balance, is_primary, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'CONNECTED')
    `).run(
      bankAccountId,
      user.id,
      cleanBankName,
      bankCode || '000',
      cleanAccNumber,
      cleanAccName,
      accountType || 'Current',
      balance,
      isFirst ? 1 : 0
    );

    const connectedAccount = db.prepare('SELECT * FROM bank_accounts WHERE id = ?').get(bankAccountId);

    console.log(`[API] Connected Bank Account: ${cleanBankName} (${cleanAccNumber}) for user ${user.name}`);

    // If there were any scheduled payments waiting for funds, refresh them
    db.prepare(`
      UPDATE scheduled_payments
      SET status = 'SCHEDULED', shortfall_amount = 0, error_message = NULL
      WHERE user_id = ? AND status = 'INSUFFICIENT_FUNDS'
    `).run(user.id);

    res.status(201).json({
      success: true,
      bankAccount: connectedAccount,
      message: `Successfully connected ${cleanBankName} account.`,
    });
  } catch (err) {
    console.error('[API] Connect bank error:', err);
    res.status(500).json({ error: err.message });
  }
});

// List all connected bank accounts
app.get('/api/bank-accounts', (req, res) => {
  const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) return res.json([]);

  const accounts = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? ORDER BY is_primary DESC, created_at DESC').all(user.id);
  res.json(accounts);
});

// Set bank account as primary
app.put('/api/bank-accounts/:id/primary', (req, res) => {
  try {
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const account = db.prepare('SELECT * FROM bank_accounts WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!account) return res.status(404).json({ error: 'Bank account not found' });

    db.prepare('UPDATE bank_accounts SET is_primary = 0 WHERE user_id = ?').run(user.id);
    db.prepare('UPDATE bank_accounts SET is_primary = 1 WHERE id = ?').run(account.id);

    res.json({ success: true, message: `${account.bank_name} is now your primary account.` });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Disconnect / Delete bank account
app.delete('/api/bank-accounts/:id', (req, res) => {
  try {
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const account = db.prepare('SELECT * FROM bank_accounts WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!account) return res.status(404).json({ error: 'Bank account not found' });

    db.prepare('DELETE FROM bank_accounts WHERE id = ?').run(account.id);

    // If it was primary, promote the most recent remaining account to primary
    if (account.is_primary === 1) {
      const remaining = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(user.id);
      if (remaining) {
        db.prepare('UPDATE bank_accounts SET is_primary = 1 WHERE id = ?').run(remaining.id);
      }
    }

    res.json({ success: true, message: 'Bank account disconnected successfully.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Fund / Top up connected bank account
app.post('/api/bank-accounts/:id/fund', (req, res) => {
  try {
    const amount = parseFloat(req.body.amount) || 50000;
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const account = db.prepare('SELECT * FROM bank_accounts WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!account) return res.status(404).json({ error: 'Bank account not found' });

    const newBalance = (account.balance || 0) + amount;
    db.prepare('UPDATE bank_accounts SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(newBalance, account.id);

    console.log(`[API] Deposited ₦${amount} to ${account.bank_name} (${account.account_number}). New Balance: ₦${newBalance}`);

    // Re-check scheduled payments that had INSUFFICIENT_FUNDS
    db.prepare(`
      UPDATE scheduled_payments
      SET status = 'SCHEDULED', shortfall_amount = 0, error_message = NULL
      WHERE user_id = ? AND status = 'INSUFFICIENT_FUNDS'
    `).run(user.id);

    res.json({
      success: true,
      creditedAmount: amount,
      newBalance,
      message: `Successfully added ₦${amount.toLocaleString()} to ${account.bank_name} account.`,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Backwards-compatible /api/wallet endpoints
app.get('/api/wallet', (req, res) => {
  const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) return res.status(404).json({ error: 'User not found' });

  const primaryBank = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? AND is_primary = 1').get(user.id)
    || db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(user.id);

  if (!primaryBank) {
    return res.json({
      walletId: null,
      bankName: 'None Connected',
      accountNumber: 'N/A',
      balance: 0.0,
      totalBalance: 0.0,
      currency: 'NGN',
      isConnected: false,
    });
  }

  res.json({
    walletId: primaryBank.id,
    bankAccountId: primaryBank.id,
    bankName: primaryBank.bank_name,
    accountNumber: primaryBank.account_number,
    accountName: primaryBank.account_name,
    balance: primaryBank.balance,
    totalBalance: primaryBank.balance,
    currency: 'NGN',
    isConnected: true,
    provider: `${primaryBank.bank_name} Connected Account`,
  });
});

app.post('/api/wallet/fund-sandbox', (req, res) => {
  const amount = parseFloat(req.body.amount) || 50000;
  const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) return res.status(404).json({ error: 'User not found' });

  let primaryBank = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? AND is_primary = 1').get(user.id)
    || db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(user.id);

  if (!primaryBank) {
    return res.status(400).json({ error: 'Please connect a bank account first.' });
  }

  const newBalance = (primaryBank.balance || 0) + amount;
  db.prepare('UPDATE bank_accounts SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(newBalance, primaryBank.id);

  db.prepare(`
    UPDATE scheduled_payments
    SET status = 'SCHEDULED', shortfall_amount = 0, error_message = NULL
    WHERE user_id = ? AND status = 'INSUFFICIENT_FUNDS'
  `).run(user.id);

  res.json({
    success: true,
    creditedAmount: amount,
    newTotalBalance: newBalance,
    balance: newBalance,
    message: `Successfully credited ₦${amount.toLocaleString()} to ${primaryBank.bank_name} account.`,
  });
});

// 5. Get List of Banks
app.get('/api/banks', (req, res) => {
  res.json(STANDARD_BANKS);
});

// Bank Account Name Resolution (Simulated instant look-up for any bank)
app.post('/api/banks/resolve', (req, res) => {
  const { bankCode, accountNumber } = req.body;
  const clean = (accountNumber || '').trim().replace(/\s+/g, '');

  if (clean.length < 10) {
    return res.status(400).json({ error: 'Account number must be 10 digits' });
  }

  const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
  const userName = user ? user.name : 'Business Account';

  res.json({
    accountNumber: clean,
    accountName: `${userName} (Verified)`,
    bankCode: bankCode || '058',
  });
});

// 6. Recipients Management
app.get('/api/recipients', (req, res) => {
  const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) return res.json([]);
  const recipients = db.prepare('SELECT * FROM recipients WHERE user_id = ? ORDER BY created_at DESC').all(user.id);
  res.json(recipients);
});

app.post('/api/recipients', (req, res) => {
  try {
    const { name, accountNumber, bankName, bankCode, category } = req.body;
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const normalizedCategory = ['STAFF', 'SUPPLIER', 'OTHER'].includes((category || '').toUpperCase())
      ? (category || '').toUpperCase()
      : 'STAFF';

    const recipientId = 'rec_' + Math.random().toString(36).substring(2, 11);
    db.prepare(`
      INSERT INTO recipients (id, user_id, name, account_number, bank_name, bank_code, category)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      recipientId,
      user.id,
      name,
      accountNumber,
      bankName,
      bankCode || '058',
      normalizedCategory
    );

    res.status(201).json({
      id: recipientId,
      name,
      accountNumber,
      bankName,
      bankCode,
      category: normalizedCategory,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/recipients/:id', (req, res) => {
  try {
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    db.prepare('DELETE FROM recipients WHERE id = ? AND user_id = ?').run(req.params.id, user.id);
    res.json({ success: true, message: 'Recipient deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 7. Schedule Single Payment
app.post('/api/payments/schedule', (req, res) => {
  try {
    const { recipientId, amount, paymentDate, paymentTime, description, bankAccountId } = req.body;
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    let sourceBank = null;
    if (bankAccountId) {
      sourceBank = db.prepare('SELECT * FROM bank_accounts WHERE id = ? AND user_id = ?').get(bankAccountId, user.id);
    }
    if (!sourceBank) {
      sourceBank = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? AND is_primary = 1').get(user.id)
        || db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(user.id);
    }

    const paymentId = 'pay_' + Math.random().toString(36).substring(2, 11);
    db.prepare(`
      INSERT INTO scheduled_payments (id, user_id, recipient_id, bank_account_id, amount, payment_date, payment_time, description, payment_type, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'SINGLE', 'SCHEDULED')
    `).run(
      paymentId,
      user.id,
      recipientId,
      sourceBank ? sourceBank.id : null,
      parseFloat(amount),
      paymentDate,
      paymentTime || '09:00',
      description || 'Scheduled single transfer'
    );

    res.status(201).json({
      id: paymentId,
      recipientId,
      amount: parseFloat(amount),
      paymentDate,
      paymentTime: paymentTime || '09:00',
      description,
      status: 'SCHEDULED',
      sourceBank: sourceBank ? sourceBank.bank_name : null,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 8. Schedule Payroll Batch
app.post('/api/payments/schedule-payroll', (req, res) => {
  try {
    const { items, paymentDate, paymentTime, description, bankAccountId } = req.body;
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    let sourceBank = null;
    if (bankAccountId) {
      sourceBank = db.prepare('SELECT * FROM bank_accounts WHERE id = ? AND user_id = ?').get(bankAccountId, user.id);
    }
    if (!sourceBank) {
      sourceBank = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? AND is_primary = 1').get(user.id)
        || db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(user.id);
    }

    const batchId = 'payroll_' + Math.random().toString(36).substring(2, 9);
    const createdPayments = [];

    const insertStmt = db.prepare(`
      INSERT INTO scheduled_payments (id, user_id, recipient_id, bank_account_id, amount, payment_date, payment_time, description, batch_id, payment_type, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'PAYROLL', 'SCHEDULED')
    `);

    for (const item of items) {
      const paymentId = 'pay_' + Math.random().toString(36).substring(2, 11);
      insertStmt.run(
        paymentId,
        user.id,
        item.recipientId,
        sourceBank ? sourceBank.id : null,
        parseFloat(item.amount),
        paymentDate,
        paymentTime || '09:00',
        description || `Payroll Batch - ${batchId}`,
        batchId
      );
      createdPayments.push({ id: paymentId, recipientId: item.recipientId, amount: item.amount });
    }

    res.status(201).json({
      batchId,
      count: createdPayments.length,
      totalAmount: createdPayments.reduce((sum, p) => sum + parseFloat(p.amount), 0),
      paymentDate,
      paymentTime,
      payments: createdPayments,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 9. List Scheduled Payments
app.get('/api/payments', (req, res) => {
  const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) return res.json([]);

  const payments = db.prepare(`
    SELECT p.*, r.name as recipient_name, r.bank_name, r.account_number, r.category as recipient_category, b.bank_name as source_bank_name
    FROM scheduled_payments p
    JOIN recipients r ON p.recipient_id = r.id
    LEFT JOIN bank_accounts b ON p.bank_account_id = b.id
    WHERE p.user_id = ?
    ORDER BY p.payment_date ASC, p.created_at DESC
  `).all(user.id);

  res.json(payments);
});

// Delete Scheduled Payment
app.delete('/api/payments/:id', (req, res) => {
  try {
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const payment = db.prepare('SELECT * FROM scheduled_payments WHERE id = ? AND user_id = ?').get(req.params.id, user.id);
    if (!payment) return res.status(404).json({ error: 'Payment not found' });

    db.prepare('DELETE FROM scheduled_payments WHERE id = ?').run(req.params.id);
    res.json({ success: true, message: 'Scheduled payment deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 10. Payment Check / Smart Pay Balance Verification
app.get('/api/payments/smart-check', (req, res) => {
  const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) return res.status(404).json({ error: 'User not found' });

  const primaryBank = db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? AND is_primary = 1').get(user.id)
    || db.prepare('SELECT * FROM bank_accounts WHERE user_id = ? ORDER BY created_at DESC LIMIT 1').get(user.id);

  const currentBalance = primaryBank ? primaryBank.balance : 0.0;

  const pendingPayments = db.prepare(`
    SELECT p.*, r.name as recipient_name, r.bank_name, r.account_number
    FROM scheduled_payments p
    JOIN recipients r ON p.recipient_id = r.id
    WHERE p.user_id = ? AND p.status IN ('SCHEDULED', 'READY', 'INSUFFICIENT_FUNDS')
    ORDER BY p.payment_date ASC
  `).all(user.id);

  const totalDue = pendingPayments.reduce((sum, p) => sum + p.amount, 0);
  const shortfall = Math.max(0, totalDue - currentBalance);
  const isReady = currentBalance >= totalDue && totalDue > 0;

  res.json({
    currentBalance,
    totalDue,
    shortfall,
    isReady,
    hasConnectedBank: !!primaryBank,
    bankName: primaryBank ? primaryBank.bank_name : null,
    accountNumber: primaryBank ? primaryBank.account_number : null,
    status: shortfall > 0 ? 'SHORTFALL_WARNING' : isReady ? 'READY' : 'NO_PAYMENTS_DUE',
    warningMessage:
      !primaryBank
        ? 'No bank account connected. Please connect a bank account to enable payment execution.'
        : shortfall > 0
        ? `Scheduled payments may fail — shortfall of ₦${shortfall.toLocaleString(undefined, { minimumFractionDigits: 2 })} on your ${primaryBank.bank_name} account — Top Up Account`
        : `Connected ${primaryBank.bank_name} balance is sufficient for all scheduled transfers.`,
    pendingPayments,
  });
});

// 11. Trigger Scheduler Run Now
app.post('/api/payments/run-now', async (req, res) => {
  try {
    const result = await checkAndExecutePayments();
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 12. Transactions List
app.get('/api/transactions', (req, res) => {
  const txs = db.prepare(`
    SELECT t.*, p.description, p.payment_type
    FROM transactions t
    LEFT JOIN scheduled_payments p ON t.scheduled_payment_id = p.id
    ORDER BY t.created_at DESC
  `).all();
  res.json(txs);
});

// 13. Static hosting for Flutter Web App
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const webBuildPath = path.join(__dirname, '../paypilot_app/build/web');
app.use(express.static(webBuildPath));

app.use((req, res, next) => {
  if (req.path.startsWith('/api')) return next();
  res.sendFile(path.join(webBuildPath, 'index.html'), (err) => {
    if (err) next();
  });
});

// Start background scheduler
startScheduler(30000);

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 PayPilot Full-Stack App running on http://0.0.0.0:${PORT}`);
});
