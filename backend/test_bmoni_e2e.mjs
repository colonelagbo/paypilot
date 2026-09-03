import { ethers } from 'ethers';

const BASE_URL = 'https://embedded-dev.bmoni.com';
const API_KEY = 'pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4';

async function api(endpoint, options = {}) {
  const url = `${BASE_URL}${endpoint}`;
  const headers = {
    'x-api-key': API_KEY,
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };
  console.log(`\n>>> ${options.method || 'GET'} ${url}`);
  if (options.body) {
    console.log('Request Body:', options.body);
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

async function run() {
  console.log('\n--- Generating EVM Owner Wallet ---');
  const ownerWallet = ethers.Wallet.createRandom();
  console.log('Owner address (EIP-55):', ownerWallet.address);

  console.log('\n--- Step 1: Create user ---');
  const randomSuffix = Math.floor(1000 + Math.random() * 9000);
  const userRes = await api('/v1/users', {
    method: 'POST',
    body: JSON.stringify({
      firstName: 'Bunch',
      lastName: 'Dillon',
      email: `bunch.dillon.${randomSuffix}@example.com`,
      phoneNumber: `+234800000${randomSuffix}`,
    })
  });

  const bmoniUserId = userRes.data?.user?.bmoniUserId;
  if (!bmoniUserId) throw new Error('No bmoniUserId returned!');

  console.log('\n--- Step 2: Submit KYC profile ---');
  await api(`/v1/users/${bmoniUserId}/kyc`, {
    method: 'PATCH',
    body: JSON.stringify({
      personalInfo: {
        firstName: 'Bunch',
        lastName: 'Dillon',
        dateOfBirth: '1990-01-15',
        gender: 'male',
      },
      addressDetails: {
        street: '15 Admiralty Way',
        city: 'Lagos',
        state: 'Lagos',
        countryCode: 'NGA',
      }
    })
  });

  console.log('\n--- Step 3: Owner proof challenge ---');
  const challengeRes = await api(`/v1/users/${bmoniUserId}/smart-wallets/owner-proof-challenges`, {
    method: 'POST',
    body: JSON.stringify({
      currency: 'CNGN',
      userOwnerAddress: ownerWallet.address,
    })
  });

  const challengeId = challengeRes.data?.challengeId || challengeRes.data?.data?.challengeId;
  const challengeMsg = challengeRes.data?.message || challengeRes.data?.data?.message;
  console.log('Challenge ID:', challengeId);
  console.log('Challenge Message:', challengeMsg);

  console.log('\n--- Step 4: Sign owner challenge (EIP-191) & Create Smart Wallet ---');
  // EIP-191 personal_sign
  const ownerProofSig = await ownerWallet.signMessage(challengeMsg);
  console.log('Owner proof signature:', ownerProofSig);

  const createWalletRes = await api(`/v1/users/${bmoniUserId}/smart-wallets/create-managed`, {
    method: 'POST',
    body: JSON.stringify({
      currency: 'CNGN',
      userOwnerAddress: ownerWallet.address,
      ownerProofChallengeId: challengeId,
      ownerProofSignature: ownerProofSig,
    })
  });

  const walletData = createWalletRes.data?.data || createWalletRes.data;
  const smartWalletId = walletData?.id || walletData?.smartWalletId;
  const walletAddress = walletData?.address || walletData?.walletAddress;
  console.log('Smart Wallet ID:', smartWalletId);
  console.log('Smart Wallet Address:', walletAddress);

  console.log('\n--- Step 5: Start Nigeria onboarding ---');
  const obRes = await api(`/v1/users/${bmoniUserId}/onboarding/start-nigeria`, {
    method: 'POST',
    body: JSON.stringify({
      bvn: '95888168924',
      ngnWalletAddress: walletAddress || ownerWallet.address,
      ngnWalletIndex: 0,
    })
  });

  console.log('\n--- Step 6: Check onboarding status ---');
  await api(`/v1/users/${bmoniUserId}/onboarding/status`);

  console.log('\n--- Step 7: Check wallets and balances ---');
  await api(`/v1/users/${bmoniUserId}/smart-wallets/account/wallets`);
  await api(`/v1/users/${bmoniUserId}/smart-wallets/account/balances`);

  return { bmoniUserId, smartWalletId, walletAddress, ownerWallet };
}

run().catch(console.error);
