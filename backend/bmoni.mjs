import { ethers } from 'ethers';

export const BASE_URL = 'https://embedded-dev.bmoni.com';
export const API_KEY = process.env.BMONI_API_KEY || 'pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4';

export async function bmoniFetch(endpoint, options = {}) {
  const url = `${BASE_URL}${endpoint}`;
  const headers = {
    'x-api-key': API_KEY,
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };

  const response = await fetch(url, { ...options, headers });
  const text = await response.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch (e) {
    json = text;
  }

  if (!response.ok) {
    const errorMsg = typeof json === 'object' && json ? JSON.stringify(json) : text;
    const err = new Error(`BMONI API ${options.method || 'GET'} ${endpoint} failed (${response.status}): ${errorMsg}`);
    err.status = response.status;
    err.data = json;
    throw err;
  }

  return json;
}

/**
 * 1. Create BMONI user using sandbox persona
 */
export async function createBmoniUser({ firstName = 'Bunch', lastName = 'Dillon', email, phoneNumber }) {
  const randomSuffix = Math.floor(100000 + Math.random() * 900000);
  const userEmail = email || `bunch.dillon.${randomSuffix}@example.com`;
  const userPhone = phoneNumber || `+2348000${randomSuffix}`;

  const res = await bmoniFetch('/v1/users', {
    method: 'POST',
    body: JSON.stringify({
      firstName,
      lastName,
      email: userEmail,
      phoneNumber: userPhone,
    }),
  });

  const bmoniUser = res.user || res.data?.user || res;
  return {
    bmoniUserId: bmoniUser.bmoniUserId,
    email: userEmail,
    phoneNumber: userPhone,
    raw: bmoniUser,
  };
}

/**
 * 2. Request owner-proof challenge
 */
export async function getOwnerProofChallenge(bmoniUserId, userOwnerAddress, currency = 'CNGN') {
  const res = await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/owner-proof-challenges`, {
    method: 'POST',
    body: JSON.stringify({
      currency,
      userOwnerAddress,
    }),
  });

  const challengeId = res.challengeId || res.data?.challengeId;
  const message = res.message || res.data?.message;

  return { challengeId, message };
}

/**
 * 3. Create managed smart wallet
 */
export async function createManagedSmartWallet({
  bmoniUserId,
  userOwnerAddress,
  ownerProofChallengeId,
  ownerProofSignature,
  currency = 'CNGN',
}) {
  const res = await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/create-managed`, {
    method: 'POST',
    body: JSON.stringify({
      currency,
      userOwnerAddress,
      ownerProofChallengeId,
      ownerProofSignature,
    }),
  });

  const wallet = res.data || res;
  return {
    smartWalletId: wallet.id || wallet.smartWalletId,
    walletAddress: wallet.walletAddress || wallet.address,
    currency: wallet.currency || 'CNGN',
    isActive: wallet.isActive,
    raw: wallet,
  };
}

/**
 * 4. Start Nigeria Onboarding (NGN Virtual Account)
 */
export async function startNigeriaOnboarding({ bmoniUserId, walletAddress, bvn = '95888168924' }) {
  const res = await bmoniFetch(`/v1/users/${bmoniUserId}/onboarding/start-nigeria`, {
    method: 'POST',
    body: JSON.stringify({
      bvn,
      ngnWalletAddress: walletAddress,
      ngnWalletIndex: 0,
    }),
  });
  return res;
}

/**
 * 5. Fetch Account Wallets & Live Balances
 */
export async function getAccountBalances(bmoniUserId) {
  try {
    const res = await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/account/balances`);
    return res;
  } catch (err) {
    console.error('Error fetching BMONI balances:', err.message);
    return { balances: [] };
  }
}

export async function getAccountWallets(bmoniUserId) {
  try {
    const res = await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/account/wallets`);
    return res;
  } catch (err) {
    console.error('Error fetching BMONI wallets:', err.message);
    return [];
  }
}

/**
 * 6. Fetch Supported Nigerian Banks
 */
export async function getNigerianBanks(bmoniUserId) {
  try {
    const res = await bmoniFetch(`/v1/users/${bmoniUserId}/bank-accounts/nigerian-banks`);
    return Array.isArray(res) ? res : [];
  } catch (err) {
    console.error('Error fetching Nigerian banks:', err.message);
    return [];
  }
}

/**
 * 7. End-to-End Transfer Execution via BMONI Smart Wallet Proposal
 */
export async function executeTransferProposal({
  bmoniUserId,
  smartWalletId,
  toAddress,
  amount,
  currency = 'CNGN',
  description = 'PayPilot scheduled transfer',
  signingPrivateKey,
}) {
  console.log(`[BMONI] Creating transfer proposal for ${amount} ${currency} to ${toAddress}...`);

  // A. Create proposal
  const propRes = await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/${smartWalletId}/proposals`, {
    method: 'POST',
    body: JSON.stringify({
      proposal: {
        type: 'TRANSFER',
        toAddress,
        amount: String(amount),
        currency,
        description,
      },
    }),
  });

  const proposal = propRes.proposal || propRes.data?.proposal || propRes;
  const proposalId = proposal.id;
  console.log(`[BMONI] Proposal created. ID: ${proposalId}, Status: ${proposal.status}`);

  // B. Approve proposal
  await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}/approve`, {
    method: 'POST',
  });
  console.log(`[BMONI] Proposal approved.`);

  // C. Poll sign-payload
  let hashToSign;
  for (let i = 0; i < 10; i++) {
    await new Promise((r) => setTimeout(r, 1000));
    try {
      const payloadRes = await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}/sign-payload`);
      const raw = payloadRes.data || payloadRes;
      const found = raw.signingPayloadHash || raw.hashToSign;
      if (found) {
        hashToSign = found;
        break;
      }
    } catch (e) {
      // 409 when payload is still preparing
    }
  }

  if (!hashToSign) {
    throw new Error(`Failed to obtain sign-payload for proposal ${proposalId}`);
  }

  console.log(`[BMONI] Obtained hashToSign: ${hashToSign}`);

  // D. Sign raw 32-byte digest WITHOUT EIP-191 prefix
  const wallet = new ethers.Wallet(signingPrivateKey);
  const signature = wallet.signingKey.sign(hashToSign).serialized;
  console.log(`[BMONI] Generated raw secp256k1 signature: ${signature.slice(0, 30)}...`);

  // E. Submit signature
  const submitRes = await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}/sign`, {
    method: 'POST',
    body: JSON.stringify({ signature }),
  });
  console.log(`[BMONI] Signature submitted. BMONI co-signed.`);

  // F. Poll final status
  let finalProposal = submitRes.proposal || submitRes.data?.proposal || submitRes;
  for (let attempt = 1; attempt <= 4; attempt++) {
    await new Promise((r) => setTimeout(r, 1500));
    try {
      const check = await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}`);
      finalProposal = check.proposal || check.data?.proposal || check;
      if (['COMPLETED', 'FAILED', 'EXECUTED'].includes(finalProposal.status)) {
        break;
      }
    } catch (e) {}
  }

  return {
    proposalId,
    status: finalProposal.status,
    workflowId: finalProposal.workflowId,
    blockchainTxHash: finalProposal.blockchainTxHash,
    reference: `BMONI-${proposalId.slice(0, 8).toUpperCase()}`,
    proposal: finalProposal,
  };
}
