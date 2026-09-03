export const BMONI_PRODUCTION_BASE_URL = 'https://embedded.bmoni.com';
export const BMONI_SANDBOX_BASE_URL = 'https://embedded-dev.bmoni.com';
export const BMONI_SANDBOX_SHARED_API_KEY = 'pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4';

const BASE_URL = process.env.BMONI_BASE_URL || BMONI_SANDBOX_BASE_URL;
const API_KEY = process.env.BMONI_API_KEY || (BASE_URL === BMONI_SANDBOX_BASE_URL ? BMONI_SANDBOX_SHARED_API_KEY : '');

if (!API_KEY) {
  console.warn('[BMONI] BMONI_API_KEY is not set. API calls will fail until configured.');
}

export { BASE_URL, API_KEY };

export async function bmoniFetch(endpoint, options = {}) {
  if (!API_KEY) throw new Error('BMONI_API_KEY is not configured');
  const response = await fetch(`${BASE_URL}${endpoint}`, {
    ...options,
    headers: {
      'x-api-key': API_KEY,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });

  const text = await response.text();
  let data;
  try { data = text ? JSON.parse(text) : {}; } catch { data = text; }
  if (!response.ok) {
    const err = new Error(`BMONI ${options.method || 'GET'} ${endpoint} failed (${response.status}): ${typeof data === 'string' ? data : JSON.stringify(data)}`);
    err.status = response.status;
    err.data = data;
    throw err;
  }
  return data;
}

const unwrap = (res, key) => res?.[key] || res?.data?.[key] || res?.data || res;

export async function createBmoniUser({ firstName, lastName, email, phoneNumber }) {
  const res = await bmoniFetch('/v1/users', {
    method: 'POST',
    body: JSON.stringify({ firstName, lastName, email, phoneNumber }),
  });
  const user = unwrap(res, 'user');
  return { bmoniUserId: user.bmoniUserId || user.id, raw: user };
}

export async function getOwnerProofChallenge(bmoniUserId, userOwnerAddress, currency = 'CNGN') {
  const res = await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/owner-proof-challenges`, {
    method: 'POST',
    body: JSON.stringify({ currency, userOwnerAddress }),
  });
  return { challengeId: res.challengeId || res.data?.challengeId, message: res.message || res.data?.message };
}

export async function createManagedSmartWallet({ bmoniUserId, userOwnerAddress, ownerProofChallengeId, ownerProofSignature, currency = 'CNGN' }) {
  const res = await bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/create-managed`, {
    method: 'POST',
    body: JSON.stringify({ currency, userOwnerAddress, ownerProofChallengeId, ownerProofSignature }),
  });
  const wallet = unwrap(res, 'wallet');
  return {
    smartWalletId: wallet.id || wallet.smartWalletId,
    walletAddress: wallet.walletAddress || wallet.address,
    currency: wallet.currency || currency,
    isActive: wallet.isActive,
    raw: wallet,
  };
}

export async function startNigeriaOnboarding({ bmoniUserId, walletAddress, bvn }) {
  if (!bvn) throw new Error('BVN is required to start Nigeria onboarding');
  return bmoniFetch(`/v1/users/${bmoniUserId}/onboarding/start-nigeria`, {
    method: 'POST',
    body: JSON.stringify({ bvn, ngnWalletAddress: walletAddress, ngnWalletIndex: 0 }),
  });
}

export async function getOnboardingStatus(bmoniUserId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/onboarding/status`);
}

export async function getAccountBalances(bmoniUserId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/account/balances`);
}

export async function getAccountWallets(bmoniUserId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/account/wallets`);
}

export async function getNigerianBanks(bmoniUserId) {
  const res = await bmoniFetch(`/v1/users/${bmoniUserId}/bank-accounts/nigerian-banks`);
  return Array.isArray(res) ? res : (res.banks || res.data?.banks || res.data || []);
}

export async function getNgnDepositAccount(bmoniUserId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/bank-accounts/deposit-accounts/NGN`);
}

export async function createNgnOnramp(bmoniUserId, smartWalletId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/${smartWalletId}/onramp/vba/nigeria`, {
    method: 'POST',
    body: JSON.stringify({}),
  });
}

export async function verifyNigerianAccount(bmoniUserId, { bankCode, accountNumber }) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/bank-accounts/verify-nigerian-account`, {
    method: 'POST',
    body: JSON.stringify({ bankCode, accountNumber }),
  });
}

export async function registerNigerianWithdrawalAccount(bmoniUserId, { bankCode, accountNumber, accountName }) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/bank-accounts/withdrawal-accounts/nigeria`, {
    method: 'POST',
    body: JSON.stringify({ bankCode, accountNumber, accountName }),
  });
}

export async function createNigerianOfframp({ bmoniUserId, smartWalletId, withdrawalAccountId, amount, description }) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/${smartWalletId}/offramp/nigeria`, {
    method: 'POST',
    body: JSON.stringify({
      withdrawalAccountId,
      amount: String(amount),
      currency: 'CNGN',
      description: description || 'PayPilot bank payment',
    }),
  });
}

export async function getProposalSignPayload(bmoniUserId, proposalId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}/sign-payload`);
}

export async function approveProposal(bmoniUserId, proposalId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}/approve`, { method: 'POST' });
}

export async function submitProposalSignature(bmoniUserId, proposalId, signature) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}/sign`, {
    method: 'POST', body: JSON.stringify({ signature }),
  });
}

export async function getProposal(bmoniUserId, proposalId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/proposals/${proposalId}`);
}

// EmbeddedWalletReadDataSource backend proxy functions
export async function fetchWallets(bmoniUserId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/account/wallets`);
}

export async function fetchWalletDetail(bmoniUserId, walletId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/${walletId}`);
}

export async function fetchBalance(bmoniUserId, walletId) {
  return bmoniFetch(`/v1/users/${bmoniUserId}/smart-wallets/${walletId}/balance`);
}

export async function fetchTransactions(bmoniUserId, walletId, { page, pageSize } = {}) {
  const query = new URLSearchParams();
  if (page) query.append('page', String(page));
  if (pageSize) query.append('pageSize', String(pageSize));
  const queryString = query.toString();
  const endpoint = `/v1/users/${bmoniUserId}/smart-wallets/${walletId}/transactions${queryString ? `?${queryString}` : ''}`;
  return bmoniFetch(endpoint);
}
