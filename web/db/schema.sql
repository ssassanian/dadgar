-- =====================================================================
-- دادگر — اسکیمای دیتابیس (Postgres / Supabase)
-- پورت وفادار از اسکیمای SQLite سندشده در dadgar/lib/db.js (فایل مرجع، بدون تغییر)
-- اعمال‌شده روی پروژه Supabase: dadgar (ref: oyoywxgudbqmptwkxzpi)
-- تاریخ: 2026-10-27 — بخشی از CMD-002 (مهاجرت Vercel+Supabase)
-- نکته: این فایل هیچ رمز یا کلیدی ندارد و امن کامیت می‌شود.
-- =====================================================================

-- ---------- users ----------
-- تفاوت پورت: SQLite «username TEXT UNIQUE COLLATE NOCASE» داشت؛
-- در Postgres معادل آن ایندکس یکتا روی lower(username) است.
CREATE TABLE IF NOT EXISTS users(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username TEXT,
  role TEXT NOT NULL CHECK(role IN('client','lawyer','admin')),
  name TEXT NOT NULL, email TEXT,
  phone_hash TEXT UNIQUE, phone_last4 TEXT, phone_enc TEXT,
  password_hash TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK(status IN('active','pending','blocked')),
  must_change INTEGER NOT NULL DEFAULT 0,
  specialty TEXT, bio TEXT,
  created_at BIGINT NOT NULL, last_login BIGINT);
CREATE UNIQUE INDEX IF NOT EXISTS ix_users_username_nocase ON users(lower(username));

-- ---------- sessions ----------
-- CMD-026 (D-6 افزوده‌ی اول): ستون kind برای تفکیک نشست وب از توکن API موبایل:
--   'web' (پیش‌فرض) | 'api-access' (۱۵ دقیقه) | 'api-refresh' (۳۰ روز، چرخشی)
CREATE TABLE IF NOT EXISTS sessions(
  id TEXT PRIMARY KEY, user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  csrf TEXT NOT NULL, created_at BIGINT NOT NULL, last_seen BIGINT NOT NULL, expires_at BIGINT NOT NULL, ip TEXT, ua TEXT,
  kind TEXT NOT NULL DEFAULT 'web');
CREATE INDEX IF NOT EXISTS ix_sessions_user ON sessions(user_id);

-- ---------- otp ----------
CREATE TABLE IF NOT EXISTS otp(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, phone_hash TEXT NOT NULL, code_hash TEXT NOT NULL,
  expires_at BIGINT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, used INTEGER NOT NULL DEFAULT 0, created_at BIGINT NOT NULL, ip TEXT);
CREATE INDEX IF NOT EXISTS ix_otp_phone ON otp(phone_hash, created_at);

-- ---------- login_attempts ----------
CREATE TABLE IF NOT EXISTS login_attempts(key TEXT PRIMARY KEY, count INTEGER NOT NULL, first_at BIGINT NOT NULL, locked_until BIGINT NOT NULL DEFAULT 0);

-- ---------- rate_limits ----------
-- (مهاجرت) جایگزین محدودکننده نرخ درون‌حافظه‌ای server.js برای محیط سرورلس
CREATE TABLE IF NOT EXISTS rate_limits(key TEXT PRIMARY KEY, hits INTEGER NOT NULL, window_start BIGINT NOT NULL);

-- ---------- cases ----------
CREATE TABLE IF NOT EXISTS cases(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, client_id BIGINT NOT NULL REFERENCES users(id),
  category TEXT NOT NULL, title TEXT NOT NULL, description_enc TEXT,
  status TEXT NOT NULL DEFAULT 'waiting' CHECK(status IN('waiting','proposing','assigned','running','done')),
  lawyer_id BIGINT REFERENCES users(id), final_price BIGINT, created_at BIGINT NOT NULL, updated_at BIGINT NOT NULL);
CREATE INDEX IF NOT EXISTS ix_cases_client ON cases(client_id);
CREATE INDEX IF NOT EXISTS ix_cases_lawyer ON cases(lawyer_id);

-- ---------- proposals ----------
CREATE TABLE IF NOT EXISTS proposals(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, case_id BIGINT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  lawyer_id BIGINT NOT NULL REFERENCES users(id), amount BIGINT NOT NULL, days INTEGER NOT NULL, note_enc TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN('pending','accepted','rejected')), created_at BIGINT NOT NULL,
  UNIQUE(case_id, lawyer_id));

-- ---------- documents ----------
CREATE TABLE IF NOT EXISTS documents(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, case_id BIGINT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  owner_id BIGINT NOT NULL REFERENCES users(id), name_enc TEXT NOT NULL, mime TEXT, size BIGINT, file TEXT NOT NULL, created_at BIGINT NOT NULL);

-- ---------- messages ----------
CREATE TABLE IF NOT EXISTS messages(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, case_id BIGINT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id), body_enc TEXT NOT NULL, created_at BIGINT NOT NULL);

-- ---------- tickets ----------
CREATE TABLE IF NOT EXISTS tickets(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, user_id BIGINT NOT NULL REFERENCES users(id), dept TEXT, priority TEXT,
  subject TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open' CHECK(status IN('open','review','answered','closed')), created_at BIGINT NOT NULL, updated_at BIGINT NOT NULL);
CREATE TABLE IF NOT EXISTS ticket_messages(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, ticket_id BIGINT NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id), body_enc TEXT NOT NULL, created_at BIGINT NOT NULL);

-- ---------- appointments ----------
CREATE TABLE IF NOT EXISTS appointments(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, client_id BIGINT NOT NULL REFERENCES users(id), lawyer_id BIGINT REFERENCES users(id),
  starts_at BIGINT NOT NULL, kind TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'booked', created_at BIGINT NOT NULL);

-- ---------- invoices ----------
CREATE TABLE IF NOT EXISTS invoices(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, case_id BIGINT REFERENCES cases(id), client_id BIGINT NOT NULL REFERENCES users(id),
  amount BIGINT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', created_at BIGINT NOT NULL, paid_at BIGINT);

-- ---------- payment_requests (CMD-029 — درگاه پرداخت آنلاین) ----------
-- هر ردیف یک نشست پرداخت نزد درگاه (زيبال و در آینده providerهای دیگر)؛
-- track_id کلید یکتای درگاه است؛ amount_rial مبلغ ارسالی به درگاه (تومان×۱۰).
-- status: pending → paid | failed (پرداخت نشده) | mismatch (مغایرت مبلغ).
CREATE TABLE IF NOT EXISTS payment_requests(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  invoice_id BIGINT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  client_id BIGINT NOT NULL REFERENCES users(id),
  gateway TEXT NOT NULL, track_id BIGINT NOT NULL UNIQUE, amount_rial BIGINT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', ref_number TEXT, card_number TEXT,
  created_at BIGINT NOT NULL, paid_at BIGINT);

-- ---------- reviews ----------
CREATE TABLE IF NOT EXISTS reviews(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, case_id BIGINT NOT NULL REFERENCES cases(id), client_id BIGINT NOT NULL REFERENCES users(id),
  lawyer_id BIGINT NOT NULL REFERENCES users(id), rating INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 5), body TEXT,
  approved INTEGER NOT NULL DEFAULT 0, consent INTEGER NOT NULL DEFAULT 0, created_at BIGINT NOT NULL);

-- ---------- audit_log ----------
CREATE TABLE IF NOT EXISTS audit_log(
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, at BIGINT NOT NULL, user_id BIGINT, action TEXT NOT NULL, detail TEXT, ip TEXT);

-- ---------- settings ----------
-- CMD-010 — افزوده‌ی ثبت‌شده (نه پورت مرجع؛ اسکیمای مرجع جدول تنظیمات ندارد).
-- مدل key-value سفید‌لیست‌شده در سمت سرور (web/lib/web.js) برای aSet/aCms؛ سقف طول هر کلید در سرور.
CREATE TABLE IF NOT EXISTS settings(
  key TEXT PRIMARY KEY, value TEXT, updated_at BIGINT NOT NULL, updated_by BIGINT REFERENCES users(id));
