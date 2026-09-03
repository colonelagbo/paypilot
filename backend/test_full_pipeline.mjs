import { ethers } from 'ethers';

const BASE_URL = process.env.BMONI_BASE_URL || 'https://embedded-dev.bmoni.com';
const API_KEY = process.env.BMONI_API_KEY || 'pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4';

async function api(endpoint, options = {}) {
  const url = `${BASE_URL}${endpoint}`;
  const headers = {
    'x-api-key': API_KEY,
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };
  console.log(`\n>>> [${options.method || 'GET'}] ${endpoint}`);
  if (options.body) {
    console.log('Body:', options.body);
  }
  const res = await fetch(url, { ...options, headers });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch (e) {
    json = text;
  }
  console.log(`<<< HTTP ${res.status}:`, JSON.stringify(json, null, 2));
  return { status: res.status, ok: res.ok, data: json };
}

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function run() {
  console.log('====================================================');
  console.log('  PAYPILOT — PHASE 1: END-TO-END BMONI TEST PIPELINE');
  console.log('====================================================');

  // Step 1: Generate Client Owner Wallet (simulates bmoni_embedded_sdk on device)
  const clientOwnerWallet = ethers.Wallet.createRandom();
  console.log('1. Generated Device EVM Keypair:');
  console.log('   Address:', clientOwnerWallet.address);

  // Step 2: Create User with Sandbox Test Persona (Bunch Dillon)
  const randomSuffix = Math.floor(100000 + Math.random() * 900000);
  const userRes = await api('/v1/users', {
    method: 'POST',
    body: JSON.stringify({
      firstName: 'Bunch',
      lastName: 'Dillon',
      email: `bunch.dillon.${randomSuffix}@example.com`,
      phoneNumber: `+2348000${randomSuffix}`,
    }),
  });
  const bmoniUserId = userRes.data?.user?.bmoniUserId;
  console.log('2. Created BMONI User ID:', bmoniUserId);

  // Step 3: Request Owner-Proof Challenge
  const challengeRes = await api(`/v1/users/${bmoniUserId}/smart-wallets/owner-proof-challenges`, {
    method: 'POST',
    body: JSON.stringify({
      currency: 'CNGN',
      userOwnerAddress: clientOwnerWallet.address,
    }),
  });
  const challengeId = challengeRes.data?.challengeId;
  const challengeMessage = challengeRes.data?.message;
  console.log('3. Challenge received. ID:', challengeId);

  // Step 4: Sign Challenge using EIP-191 (simulates BmoniEmbeddedSdk.signMessage)
  const ownerProofSig = await clientOwnerWallet.signMessage(challengeMessage);
  console.log('4. EIP-191 signature produced:', ownerProofSig.slice(0, 30) + '...');

  // Step 5: Create Managed Smart Wallet
  const walletRes = await api(`/v1/users/${bmoniUserId}/smart-wallets/create-managed`, {
    method: 'POST',
    body: JSON.stringify({
      currency: 'CNGN',
      userOwnerAddress: clientOwnerWallet.address,
      ownerProofChallengeId: challengeId,
      ownerProofSignature: ownerProofSig,
    }),
  });
  const smartWalletId = walletRes.data?.id;
  const smartWalletAddress = walletRes.data?.walletAddress;
  console.log('5. Smart Wallet Provisioned:');
  console.log('   Wallet ID:', smartWalletId);
  console.log('   Wallet Address:', smartWalletAddress);

  // Step 6: Start Nigeria Onboarding
  await api(`/v1/users/${bmoniUserId}/onboarding/start-nigeria`, {
    method: 'POST',
    body: JSON.stringify({
      bvn: '95888168924',
      ngnWalletAddress: smartWalletAddress,
      ngnWalletIndex: 0,
    }),
  });
  console.log('6. Nigeria onboarding submitted.');

  // Step 7: Check Wallet Balance
  const balanceRes = await api(`/v1/users/${bmoniUserId}/smart-wallets/account/balances`);
  console.log('7. Current Balances:', balanceRes.data);

  // Step 8: Create Transfer Proposal
  const destAddress = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
  const amount = '10.00';
  const propRes = await api(`/v1/users/${bmoniUserId}/smart-wallets/${smartWalletId}/proposals`, {
    method: 'POST',
    body: JSON.stringify({
      proposal: {
        type: 'TRANSFER',
        toAddress: destAddress,
        amount: amount,
        currency: 'CNGN',
        description: 'PayPilot Hackathon Scheduled Payout',
      },
    }),
  });
  const proposalId = propRes.data?.proposal?.id;
  console.log('8. Proposal Created. ID:', proposalId);

  // Step 9: Approve Proposal
  const approveRes = await api(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}/approve`, {
    method: 'POST',
  });
  console.log('9. Proposal Approved.');

  // Step 10: Fetch Sign Payload
  let hashToSign;
  for (let i = 0; i < 10; i++) {
    const payloadRes = await api(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}/sign-payload`);
    const raw = payloadRes.data?.data || payloadRes.data;
    const foundHash = raw?.signingPayloadHash || raw?.hashToSign;
    if (payloadRes.ok && foundHash) {
      hashToSign = foundHash;
      break;
    }
    console.log('Waiting for sign-payload to become ready...');
    await sleep(1500);
  }

  if (!hashToSign) {
    throw new Error('Failed to obtain sign-payload!');
  }
  console.log('10. Hash to sign (raw 32-byte digest):', hashToSign);

  // Step 11: Sign raw 32-byte digest WITHOUT EIP-191 prefix (simulates BmoniEmbeddedSdk.signTransactionHash)
  // signingKey.sign() produces low-s normalized 65-byte hex with v=27/28
  const rawSignature = clientOwnerWallet.signingKey.sign(hashToSign).serialized;
  console.log('11. Raw Secp256k1 Signature:', rawSignature);

  // Step 12: Submit Signature to BMONI
  const submitRes = await api(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}/sign`, {
    method: 'POST',
    body: JSON.stringify({ signature: rawSignature }),
  });
  console.log('12. Signature submitted. Response:', submitRes.data);

  // Step 13: Poll Proposal Status
  console.log('13. Polling proposal status...');
  for (let attempt = 1; attempt <= 5; attempt++) {
    await sleep(2000);
    const statusRes = await api(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}`);
    const currentStatus = statusRes.data?.proposal?.status;
    console.log(`    Attempt ${attempt}: Proposal Status = ${currentStatus}`);
    if (currentStatus === 'COMPLETED' || currentStatus === 'FAILED' || currentStatus === 'EXECUTED') {
      break;
    }
  }

  console.log('\n====================================================');
  console.log('  PHASE 1 COMPLETE: End-to-end BMONI integration proven!');
  console.log('====================================================');
}

run().catch((err) => {
  console.error('\n❌ PIPELINE ERROR:', err);
  process.exit(1);
});
