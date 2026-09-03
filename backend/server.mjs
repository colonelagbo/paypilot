import express from 'express';
import cors from 'cors';
import crypto from 'crypto';
import { db } from './db.mjs';
import {
  createBmoniUser, getOwnerProofChallenge, createManagedSmartWallet, startNigeriaOnboarding,
  getOnboardingStatus, getAccountBalances, getNigerianBanks, getNgnDepositAccount, createNgnOnramp,
  verifyNigerianAccount, registerNigerianWithdrawalAccount, getProposalSignPayload,
  approveProposal, submitProposalSignature, getProposal,
  fetchWallets, fetchWalletDetail, fetchBalance, fetchTransactions,
} from './bmoni.mjs';
import { checkAndExecutePayments, startScheduler } from './scheduler.mjs';

const app = express();
const PORT = process.env.PORT || 4000;
const WEBHOOK_SECRET = process.env.BMONI_WEBHOOK_SECRET || '';
app.use(cors());

// Webhook must receive the untouched body for HMAC verification.
app.post('/api/webhooks/bmoni', express.raw({ type: 'application/json' }), (req, res) => {
  try {
    const signature = req.get('x-bmoni-signature') || req.get('x-webhook-signature') || '';
    const raw = Buffer.isBuffer(req.body) ? req.body : Buffer.from('');
    if (!WEBHOOK_SECRET) return res.status(503).json({ error: 'BMONI_WEBHOOK_SECRET is not configured' });
    const expected = crypto.createHmac('sha256', WEBHOOK_SECRET).update(raw).digest('hex');
    const supplied = signature.replace(/^sha256=/i, '');
    if (!supplied || supplied.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(supplied), Buffer.from(expected))) {
      return res.status(401).json({ error: 'Invalid webhook signature' });
    }

    const event = JSON.parse(raw.toString('utf8'));
    const eventId = event.id || event.eventId;
    if (!eventId) return res.status(400).json({ error: 'Webhook event id is required' });
    const already = db.prepare('SELECT event_id FROM webhook_events WHERE event_id=?').get(eventId);
    if (already) return res.json({ received: true, duplicate: true });
    db.prepare('INSERT INTO webhook_events(event_id,event_type,payload) VALUES(?,?,?)')
      .run(eventId, event.type || event.eventType || 'unknown', JSON.stringify(event));

    const data = event.data || event.payload || event;
    const proposalId = data.proposalId || data.proposal?.id || data.id;
    const reference = data.reference || data.proposal?.reference;
    const status = event.type || event.eventType || '';
    if (proposalId || reference) {
      const terminal = status.includes('completed') ? 'SUCCESSFUL' : status.includes('failed') ? 'FAILED' : status.includes('processing') ? 'PROCESSING' : null;
      if (terminal) {
        db.prepare(`UPDATE scheduled_payments SET status=?, executed_at=CASE WHEN ?='SUCCESSFUL' THEN CURRENT_TIMESTAMP ELSE executed_at END, error_message=CASE WHEN ?='FAILED' THEN ? ELSE error_message END WHERE bmoni_proposal_id=? OR bmoni_reference=?`)
          .run(terminal, terminal, terminal, JSON.stringify(data), proposalId || '', reference || '');
        db.prepare(`UPDATE transactions SET status=? WHERE scheduled_payment_id IN (SELECT id FROM scheduled_payments WHERE bmoni_proposal_id=? OR bmoni_reference=?)`)
          .run(terminal, proposalId || '', reference || '');
      }
    }
    res.json({ received: true });
  } catch (e) {
    console.error('[BMONI WEBHOOK]', e);
    res.status(400).json({ error: 'Invalid webhook' });
  }
});

app.use(express.json({ limit: '1mb' }));

function currentUser() { return db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT 1').get(); }
function id(prefix) { return `${prefix}_${crypto.randomBytes(7).toString('hex')}`; }

app.get('/api/health', (_, res) => res.json({ status: 'ok', timestamp: new Date().toISOString(), bmoniBaseUrl: process.env.BMONI_BASE_URL || 'https://embedded-dev.bmoni.com' }));

// Onboarding: the browser/native wallet signs the owner challenge; the server never receives a private key.
app.post('/api/users/onboard', async (req, res) => {
  try {
    const { name, businessName, email, phoneNumber, ownerAddress, ownerProofSignature, bvn } = req.body;
    if (!name || !businessName || !email || !ownerAddress || !ownerProofSignature || !bvn) return res.status(400).json({ error: 'name, businessName, email, ownerAddress, ownerProofSignature and bvn are required' });

    const existing = db.prepare('SELECT id FROM users WHERE email=?').get(email);
    if (existing) return res.status(409).json({ error: 'A PayPilot account with this email already exists' });

    const buser = await createBmoniUser({ firstName: name.split(' ')[0], lastName: name.split(' ').slice(1).join(' ') || 'Owner', email, phoneNumber });
    const challenge = await getOwnerProofChallenge(buser.bmoniUserId, ownerAddress, 'CNGN');
    // Client must obtain the challenge first. If a signature was supplied, it must match this challenge.
    // To make the flow atomic, allow a two-step continuation endpoint below as well.
    const smartWallet = await createManagedSmartWallet({
      bmoniUserId: buser.bmoniUserId, userOwnerAddress: ownerAddress,
      ownerProofChallengeId: challenge.challengeId, ownerProofSignature, currency: 'CNGN'
    });
    await startNigeriaOnboarding({ bmoniUserId: buser.bmoniUserId, walletAddress: smartWallet.walletAddress, bvn });

    const userId = id('usr');
    db.prepare(`INSERT INTO users(id,name,business_name,email,bmoni_user_id,owner_address) VALUES(?,?,?,?,?,?)`)
      .run(userId, name, businessName, email, buser.bmoniUserId, ownerAddress);
    const walletId = id('wlt');
    db.prepare(`INSERT INTO wallets(id,user_id,bmoni_wallet_id,wallet_address,currency) VALUES(?,?,?,?,?)`)
      .run(walletId, userId, smartWallet.smartWalletId, smartWallet.walletAddress, 'CNGN');

    res.status(201).json({ success: true, user: { id:userId,name,businessName,email,bmoniUserId:buser.bmoniUserId,ownerAddress }, wallet: { id:walletId,bmoniWalletId:smartWallet.smartWalletId,walletAddress:smartWallet.walletAddress,currency:'CNGN',balance:0 } });
  } catch (e) { console.error('[ONBOARD]', e); res.status(e.status || 500).json({ error:e.message, details:e.data }); }
});

// Safer two-step onboarding for browsers: get challenge, sign it locally, then finish.
app.post('/api/users/onboard/challenge', async (req,res) => {
  try {
    const { name,businessName,email,phoneNumber,ownerAddress }=req.body;
    if(!name||!businessName||!email||!ownerAddress) return res.status(400).json({error:'name, businessName, email and ownerAddress are required'});
    const buser=await createBmoniUser({firstName:name.split(' ')[0],lastName:name.split(' ').slice(1).join(' ')||'Owner',email,phoneNumber});
    const challenge=await getOwnerProofChallenge(buser.bmoniUserId,ownerAddress,'CNGN');
    res.json({challenge,...buser,profile:{name,businessName,email,phoneNumber}});
  }catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}
});

app.post('/api/users/onboard/complete', async (req,res)=>{
  try{
    const { bmoniUserId,name,businessName,email,ownerAddress,ownerProofChallengeId,ownerProofSignature,bvn }=req.body;
    if(!bmoniUserId||!ownerAddress||!ownerProofChallengeId||!ownerProofSignature||!bvn) return res.status(400).json({error:'Missing onboarding fields'});
    const smartWallet=await createManagedSmartWallet({bmoniUserId,userOwnerAddress:ownerAddress,ownerProofChallengeId,ownerProofSignature,currency:'CNGN'});
    await startNigeriaOnboarding({bmoniUserId,walletAddress:smartWallet.walletAddress,bvn});
    const userId=id('usr');
    db.prepare(`INSERT INTO users(id,name,business_name,email,bmoni_user_id,owner_address) VALUES(?,?,?,?,?,?)`).run(userId,name,businessName,email,bmoniUserId,ownerAddress);
    const walletId=id('wlt');
    db.prepare(`INSERT INTO wallets(id,user_id,bmoni_wallet_id,wallet_address,currency) VALUES(?,?,?,?,?)`).run(walletId,userId,smartWallet.smartWalletId,smartWallet.walletAddress,'CNGN');
    res.status(201).json({success:true,user:{id:userId,name,businessName,email,bmoniUserId,ownerAddress},wallet:{id:walletId,bmoniWalletId:smartWallet.smartWalletId,walletAddress:smartWallet.walletAddress,currency:'CNGN',balance:0}});
  }catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}
});

app.get('/api/user', async (req,res)=>{ const u=currentUser(); if(!u)return res.status(404).json({error:'No active user'}); const w=db.prepare('SELECT * FROM wallets WHERE user_id=? LIMIT 1').get(u.id); res.json({user:{id:u.id,name:u.name,businessName:u.business_name,email:u.email,bmoniUserId:u.bmoni_user_id,ownerAddress:u.owner_address,createdAt:u.created_at},wallet:w}); });

app.get('/api/wallet', async (req,res)=>{try{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});const w=db.prepare('SELECT * FROM wallets WHERE user_id=? LIMIT 1').get(u.id);if(!w)return res.status(404).json({error:'Wallet not found'});const b=await getAccountBalances(u.bmoni_user_id);const list=b?.balances||b?.data?.balances||[];const match=Array.isArray(list)?list.find(x=>x.smartWalletId===w.bmoni_wallet_id):null;const balance=Number(match?.balance||0);db.prepare('UPDATE wallets SET balance=?,updated_at=CURRENT_TIMESTAMP WHERE id=?').run(balance,w.id);res.json({walletId:w.id,bmoniWalletId:w.bmoni_wallet_id,walletAddress:w.wallet_address,currency:w.currency,balance,provider:'BMONI',bmoniUserId:u.bmoni_user_id});}catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}});

// EmbeddedWalletReadDataSource endpoints
app.get('/api/wallets', async (req, res) => {
  try {
    const u = currentUser();
    if (!u) return res.status(404).json({ error: 'User not found' });
    const wallets = await fetchWallets(u.bmoni_user_id);
    const list = Array.isArray(wallets) ? wallets : (wallets.wallets || wallets.data || []);
    const normalized = list.map(w => ({
      walletId: w.id || w.smartWalletId || w.walletId,
      name: w.name || `${w.currency || 'BMONI'} Wallet`,
      currency: w.currency || 'CNGN',
      balance: Number(w.balance || 0),
      colorSuffix: w.colorSuffix || null,
      walletAddress: w.walletAddress || w.address || null,
      isActive: w.isActive ?? true,
      createdAt: w.createdAt,
      updatedAt: w.updatedAt,
    }));
    res.json({ wallets: normalized });
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message, details: e.data });
  }
});

app.get('/api/wallets/:walletId', async (req, res) => {
  try {
    const u = currentUser();
    if (!u) return res.status(404).json({ error: 'User not found' });
    const w = await fetchWalletDetail(u.bmoni_user_id, req.params.walletId);
    const raw = w.wallet || w.data || w;
    res.json({
      wallet: {
        walletId: raw.id || raw.smartWalletId || req.params.walletId,
        name: raw.name || `${raw.currency || 'BMONI'} Wallet`,
        currency: raw.currency || 'CNGN',
        balance: Number(raw.balance || 0),
        colorSuffix: raw.colorSuffix || null,
        walletAddress: raw.walletAddress || raw.address || null,
        isActive: raw.isActive ?? true,
        createdAt: raw.createdAt,
        updatedAt: raw.updatedAt,
      }
    });
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message, details: e.data });
  }
});

app.get('/api/wallets/:walletId/balance', async (req, res) => {
  try {
    const u = currentUser();
    if (!u) return res.status(404).json({ error: 'User not found' });
    const b = await fetchBalance(u.bmoni_user_id, req.params.walletId);
    const raw = b.data || b;
    res.json({
      walletId: raw.smartWalletId || raw.walletId || req.params.walletId,
      balance: Number(raw.balance || 0),
      currency: raw.currency || 'CNGN',
    });
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message, details: e.data });
  }
});

app.get('/api/wallets/:walletId/transactions', async (req, res) => {
  try {
    const u = currentUser();
    if (!u) return res.status(404).json({ error: 'User not found' });
    const { page, pageSize } = req.query;
    const txData = await fetchTransactions(u.bmoni_user_id, req.params.walletId, { page, pageSize });
    const rawData = txData.data || txData;
    const txList = rawData.transactions || (Array.isArray(rawData) ? rawData : []);
    const normalized = txList.map(t => ({
      id: t.id || t.transactionId || t.bmoni_reference,
      walletId: t.walletId || req.params.walletId,
      amount: Number(t.amount || 0),
      currency: t.currency || 'CNGN',
      direction: t.direction || 'incoming',
      status: t.status || 'completed',
      title: t.title || t.description,
      counterpartyName: t.counterpartyName || t.recipient_name,
      createdAt: t.createdAt || t.created_at,
      reference: t.reference || t.bmoni_reference,
    }));
    res.json({
      transactions: normalized,
      total: rawData.total ?? normalized.length,
      page: Number(page || 1),
      pageSize: Number(pageSize || 20),
    });
  } catch (e) {
    res.status(e.status || 500).json({ error: e.message, details: e.data });
  }
});

app.get('/api/wallet/deposit-account', async (req,res)=>{try{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});const data=await getNgnDepositAccount(u.bmoni_user_id);res.json(data);}catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}});
app.post('/api/wallet/onramp', async (req,res)=>{try{const u=currentUser();const w=db.prepare('SELECT * FROM wallets WHERE user_id=? LIMIT 1').get(u?.id);if(!u||!w)return res.status(404).json({error:'Wallet not found'});res.json(await createNgnOnramp(u.bmoni_user_id,w.bmoni_wallet_id));}catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}});
app.get('/api/wallet/onboarding-status',async(req,res)=>{try{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});res.json(await getOnboardingStatus(u.bmoni_user_id));}catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}});

app.get('/api/banks',async(req,res)=>{try{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});res.json(await getNigerianBanks(u.bmoni_user_id));}catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}});

app.post('/api/recipients/verify',async(req,res)=>{try{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});const {bankCode,accountNumber}=req.body;if(!bankCode||!accountNumber)return res.status(400).json({error:'bankCode and accountNumber are required'});res.json(await verifyNigerianAccount(u.bmoni_user_id,{bankCode,accountNumber}));}catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}});
app.get('/api/recipients',(req,res)=>{const u=currentUser();if(!u)return res.json([]);res.json(db.prepare('SELECT * FROM recipients WHERE user_id=? ORDER BY created_at DESC').all(u.id));});
app.post('/api/recipients',async(req,res)=>{try{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});const {name,accountNumber,bankName,bankCode,category='STAFF',verifiedAccountName}=req.body;if(!name||!accountNumber||!bankName||!bankCode)return res.status(400).json({error:'Missing recipient fields'});const verification=await verifyNigerianAccount(u.bmoni_user_id,{bankCode,accountNumber});const accountName=verification.accountName||verification.account_name||verification.data?.accountName||verifiedAccountName||name;const registered=await registerNigerianWithdrawalAccount(u.bmoni_user_id,{bankCode,accountNumber,accountName});const rid=id('rec');const withdrawalId=registered.id||registered.withdrawalAccountId||registered.data?.id||registered.data?.withdrawalAccountId;db.prepare(`INSERT INTO recipients(id,user_id,name,account_number,bank_name,bank_code,category,bmoni_withdrawal_account_id,verified_account_name,verified_at) VALUES(?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP)`).run(rid,u.id,name,accountNumber,bankName,bankCode,String(category).toUpperCase(),withdrawalId,accountName);res.status(201).json({id:rid,name,accountNumber,bankName,bankCode,category:String(category).toUpperCase(),bmoniWithdrawalAccountId:withdrawalId,verifiedAccountName:accountName,verification});}catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}});

function validatePaymentBody(body){const amount=Number(body.amount);if(!body.recipientId||!Number.isFinite(amount)||amount<=0||!/^\d{4}-\d{2}-\d{2}$/.test(body.paymentDate))throw new Error('recipientId, positive amount and paymentDate (YYYY-MM-DD) are required');return amount;}
app.post('/api/payments/schedule',(req,res)=>{try{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});const amount=validatePaymentBody(req.body);const r=db.prepare('SELECT * FROM recipients WHERE id=? AND user_id=?').get(req.body.recipientId,u.id);if(!r)return res.status(404).json({error:'Recipient not found'});const pid=id('pay');db.prepare(`INSERT INTO scheduled_payments(id,user_id,recipient_id,amount,payment_date,payment_time,description,payment_type,status,bmoni_wallet_id) VALUES(?,?,?,?,?,?,?,'SINGLE','SCHEDULED',(SELECT bmoni_wallet_id FROM wallets WHERE user_id=? LIMIT 1))`).run(pid,u.id,r.id,amount,req.body.paymentDate,req.body.paymentTime||'09:00',req.body.description||'Scheduled payment',u.id);res.status(201).json({id:pid,recipientId:r.id,amount,paymentDate:req.body.paymentDate,paymentTime:req.body.paymentTime||'09:00',status:'SCHEDULED'});}catch(e){res.status(400).json({error:e.message});}});
app.post('/api/payments/schedule-payroll',(req,res)=>{try{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});if(!Array.isArray(req.body.items)||!req.body.items.length)throw new Error('items are required');const batchId=id('payroll');const stmt=db.prepare(`INSERT INTO scheduled_payments(id,user_id,recipient_id,amount,payment_date,payment_time,description,batch_id,payment_type,status,bmoni_wallet_id) VALUES(?,?,?,?,?,?,?,?,'PAYROLL','SCHEDULED',(SELECT bmoni_wallet_id FROM wallets WHERE user_id=? LIMIT 1))`);const out=[];for(const item of req.body.items){const amount=Number(item.amount);const r=db.prepare('SELECT * FROM recipients WHERE id=? AND user_id=?').get(item.recipientId,u.id);if(!r||!Number.isFinite(amount)||amount<=0)throw new Error('Invalid payroll item');const pid=id('pay');stmt.run(pid,u.id,r.id,amount,req.body.paymentDate,req.body.paymentTime||'09:00',req.body.description||`Payroll ${batchId}`,batchId,u.id);out.push({id:pid,recipientId:r.id,amount});}res.status(201).json({batchId,count:out.length,totalAmount:out.reduce((s,x)=>s+x.amount,0),payments:out});}catch(e){res.status(400).json({error:e.message});}});

app.get('/api/payments',(req,res)=>{const u=currentUser();if(!u)return res.json([]);res.json(db.prepare(`SELECT p.*,r.name recipient_name,r.bank_name,r.account_number,r.category recipient_category,r.verified_account_name FROM scheduled_payments p JOIN recipients r ON p.recipient_id=r.id WHERE p.user_id=? ORDER BY p.payment_date ASC,p.created_at DESC`).all(u.id));});
app.delete('/api/payments/:id',(req,res)=>{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});const p=db.prepare('SELECT * FROM scheduled_payments WHERE id=? AND user_id=?').get(req.params.id,u.id);if(!p)return res.status(404).json({error:'Payment not found'});if(!['SCHEDULED','INSUFFICIENT_FUNDS','FAILED'].includes(p.status))return res.status(409).json({error:'Payment can no longer be deleted'});db.prepare('DELETE FROM scheduled_payments WHERE id=?').run(p.id);res.json({success:true});});
app.get('/api/payments/smart-check',(req,res)=>{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});const w=db.prepare('SELECT * FROM wallets WHERE user_id=? LIMIT 1').get(u.id);const pending=db.prepare(`SELECT p.*,r.name recipient_name,r.bank_name,r.account_number FROM scheduled_payments p JOIN recipients r ON p.recipient_id=r.id WHERE p.user_id=? AND p.status IN ('SCHEDULED','INSUFFICIENT_FUNDS','AWAITING_SIGNATURE') ORDER BY p.payment_date,p.payment_time`).all(u.id);const total=pending.reduce((s,p)=>s+p.amount,0);const balance=Number(w?.balance||0);res.json({currentBalance:balance,totalDue:total,shortfall:Math.max(0,total-balance),isReady:balance>=total&&total>0,status:balance<total?'SHORTFALL_WARNING':total?'READY':'NO_PAYMENTS_DUE',pendingPayments:pending});});

// Start a payment: creates BMONI NGN offramp proposal and returns a signing payload.
app.post('/api/payments/:id/prepare-signature',async(req,res)=>{try{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});const p=db.prepare(`SELECT p.*,r.bmoni_withdrawal_account_id FROM scheduled_payments p JOIN recipients r ON p.recipient_id=r.id WHERE p.id=? AND p.user_id=?`).get(req.params.id,u.id);if(!p)return res.status(404).json({error:'Payment not found'});if(!p.bmoni_proposal_id){return res.status(409).json({error:'Payment has not been prepared by the scheduler yet. Run the payment or wait for its scheduled time.'});}await approveProposal(u.bmoni_user_id,p.bmoni_proposal_id);const payload=await getProposalSignPayload(u.bmoni_user_id,p.bmoni_proposal_id);const raw=payload.data||payload;res.json({paymentId:p.id,proposalId:p.bmoni_proposal_id,signingPayloadHash:raw.signingPayloadHash||raw.hashToSign||raw});}catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}});
app.post('/api/payments/:id/signature',async(req,res)=>{try{const u=currentUser();if(!u)return res.status(404).json({error:'User not found'});const p=db.prepare('SELECT * FROM scheduled_payments WHERE id=? AND user_id=?').get(req.params.id,u.id);if(!p||!p.bmoni_proposal_id)return res.status(404).json({error:'Payment/proposal not found'});if(!req.body.signature)return res.status(400).json({error:'signature is required'});const result=await submitProposalSignature(u.bmoni_user_id,p.bmoni_proposal_id,req.body.signature);const proposal=result.proposal||result.data?.proposal||result.data||result;const status=proposal.status||'PROCESSING';db.prepare('UPDATE scheduled_payments SET status=? WHERE id=?').run(['COMPLETED','EXECUTED'].includes(status)?'SUCCESSFUL':'PROCESSING',p.id);if(!db.prepare('SELECT id FROM transactions WHERE scheduled_payment_id=?').get(p.id)){db.prepare(`INSERT INTO transactions(id,scheduled_payment_id,bmoni_reference,amount,currency,status,recipient_name,description) SELECT ?,id,COALESCE(bmoni_reference,?),amount,'CNGN',?,r.name,description FROM scheduled_payments p JOIN recipients r ON p.recipient_id=r.id WHERE p.id=?`).run(id('tx'),p.bmoni_reference||`BMONI-${p.id}`,status==='SUCCESSFUL'?'SUCCESSFUL':'PROCESSING',p.id);}res.json({success:true,status,proposal});}catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}});
app.get('/api/payments/:id/proposal',async(req,res)=>{try{const u=currentUser();const p=db.prepare('SELECT * FROM scheduled_payments WHERE id=? AND user_id=?').get(req.params.id,u?.id);if(!p||!p.bmoni_proposal_id)return res.status(404).json({error:'Proposal not found'});res.json(await getProposal(u.bmoni_user_id,p.bmoni_proposal_id));}catch(e){res.status(e.status||500).json({error:e.message,details:e.data});}});
app.post('/api/payments/run-now',async(req,res)=>{try{res.json(await checkAndExecutePayments());}catch(e){res.status(500).json({error:e.message});}});
app.get('/api/transactions',(req,res)=>res.json(db.prepare('SELECT t.*,p.description,p.payment_type FROM transactions t LEFT JOIN scheduled_payments p ON t.scheduled_payment_id=p.id ORDER BY t.created_at DESC').all()));

// Static Flutter web app
import path from 'path'; import { fileURLToPath } from 'url';
const __dirname=path.dirname(fileURLToPath(import.meta.url));
const webBuildPath=path.join(__dirname,'../paypilot_app/build/web');
app.use(express.static(webBuildPath));
app.use((req,res,next)=>{if(req.path.startsWith('/api'))return next();res.sendFile(path.join(webBuildPath,'index.html'),err=>{if(err)next();});});
startScheduler(30000);
app.listen(PORT, '0.0.0.0', () => console.log(`PayPilot running on http://0.0.0.0:${PORT}`));
if (String(PORT) !== '5050') {
  try {
    app.listen(5050, '0.0.0.0', () => console.log(`PayPilot also running on http://0.0.0.0:5050`));
  } catch (err) {
    console.warn('[SERVER] Could not bind port 5050:', err.message);
  }
}
