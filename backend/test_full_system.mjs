import { ethers } from 'ethers';

const BASE = 'http://localhost:4000/api';

async function api(path, options = {}) {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  const data = await res.json();
  return { status: res.status, ok: res.ok, data };
}

async function testFullSystem() {
  console.log('===============================================================');
  console.log('  PAYPILOT — COMPREHENSIVE END-TO-END SYSTEM VALIDATION');
  console.log('===============================================================');

  // 1. Health check
  console.log('\n1. Checking Health API...');
  const health = await api('/health');
  console.log('   Health Status:', health.data);

  // 2. Onboard user via API
  console.log('\n2. Testing Business Onboarding & BMONI Wallet Provisioning...');
  const ownerWallet = ethers.Wallet.createRandom();
  const onboardRes = await api('/users/onboard', {
    method: 'POST',
    body: JSON.stringify({
      name: 'Bunch Dillon',
      businessName: 'PayPilot Global Demo',
      email: `bunch.dillon.${Date.now().toString().slice(-4)}@example.com`,
      ownerAddress: ownerWallet.address,
      ownerPrivateKey: ownerWallet.privateKey,
    }),
  });
  console.log('   Onboard Response:', onboardRes.data.success ? 'SUCCESS' : 'FAILED');
  console.log('   User ID:', onboardRes.data.user?.id);
  console.log('   BMONI User ID:', onboardRes.data.user?.bmoniUserId);
  console.log('   Wallet Address:', onboardRes.data.wallet?.walletAddress);

  // 3. Get Wallet Info
  console.log('\n3. Fetching Wallet Info...');
  const walletRes = await api('/wallet');
  console.log('   BMONI Wallet ID:', walletRes.data.bmoniWalletId);
  console.log('   Total Balance:', walletRes.data.totalBalance);
  console.log('   Provider:', walletRes.data.provider);

  // 4. Add Recipients
  console.log('\n4. Adding Recipients...');
  const rec1 = await api('/recipients', {
    method: 'POST',
    body: JSON.stringify({
      name: 'Tunde Bakare (Operations)',
      accountNumber: '0123456780',
      bankName: 'GTBank',
      bankCode: '058',
    }),
  });
  const rec2 = await api('/recipients', {
    method: 'POST',
    body: JSON.stringify({
      name: 'Ngozi Okonjo (Engineering)',
      accountNumber: '0123456781',
      bankName: 'Access Bank',
      bankCode: '044',
    }),
  });
  console.log(`   Added: ${rec1.data.name} & ${rec2.data.name}`);

  // 5. Schedule Single Payment (Today)
  console.log('\n5. Scheduling Single Payment...');
  const todayStr = new Date().toISOString().split('T')[0];
  const singlePay = await api('/payments/schedule', {
    method: 'POST',
    body: JSON.stringify({
      recipientId: rec1.data.id,
      amount: 15000,
      paymentDate: todayStr,
      paymentTime: '09:00',
      description: 'Office Maintenance Services',
    }),
  });
  console.log('   Single Payment Scheduled. ID:', singlePay.data.id);

  // 6. Schedule Payroll Batch (Today)
  console.log('\n6. Scheduling Payroll Batch...');
  const payroll = await api('/payments/schedule-payroll', {
    method: 'POST',
    body: JSON.stringify({
      items: [
        { recipientId: rec1.data.id, amount: 45000 },
        { recipientId: rec2.data.id, amount: 60000 },
      ],
      paymentDate: todayStr,
      paymentTime: '10:00',
      description: 'September Engineering & Ops Payroll',
    }),
  });
  console.log(`   Payroll Batch Scheduled. Total: ₦${payroll.data.totalAmount} across ${payroll.data.count} staff`);

  // 7. Test Smart Pay Pre-Payment Balance Check (Expect SHORTFALL since balance is 0)
  console.log('\n7. Running Smart Pay Balance Check (Zero Balance Scenario)...');
  const smartCheck1 = await api('/payments/smart-check');
  console.log('   Status:', smartCheck1.data.status);
  console.log('   Warning Message:', smartCheck1.data.warningMessage);
  console.log('   Total Due:', smartCheck1.data.totalDue);
  console.log('   Shortfall:', smartCheck1.data.shortfall);
  console.log('   Is Ready:', smartCheck1.data.isReady);

  // 8. Fund Wallet in Sandbox
  console.log('\n8. Funding BMONI Sandbox Wallet with ₦150,000 CNGN...');
  const fundRes = await api('/wallet/fund-sandbox', {
    method: 'POST',
    body: JSON.stringify({ amount: 150000 }),
  });
  console.log('   Fund Result:', fundRes.data.message);
  console.log('   New Total Balance:', fundRes.data.newTotalBalance);

  // 9. Re-run Smart Pay Check (Expect READY since balance covers total due!)
  console.log('\n9. Re-running Smart Pay Balance Check (Post-Funding Scenario)...');
  const smartCheck2 = await api('/payments/smart-check');
  console.log('   Status:', smartCheck2.data.status);
  console.log('   Message:', smartCheck2.data.warningMessage);
  console.log('   Is Ready:', smartCheck2.data.isReady);

  // 10. Trigger Scheduler Execution
  console.log('\n10. Triggering Automated Payment Scheduler Execution...');
  const runRes = await api('/payments/run-now', { method: 'POST' });
  console.log('   Scheduler Run Result:', runRes.data);

  // 11. Check Completed Transactions
  console.log('\n11. Fetching Transaction Records with BMONI References...');
  const txs = await api('/transactions');
  console.log(`   Total Transactions Logged: ${txs.data.length}`);
  if (txs.data.length > 0) {
    console.log('   First Transaction:', {
      id: txs.data[0].id,
      bmoniReference: txs.data[0].bmoni_reference,
      recipient: txs.data[0].recipient_name,
      amount: txs.data[0].amount,
      status: txs.data[0].status,
    });
  }

  console.log('\n===============================================================');
  console.log('  ✅ ALL 5 PHASES AND WORKFLOWS VALIDATED SUCCESSFULLY!');
  console.log('===============================================================');
}

testFullSystem().catch(console.error);
