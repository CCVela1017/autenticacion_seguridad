import DatabaseConstructor from 'better-sqlite3';
import type { Database } from 'better-sqlite3';

let db: Database;

db = new DatabaseConstructor('auth.db');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    totp_secret TEXT,
    totp_confirmed INTEGER DEFAULT 0,
    role TEXT
  )
`);

export default db;