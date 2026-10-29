# PayPilot — Automated Business Payment Scheduling & Multi-Bank Payout Platform

**PayPilot** is an automated payment scheduling and payroll batch execution platform for businesses. PayPilot lets business owners create an account, connect accounts from **any bank**, schedule single payments and employee payroll, and automatically verify bank balances before executing payouts.

---

## 🏗 Architecture & Core Flow

PayPilot features a clean, bank-agnostic architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                 PayPilot Flutter App (4 Tabs)               │
│         Home • Bank Accounts • Schedule • Smart Pay         │
└──────────────────────────┬──────────────────────────────────┘
                           │
             ┌─────────────┴─────────────┐
             │                           │
    REST API Client             Backend Service
    (Flutter / Dart)            (Node.js/Express + SQLite)
    • Account Creation          • User & Auth management
    • Bank Connection Flow      • Multi-Bank Account registry
    • Real-time Balance Watch   • Smart Pay balance intelligence
    • Batch Payroll Form        • Scheduler engine (runs every 30s)
             │                  • Settlement transaction logs
             │                           │
             └─────────────┬─────────────┘
                           │
             ┌─────────────▼─────────────┐
             │   Connected Bank Rails    │
             │   • Any Commercial Bank   │
             │   • Microfinance & Digital│
             │   • Custom / Global Banks │
             └───────────────────────────┘
```

---

## 🔑 User Journey & Capabilities

1. **Create an Account**:
   - Simple account creation with business credentials (Owner Name, Business Name, Work Email, and Password).
2. **Connect Any Bank Account**:
   - Directly connect an account from **any bank** (Guaranty Trust Bank, Access Bank, Zenith Bank, First Bank, UBA, Kuda, Moniepoint, OPay, Stanbic IBTC, FCMB, Sterling, Fidelity, Union, Wema, etc., or enter any custom bank name).
   - Enter 10-digit Account Number with instant account name resolution, select account type (Corporate Current, Business Savings, Checking), and configure balance.
   - Support for multiple connected bank accounts, setting primary accounts, and topping up balances.
3. **Smart Pay Balance Intelligence**:
   - Continuously verifies connected bank account balance against upcoming scheduled transfers and payroll batches.
   - Flags shortfall warnings (`⚠️ Shortfall Warning`) if the bank balance is insufficient, preventing failed payouts.
   - Displays `✓ Ready to Pay` when balance covers all commitments.
4. **Single Payment & Batch Payroll Scheduling**:
   - Schedule payments to staff, suppliers, and contractors with specific dates and execution times.
   - Batch payroll scheduling calculates running totals and verifies feasibility against the connected bank account balance.
5. **Automated Background Scheduler**:
   - Background worker monitors due transfers, verifies funds, executes transfers from connected bank accounts, and records transaction references.

---

## 📱 App Screens

1. **Account Creation & Bank Connection (Onboarding)**:
   - Step 1: Create Account with Owner Name, Business Name, Email, and Password.
   - Step 2: Connect Bank Account from any bank with account number, account name, and initial balance.

2. **Home Screen**:
   - Primary connected bank card with live balance, masked account number, and top-up action.
   - Smart Pay real-time readiness indicator.
   - Quick action shortcuts (Schedule Payout, Bank Accounts, Run Scheduler).
   - Upcoming scheduled payments list with status badges.
   - Recent bank settlements list.

3. **Bank Accounts Screen**:
   - Comprehensive multi-bank account management.
   - Cards for all connected bank accounts showing balances, primary indicator, and actions (Set as Primary, Top Up, Disconnect).
   - "Connect Bank Account" action supporting any bank.
   - Full transaction settlement history with transfer references.

4. **Schedule Payment Screen**:
   - Recipient selection with "Quick Add Recipient" modal supporting all banks.
   - Source bank indicator showing which connected bank account will fund the transfer.
   - Amount, Date, Time, and Description.

5. **Schedule Payroll Screen**:
   - Multi-employee payroll batch form with checkbox selection.
   - Individual salary inputs and live running total calculation.
   - Scheduled batch execution with single timestamp.

6. **Payment Check / Smart Pay Screen**:
   - Pre-payment balance verification comparing connected bank balance against pending payouts.
   - Dynamic states for shortfall alerts and ready-to-pay verification.
   - Manual "Execute Transfers Now" action.

---

## 🚀 Running the Project

### 1. Prerequisites
- Node.js v20+
- Flutter 3.24+ (located in `~/flutter` or standard PATH)

### 2. Backend & Full-Stack Web Server
```bash
cd backend
npm install
node server.mjs
```
The server will start at `http://localhost:4000`.

### 3. Running Automated End-to-End System Test
```bash
cd backend
node test_full_system.mjs
```

### 4. Running the Flutter App on Mobile / Desktop / Web
```bash
cd paypilot_app
~/flutter/bin/flutter run -d chrome     # Run in Chrome
~/flutter/bin/flutter run -d linux      # Run native Linux desktop
~/flutter/bin/flutter run -d android    # Run in Android emulator
```
