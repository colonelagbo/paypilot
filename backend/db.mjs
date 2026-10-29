import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.join(__dirname, 'paypilot.db');

export const db = new Database(dbPath);
db.pragma('journal_mode = WAL');

// Initialize tables
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    business_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS bank_accounts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    bank_name TEXT NOT NULL,
    bank_code TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_name TEXT NOT NULL,
    account_type TEXT NOT NULL DEFAULT 'Current',
    balance REAL NOT NULL DEFAULT 0.0,
    is_primary INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'CONNECTED',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS recipients (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    bank_name TEXT NOT NULL,
    bank_code TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'STAFF',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS scheduled_payments (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    recipient_id TEXT NOT NULL,
    bank_account_id TEXT,
    amount REAL NOT NULL,
    payment_date TEXT NOT NULL,
    payment_time TEXT,
    description TEXT,
    batch_id TEXT,
    payment_type TEXT NOT NULL DEFAULT 'SINGLE',
    status TEXT NOT NULL DEFAULT 'SCHEDULED',
    shortfall_amount REAL DEFAULT 0.0,
    reference TEXT,
    error_message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    executed_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (recipient_id) REFERENCES recipients(id),
    FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(id)
  );

  CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY,
    scheduled_payment_id TEXT,
    bank_account_id TEXT,
    reference TEXT NOT NULL,
    amount REAL NOT NULL,
    currency TEXT NOT NULL DEFAULT 'NGN',
    status TEXT NOT NULL,
    recipient_name TEXT NOT NULL,
    recipient_bank TEXT,
    recipient_account TEXT,
    source_bank TEXT,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (scheduled_payment_id) REFERENCES scheduled_payments(id),
    FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(id)
  );
`);

console.log('✅ SQLite Database initialized with Bank Accounts at:', dbPath);
