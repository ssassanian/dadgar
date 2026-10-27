'use strict';
const fs = require('fs'), path = require('path');
const { DatabaseSync } = require('node:sqlite');
const cfg = require('./config');
fs.mkdirSync(path.join(cfg.dataDir, 'files'), { recursive: true, mode: 0o700 });
const db = new DatabaseSync(path.join(cfg.dataDir, 'dadgar.sqlite'));
db.exec(`
PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000; PRAGMA secure_delete=ON;
CREATE TABLE IF NOT EXISTS users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE COLLATE NOCASE,
  role TEXT NOT NULL CHECK(role IN('client','lawyer','admin')),
  name TEXT NOT NULL, email TEXT,
  phone_hash TEXT UNIQUE, phone_last4 TEXT, phone_enc TEXT,
  password_hash TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK(status IN('active','pending','blocked')),
  must_change INTEGER NOT NULL DEFAULT 0,
  specialty TEXT, bio TEXT,
  created_at INTEGER NOT NULL, last_login INTEGER);
CREATE TABLE IF NOT EXISTS sessions(
  id TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  csrf TEXT NOT NULL, created_at INTEGER NOT NULL, last_seen INTEGER NOT NULL, expires_at INTEGER NOT NULL, ip TEXT, ua TEXT);
CREATE INDEX IF NOT EXISTS ix_sessions_user ON sessions(user_id);
CREATE TABLE IF NOT EXISTS otp(
  id INTEGER PRIMARY KEY AUTOINCREMENT, phone_hash TEXT NOT NULL, code_hash TEXT NOT NULL,
  expires_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, used INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, ip TEXT);
CREATE INDEX IF NOT EXISTS ix_otp_phone ON otp(phone_hash, created_at);
CREATE TABLE IF NOT EXISTS login_attempts(key TEXT PRIMARY KEY, count INTEGER NOT NULL, first_at INTEGER NOT NULL, locked_until INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS cases(
  id INTEGER PRIMARY KEY AUTOINCREMENT, client_id INTEGER NOT NULL REFERENCES users(id),
  category TEXT NOT NULL, title TEXT NOT NULL, description_enc TEXT,
  status TEXT NOT NULL DEFAULT 'waiting' CHECK(status IN('waiting','proposing','assigned','running','done')),
  lawyer_id INTEGER REFERENCES users(id), final_price INTEGER, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS ix_cases_client ON cases(client_id); CREATE INDEX IF NOT EXISTS ix_cases_lawyer ON cases(lawyer_id);
CREATE TABLE IF NOT EXISTS proposals(
  id INTEGER PRIMARY KEY AUTOINCREMENT, case_id INTEGER NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  lawyer_id INTEGER NOT NULL REFERENCES users(id), amount INTEGER NOT NULL, days INTEGER NOT NULL, note_enc TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN('pending','accepted','rejected')), created_at INTEGER NOT NULL,
  UNIQUE(case_id, lawyer_id));
CREATE TABLE IF NOT EXISTS documents(
  id INTEGER PRIMARY KEY AUTOINCREMENT, case_id INTEGER NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  owner_id INTEGER NOT NULL REFERENCES users(id), name_enc TEXT NOT NULL, mime TEXT, size INTEGER, file TEXT NOT NULL, created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS messages(
  id INTEGER PRIMARY KEY AUTOINCREMENT, case_id INTEGER NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id), body_enc TEXT NOT NULL, created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS tickets(
  id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL REFERENCES users(id), dept TEXT, priority TEXT,
  subject TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open' CHECK(status IN('open','review','answered','closed')), created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS ticket_messages(
  id INTEGER PRIMARY KEY AUTOINCREMENT, ticket_id INTEGER NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id), body_enc TEXT NOT NULL, created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS appointments(
  id INTEGER PRIMARY KEY AUTOINCREMENT, client_id INTEGER NOT NULL REFERENCES users(id), lawyer_id INTEGER REFERENCES users(id),
  starts_at INTEGER NOT NULL, kind TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'booked', created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS invoices(
  id INTEGER PRIMARY KEY AUTOINCREMENT, case_id INTEGER REFERENCES cases(id), client_id INTEGER NOT NULL REFERENCES users(id),
  amount INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'pending', created_at INTEGER NOT NULL, paid_at INTEGER);
CREATE TABLE IF NOT EXISTS reviews(
  id INTEGER PRIMARY KEY AUTOINCREMENT, case_id INTEGER NOT NULL REFERENCES cases(id), client_id INTEGER NOT NULL REFERENCES users(id),
  lawyer_id INTEGER NOT NULL REFERENCES users(id), rating INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 5), body TEXT,
  approved INTEGER NOT NULL DEFAULT 0, consent INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS audit_log(
  id INTEGER PRIMARY KEY AUTOINCREMENT, at INTEGER NOT NULL, user_id INTEGER, action TEXT NOT NULL, detail TEXT, ip TEXT);
`);
const now = () => Math.floor(Date.now() / 1000);
const audit = (uid, action, detail, ip) => db.prepare('INSERT INTO audit_log(at,user_id,action,detail,ip) VALUES(?,?,?,?,?)').run(now(), uid || null, action, detail ? String(detail).slice(0, 300) : null, ip || null);
const tx = (fn) => { db.exec('BEGIN IMMEDIATE'); try { const r = fn(); db.exec('COMMIT'); return r; } catch (e) { db.exec('ROLLBACK'); throw e; } };
module.exports = { db, now, audit, tx };
