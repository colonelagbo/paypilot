import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dbPath = path.join(__dirname, 'paypilot.db');
export const db = new Database(dbPath);
db.pragma('journal_mode = WAL');

db.exec(`
CREATE TABLE IF NOT EXISTS users (
 id TEXT PRIMARY KEY, name TEXT NOT NULL, business_name TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
 bmoni_user_id TEXT NOT NULL, owner_address TEXT NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS wallets (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL, bmoni_wallet_id TEXT NOT NULL, wallet_address TEXT NOT NULL,
 currency TEXT NOT NULL DEFAULT 'CNGN', balance REAL NOT NULL DEFAULT 0, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS recipients (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL, name TEXT NOT NULL, account_number TEXT NOT NULL,
 bank_name TEXT NOT NULL, bank_code TEXT NOT NULL, wallet_address TEXT, category TEXT NOT NULL DEFAULT 'STAFF',
 bmoni_withdrawal_account_id TEXT, verified_account_name TEXT, verified_at DATETIME, created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS scheduled_payments (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL, recipient_id TEXT NOT NULL, amount REAL NOT NULL,
 payment_date TEXT NOT NULL, payment_time TEXT, description TEXT, batch_id TEXT, payment_type TEXT NOT NULL DEFAULT 'SINGLE',
 status TEXT NOT NULL DEFAULT 'SCHEDULED', shortfall_amount REAL DEFAULT 0, bmoni_wallet_id TEXT,
 bmoni_reference TEXT, bmoni_proposal_id TEXT, error_message TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
 executed_at DATETIME, FOREIGN KEY(user_id) REFERENCES users(id), FOREIGN KEY(recipient_id) REFERENCES recipients(id)
);
CREATE TABLE IF NOT EXISTS transactions (
 id TEXT PRIMARY KEY, scheduled_payment_id TEXT, bmoni_reference TEXT, amount REAL NOT NULL, currency TEXT NOT NULL DEFAULT 'CNGN',
 status TEXT NOT NULL, recipient_name TEXT NOT NULL, description TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(scheduled_payment_id) REFERENCES scheduled_payments(id)
);
CREATE TABLE IF NOT EXISTS webhook_events (
 event_id TEXT PRIMARY KEY, event_type TEXT NOT NULL, payload TEXT NOT NULL, received_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
`);

const addColumn = (sql) => { try { db.exec(sql); } catch (_) {} };
addColumn(`ALTER TABLE recipients ADD COLUMN bmoni_withdrawal_account_id TEXT`);
addColumn(`ALTER TABLE recipients ADD COLUMN verified_account_name TEXT`);
addColumn(`ALTER TABLE recipients ADD COLUMN verified_at DATETIME`);

// Remove legacy custody key if an old database has it. SQLite cannot drop a column safely in all versions,
// so the application simply never reads it; existing data should be rotated/deleted before production.
console.log('SQLite database initialized:', dbPath);
