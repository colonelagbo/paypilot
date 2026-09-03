import express from 'express';
import cors from 'cors';
import { ethers } from 'ethers';
import { db } from './db.mjs';
import {
  createBmoniUser,
  getOwnerProofChallenge,
  createManagedSmartWallet,
  startNigeriaOnboarding,
  getAccountBalances,
  getAccountWallets,
  getNigerianBanks,
} from './bmoni.mjs';
import { checkAndExecutePayments, startScheduler } from './scheduler.mjs';

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

// 1. Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    bmoniBaseUrl: 'https://embedded-dev.bmoni.com',
  });
});

// 2. Onboard User & Provision BMONI Wallet
app.post('/api/users/onboard', async (req, res) => {
  try {
    const { name, businessName, email, ownerPrivateKey, userOwnerAddress } = req.body;

    // Generate or use owner key
    let walletSigner;
    if (ownerPrivateKey) {
      walletSigner = new ethers.Wallet(ownerPrivateKey);
    } else if (!userOwnerAddress) {
      walletSigner = ethers.Wallet.createRandom();
    }
    const finalOwnerAddress = userOwnerAddress || walletSigner?.address;

    console.log(`[API] Onboarding user: ${name} (${businessName}), Owner: ${finalOwnerAddress}`);

    // Step A: Create BMONI User
    const bmoniUser = await createBmoniUser({
      firstName: 'Bunch',
      lastName: 'Dillon',
      email: email || undefined,
    });
    const bmoniUserId = bmoniUser.bmoniUserId;
    console.log(`[API] Created BMONI User ID: ${bmoniUserId}`);

    // Step B: Get Owner Proof Challenge
    const challenge = await getOwnerProofChallenge(bmoniUserId, finalOwnerAddress, 'CNGN');
    console.log(`[API] Got challenge ID: ${challenge.challengeId}`);

    // Step C: If signer is available (e.g. backend custody or local simulated sdk key), sign & complete!
    let smartWallet = null;
    if (walletSigner) {
      const ownerProofSig = await walletSigner.signMessage(challenge.message);
      console.log(`[API] Signed owner proof challenge via EIP-191.`);

      smartWallet = await createManagedSmartWallet({
        bmoniUserId,
        userOwnerAddress: finalOwnerAddress,
        ownerProofChallengeId: challenge.challengeId,
        ownerProofSignature: ownerProofSig,
        currency: 'CNGN',
      });
      console.log(`[API] Smart Wallet created: ${smartWallet.walletAddress}`);

      // Start Nigeria onboarding
      await startNigeriaOnboarding({
        bmoniUserId,
        walletAddress: smartWallet.walletAddress,
        bvn: '95888168924',
      });
      console.log(`[API] Nigeria onboarding activated with BVN.`);
    }

    // Save to local database
    const userId = 'usr_' + Math.random().toString(36).substring(2, 11);
    db.prepare(`
      INSERT INTO users (id, name, business_name, email, bmoni_user_id, owner_address, owner_private_key)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      userId,
      name || 'Bunch Dillon',
      businessName || 'PayPilot Demo Business',
      bmoniUser.email,
      bmoniUserId,
      finalOwnerAddress,
      walletSigner?.privateKey || null
    );

    let walletRecord = null;
    if (smartWallet) {
      const walletId = 'wlt_' + Math.random().toString(36).substring(2, 11);
      db.prepare(`
        INSERT INTO wallets (id, user_id, bmoni_wallet_id, wallet_address, currency, balance, sandbox_funded_balance)
        VALUES (?, ?, ?, ?, 'CNGN', 0.0, 0.0)
      `).run(walletId, userId, smartWallet.smartWalletId, smartWallet.walletAddress);

      walletRecord = {
        id: walletId,
        bmoniWalletId: smartWallet.smartWalletId,
        walletAddress: smartWallet.walletAddress,
        currency: 'CNGN',
        balance: 0.0,
      };
    }

    res.status(201).json({
      success: true,
      user: {
        id: userId,
        name: name || 'Bunch Dillon',
        businessName: businessName || 'PayPilot Demo Business',
        email: bmoniUser.email,
        bmoniUserId,
        ownerAddress: finalOwnerAddress,
      },
      wallet: walletRecord,
      challenge: smartWallet ? null : challenge,
    });
  } catch (err) {
    console.error('[API] Onboard error:', err);
    res.status(500).json({ error: err.message, details: err.data });
  }
});

// 3. Get Current User and Wallet
app.get('/api/user', (req, res) => {
  const user = db.prepare('SELECT id, name, business_name, email, bmoni_user_id, owner_address, created_at FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) {
    return res.status(404).json({ error: 'No active user found. Onboard first.' });
  }
  const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ? LIMIT 1').get(user.id);
  res.json({ user, wallet });
});

// 4. Get Wallet Details and Live Balances
app.get('/api/wallet', async (req, res) => {
  try {
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ? LIMIT 1').get(user.id);
    if (!wallet) return res.status(404).json({ error: 'Wallet not found' });

    // Fetch live balances from BMONI
    const bmoniBalances = await getAccountBalances(user.bmoni_user_id);
    let onchainBalance = 0;
    if (bmoniBalances.balances && Array.isArray(bmoniBalances.balances)) {
      const match = bmoniBalances.balances.find((b) => b.smartWalletId === wallet.bmoni_wallet_id);
      if (match && match.balance) {
        onchainBalance = parseFloat(match.balance) || 0;
      }
    }

    const totalBalance = onchainBalance + (wallet.sandbox_funded_balance || 0);

    // Update DB
    db.prepare('UPDATE wallets SET balance = ? WHERE id = ?').run(totalBalance, wallet.id);

    res.json({
      walletId: wallet.id,
      bmoniWalletId: wallet.bmoni_wallet_id,
      walletAddress: wallet.wallet_address,
      currency: 'CNGN',
      onchainBalance,
      sandboxFundedBalance: wallet.sandbox_funded_balance || 0,
      totalBalance,
      provider: 'Powered by BMONI Embedded Wallet',
      bmoniUserId: user.bmoni_user_id,
    });
  } catch (err) {
    console.error('[API] Wallet fetch error:', err);
    res.status(500).json({ error: err.message });
  }
});

// 5. Fund Sandbox Wallet (Demo Funding)
app.post('/api/wallet/fund-sandbox', (req, res) => {
  try {
    const amount = parseFloat(req.body.amount) || 10000;
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ? LIMIT 1').get(user.id);
    if (!wallet) return res.status(404).json({ error: 'Wallet not found' });

    const newFunded = (wallet.sandbox_funded_balance || 0) + amount;
    const newTotal = (wallet.balance || 0) + amount;

    db.prepare('UPDATE wallets SET sandbox_funded_balance = ?, balance = ? WHERE id = ?').run(
      newFunded,
      newTotal,
      wallet.id
    );

    console.log(`[API] Credited ₦${amount} to wallet ${wallet.id}. New Balance: ₦${newTotal}`);

    // Re-check scheduled payments that had INSUFFICIENT_FUNDS
    db.prepare(`
      UPDATE scheduled_payments
      SET status = 'SCHEDULED', shortfall_amount = 0, error_message = NULL
      WHERE user_id = ? AND status = 'INSUFFICIENT_FUNDS'
    `).run(user.id);

    res.json({
      success: true,
      creditedAmount: amount,
      newTotalBalance: newTotal,
      sandboxFundedBalance: newFunded,
      message: `Successfully credited ₦${amount.toLocaleString()} CNGN to BMONI Sandbox Wallet.`,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 6. Get Nigerian Banks
app.get('/api/banks', async (req, res) => {
  try {
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (user) {
      const banks = await getNigerianBanks(user.bmoni_user_id);
      if (banks.length > 0) return res.json(banks);
    }
    // Fallback standard Nigerian banks list
    res.json([
      { bankName: 'Access Bank', bankCode: '044' },
      { bankName: 'Guaranty Trust Bank (GTBank)', bankCode: '058' },
      { bankName: 'First Bank of Nigeria', bankCode: '011' },
      { bankName: 'United Bank for Africa (UBA)', bankCode: '033' },
      { bankName: 'Zenith Bank', bankCode: '057' },
      { bankName: 'Kuda Bank', bankCode: '50211' },
      { bankName: 'OPay', bankCode: '999992' },
      { bankName: 'Moniepoint MFB', bankCode: '50515' },
    ]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 7. Recipients CRUD
app.get('/api/recipients', (req, res) => {
  const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) return res.json([]);
  const recipients = db.prepare('SELECT * FROM recipients WHERE user_id = ? ORDER BY created_at DESC').all(user.id);
  res.json(recipients);
});

app.post('/api/recipients', (req, res) => {
  try {
    const { name, accountNumber, bankName, bankCode, walletAddress, category } = req.body;
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const normalizedCategory = ['STAFF', 'SUPPLIER', 'OTHER'].includes((category || '').toUpperCase())
      ? (category || '').toUpperCase()
      : 'STAFF';

    const recipientId = 'rec_' + Math.random().toString(36).substring(2, 11);
    db.prepare(`
      INSERT INTO recipients (id, user_id, name, account_number, bank_name, bank_code, wallet_address, category)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      recipientId,
      user.id,
      name,
      accountNumber,
      bankName,
      bankCode || '058',
      walletAddress || '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      normalizedCategory
    );

    res.status(201).json({
      id: recipientId,
      name,
      accountNumber,
      bankName,
      bankCode,
      walletAddress,
      category: normalizedCategory,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 8. Schedule Single Payment
app.post('/api/payments/schedule', (req, res) => {
  try {
    const { recipientId, amount, paymentDate, paymentTime, description } = req.body;
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ? LIMIT 1').get(user.id);

    const paymentId = 'pay_' + Math.random().toString(36).substring(2, 11);
    db.prepare(`
      INSERT INTO scheduled_payments (id, user_id, recipient_id, amount, payment_date, payment_time, description, payment_type, status, bmoni_wallet_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'SINGLE', 'SCHEDULED', ?)
    `).run(
      paymentId,
      user.id,
      recipientId,
      parseFloat(amount),
      paymentDate,
      paymentTime || '09:00',
      description || 'Scheduled single payment',
      wallet ? wallet.bmoni_wallet_id : null
    );

    res.status(201).json({
      id: paymentId,
      recipientId,
      amount: parseFloat(amount),
      paymentDate,
      paymentTime: paymentTime || '09:00',
      description,
      status: 'SCHEDULED',
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 9. Schedule Payroll Batch
app.post('/api/payments/schedule-payroll', (req, res) => {
  try {
    const { items, paymentDate, paymentTime, description } = req.body;
    // items: [{ recipientId, amount }]
    const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
    if (!user) return res.status(404).json({ error: 'User not found' });

    const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ? LIMIT 1').get(user.id);
    const batchId = 'payroll_' + Math.random().toString(36).substring(2, 9);
    const createdPayments = [];

    const insertStmt = db.prepare(`
      INSERT INTO scheduled_payments (id, user_id, recipient_id, amount, payment_date, payment_time, description, batch_id, payment_type, status, bmoni_wallet_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'PAYROLL', 'SCHEDULED', ?)
    `);

    for (const item of items) {
      const paymentId = 'pay_' + Math.random().toString(36).substring(2, 11);
      insertStmt.run(
        paymentId,
        user.id,
        item.recipientId,
        parseFloat(item.amount),
        paymentDate,
        paymentTime || '09:00',
        description || `Payroll Batch - ${batchId}`,
        batchId,
        wallet ? wallet.bmoni_wallet_id : null
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

// 10. List Scheduled Payments
app.get('/api/payments', (req, res) => {
  const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) return res.json([]);

  const payments = db.prepare(`
    SELECT p.*, r.name as recipient_name, r.bank_name, r.account_number, r.wallet_address, r.category as recipient_category
    FROM scheduled_payments p
    JOIN recipients r ON p.recipient_id = r.id
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

// 11. Payment Check / Smart Pay Balance Verification
app.get('/api/payments/smart-check', (req, res) => {
  const user = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get();
  if (!user) return res.status(404).json({ error: 'User not found' });

  const wallet = db.prepare('SELECT * FROM wallets WHERE user_id = ? LIMIT 1').get(user.id);
  const currentBalance = wallet ? wallet.balance : 0.0;

  const todayStr = new Date().toISOString().split('T')[0];

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
    status: shortfall > 0 ? 'SHORTFALL_WARNING' : isReady ? 'READY' : 'NO_PAYMENTS_DUE',
    warningMessage:
      shortfall > 0
        ? `Payroll & Scheduled payments may fail — shortfall of ₦${shortfall.toLocaleString(undefined, { minimumFractionDigits: 2 })} — Fund Wallet`
        : 'Wallet balance is sufficient for all scheduled payments.',
    pendingPayments,
  });
});

// 12. Trigger Scheduler Run Now
app.post('/api/payments/run-now', async (req, res) => {
  try {
    const result = await checkAndExecutePayments();
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 13. Transactions List
app.get('/api/transactions', (req, res) => {
  const txs = db.prepare(`
    SELECT t.*, p.description, p.payment_type
    FROM transactions t
    LEFT JOIN scheduled_payments p ON t.scheduled_payment_id = p.id
    ORDER BY t.created_at DESC
  `).all();
  res.json(txs);
});

// 14. Static hosting for Flutter Web App
import path from 'path';
import { fileURLToPath } from 'url';
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
