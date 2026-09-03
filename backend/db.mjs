import { DatabaseSync } from 'node:sqlite';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.join(__dirname, 'paypilot.db');

export const db = new DatabaseSync(dbPath);

// Initialize tables
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    business_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    bmoni_user_id TEXT NOT NULL,
    owner_address TEXT NOT NULL,
    owner_private_key TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS wallets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    bmoni_wallet_id TEXT NOT NULL,
    wallet_address TEXT NOT NULL,
    currency TEXT NOT NULL DEFAULT 'CNGN',
    balance REAL NOT NULL DEFAULT 0.0,
    sandbox_funded_balance REAL NOT NULL DEFAULT 0.0,
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
    wallet_address TEXT,
    category TEXT NOT NULL DEFAULT 'STAFF',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS scheduled_payments (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    recipient_id TEXT NOT NULL,
    amount REAL NOT NULL,
    payment_date TEXT NOT NULL,
    payment_time TEXT,
    description TEXT,
    batch_id TEXT,
    payment_type TEXT NOT NULL DEFAULT 'SINGLE',
    status TEXT NOT NULL DEFAULT 'SCHEDULED',
    shortfall_amount REAL DEFAULT 0.0,
    bmoni_wallet_id TEXT,
    bmoni_reference TEXT,
    bmoni_proposal_id TEXT,
    error_message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    executed_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (recipient_id) REFERENCES recipients(id)
  );

  CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY,
    scheduled_payment_id TEXT,
    bmoni_reference TEXT NOT NULL,
    amount REAL NOT NULL,
    currency TEXT NOT NULL DEFAULT 'CNGN',
    status TEXT NOT NULL,
    recipient_name TEXT NOT NULL,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (scheduled_payment_id) REFERENCES scheduled_payments(id)
  );
`);

try {
  db.prepare("ALTER TABLE recipients ADD COLUMN category TEXT DEFAULT 'STAFF'").run();
} catch (e) {
  // Column already exists
}

console.log('✅ SQLite Database initialized at:', dbPath);
