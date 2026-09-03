# PayPilot — Automated Business Payment Scheduling on BMONI

**PayPilot** is an automated payment scheduling and payroll batch execution platform for small businesses, built directly on top of **BMONI's embedded wallet infrastructure** (`bmoni_embedded_sdk`).

PayPilot watches scheduled payments, checks wallet balance before they are due, warns the business owner if funds are insufficient, and executes the transfer through BMONI when due.

---

## 🏗 Architecture: PayPilot & BMONI

BMONI provides the financial infrastructure: wallet creation, identity matching, key signing, funding, and on-chain execution. PayPilot provides the automation, scheduling, and pre-payment balance intelligence layer.

```
┌─────────────────────────────────────────────────────────────┐
│                 PayPilot Flutter App (5 Screens)            │
│  Home • Wallet • Schedule Payment • Schedule Payroll • Smart Pay
└──────────────────────────┬──────────────────────────────────┘
                           │
             ┌─────────────┴─────────────┐
             │                           │
  On-Device Signing              Backend Service
  (bmoni_embedded_sdk)           (Node.js/Express + SQLite)
  • secp256k1 key generation     • Scheduler engine (cron / 30s)
  • Android Keystore / iOS SE    • Smart Pay balance check
  • EIP-191 personal_sign        • Holds BMONI API secret key
  • Raw 32-byte digest sign      • BMONI REST API Proxy
             │                           │
             └─────────────┬─────────────┘
                           │
             ┌─────────────▼─────────────┐
             │   BMONI Embedded Dev API  │
             │   (https://embedded-dev.  │
             │        bmoni.com)         │
             │  • Smart Accounts (Base)  │
             │  • KMS Multi-Sig Relay    │
             │  • NGN Virtual Accounts   │
             └───────────────────────────┘
```

---

## 🔑 BMONI Integration Flow & Key Findings

Every step of the BMONI Sandbox lifecycle runs against live BMONI development endpoints:

1. **User Creation (`POST /v1/users`)**: Created with sandbox persona **Bunch Dillon** (`firstName: "Bunch"`, `lastName: "Dillon"`).
2. **Identity & KYC**: Uses Bunch Dillon's BVN (`95888168924`) and verified persona identity on file.
3. **Owner-Proof Challenge (`POST /v1/users/{id}/smart-wallets/owner-proof-challenges`)**: Generates an EIP-191 challenge message.
4. **Owner-Proof Signing**: Signed via **EIP-191** (`personal_sign`) with prefix `\x19Ethereum Signed Message:\n{length}`.
5. **Smart Wallet Provisioning (`POST /v1/users/{id}/smart-wallets/create-managed`)**: Deploys managed smart wallet on Base Sepolia.
6. **Nigerian Onboarding (`POST /v1/users/{id}/onboarding/start-nigeria`)**: Activates NGN virtual account rails with BVN.
7. **Proposal Creation (`POST /v1/users/{id}/smart-wallets/{id}/proposals`)**: Creates `TRANSFER` proposal in `CNGN`.
8. **Proposal Approval (`POST /v1/users/{id}/smart-wallets/proposals/{id}/approve`)**: Records admin approval.
9. **Signing Payload (`GET /v1/users/{id}/smart-wallets/proposals/{id}/sign-payload`)**: Returns raw 32-byte digest `signingPayloadHash`.
10. **Proposal Signing**: Signed **WITHOUT EIP-191 prefix** using raw secp256k1 signing (low-s normalised).
11. **Signature Submission (`POST /v1/users/{id}/smart-wallets/proposals/{id}/sign`)**: BMONI verifies the recovered signer and executes with KMS co-signer relay.

---

## 📱 The 5 Screens

1. **Home Screen**:
   - Current BMONI wallet balance (₦ / CNGN)
   - BMONI infrastructure status badge
   - Smart Pay real-time health indicator (`✓ Ready` or `⚠️ Shortfall Warning`)
   - Upcoming scheduled payments list with status badges (`SCHEDULED`, `PROCESSING`, `SUCCESSFUL`, `INSUFFICIENT_FUNDS`)
   - Quick triggers: "Smart Pay Check" and "Run Scheduler"

2. **Wallet Screen ("Powered by BMONI")**:
   - Primary Embedded Wallet card with live balance breakdown (On-chain + Sandbox credit)
   - EIP-55 Smart Account address on Base Sepolia with one-tap copy
   - BMONI infrastructure details: Safe multi-sig mode, KMS co-signer, CNGN currency
   - "Fund Wallet (Sandbox)" action dialog
   - Full transaction history with BMONI proposal references (`BMONI-XXXXXX`)

3. **Schedule Payment Screen**:
   - Single payment form: recipient picker with "Quick Add Recipient" modal
   - BMONI-supported Nigerian bank selector (Access, GTBank, FirstBank, UBA, Zenith, Kuda, etc.)
   - Amount, Date (required), Time (optional), and Description
   - Saves to `scheduled_payments` database

4. **Schedule Payroll Screen**:
   - Multi-recipient batch form with employee selection checkboxes
   - Individual salary amount inputs per employee
   - Live Running Total calculator
   - Single date and time for the batch
   - Direct batch scheduling with `batch_id`

5. **Payment Check / Smart Pay Screen**:
   - Pre-payment balance verification screen
   - Dynamic states:
     - **⚠️ Shortfall Warning**: Visual alert card with exact shortfall amount, message *"Payroll may fail — shortfall of ₦X — Fund Wallet"*, and a prominent **Fund Wallet Now** CTA button.
     - **✓ Ready to Pay**: Green verification card showing that current BMONI balance covers all due payments, with a **"Execute Payments Now via BMONI"** CTA.
   - Breakdown of all payments in the execution queue with real-time feasibility status.

---

## 🚀 Running the Project

### 1. Prerequisites
- Node.js v20+
- Flutter 3.24+ (installed in `~/flutter` or standard path)

### 2. Backend & Full-Stack Web Server
The backend runs an Express REST API, SQLite database, and automated payment scheduler (every 30s). It also hosts the compiled Flutter web application:

```bash
cd backend
npm install
node server.mjs
```
The server will start at: `http://localhost:4000`

### 3. Running Automated End-to-End System Test
Run the comprehensive test script that exercises all 5 phases against live BMONI sandbox:

```bash
cd backend
node test_full_system.mjs
```

### 4. Running the Flutter App on Mobile / Desktop
```bash
cd paypilot_app
~/flutter/bin/flutter run -d chrome     # Run in Chrome
~/flutter/bin/flutter run -d linux      # Run native Linux desktop
~/flutter/bin/flutter run -d android    # Run in Android emulator
```
