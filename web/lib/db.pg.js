'use strict';
/* =====================================================================
 * دادگر — آداپتور دیتابیس Postgres (Supabase) برای محیط سرورلس Vercel
 * بخشی از مهاجرت CMD-002. فایل مرجع: dadgar/lib/db.js (بدون تغییر باقی مانده است)
 *
 * اصل طراحی: «سطح تماس» (call surface) کد اصلی حفظ شده است:
 *   db.prepare(sql).get/all/run(...) — با این تفاوت که async است (Postgres Async است)
 *   now() / audit() / tx() — همان امضاها
 * تبدیل‌های خودکار:
 *   - پارامترهای «?» سبک SQLite به «$n» پستگرس (quote-aware)
 *   - ستون‌های BIGINT (epoch-seconds) به Number (تا JSON مثل خروجی اصلی باشد)
 * ===================================================================== */
const postgres = require('postgres');
const cfg = require('./config');

if (!process.env.DATABASE_URL) {
  if (cfg.prod) { console.error('FATAL: DATABASE_URL must be set in production.'); process.exit(1); }
  console.error('[db.pg] DATABASE_URL is not set; local dev without DB.');
}

/* اتصال از طریق Transaction Pooler سوپابیس (سازگار با Serverless).
   prepare:false چون PgBouncer در حالت transaction از prepared statements پشتیبانی نمی‌کند. */
const sql = process.env.DATABASE_URL ? postgres(process.env.DATABASE_URL, {
  prepare: false, max: 5, idle_timeout: 20, connect_timeout: 15, onnotice: () => {}
}) : null;

const now = () => Math.floor(Date.now() / 1000);

/* تبدیل «?» به «$n» — کوتیشن‌های تک‌رشته‌ای را نادیده می‌گیرد */
function toPg(query) {
  let out = '', n = 0, inS = false;
  for (let i = 0; i < query.length; i++) {
    const ch = query[i];
    if (ch === "'") { inS = !inS; out += ch; continue; }
    if (ch === '?' && !inS) out += '$' + (++n); else out += ch;
  }
  return out;
}

/* ستون‌های BIGINT که باید به Number برگردند تا رفتار JSON با SQLite اصلی یکسان بماند */
const NUM_COLS = new Set(['id','user_id','client_id','lawyer_id','case_id','ticket_id','owner_id',
  'created_at','updated_at','expires_at','last_seen','last_login','first_at','locked_until',
  'starts_at','paid_at','at','amount','final_price','size','window_start']);
function fixRow(row) {
  if (!row || typeof row !== 'object') return row;
  for (const k in row) if (NUM_COLS.has(k) && typeof row[k] === 'string' && /^-?\d+$/.test(row[k])) row[k] = Number(row[k]);
  return row;
}
const fixRows = (rows) => (Array.isArray(rows) ? rows.map(fixRow) : fixRow(rows));

const db = {
  prepare(query) {
    const q = toPg(query);
    return {
      async get(...p) { const r = await sql.unsafe(q, p); return fixRow(r[0]); },
      async all(...p) { return fixRows(await sql.unsafe(q, p)); },
      async run(...p) {
        const r = await sql.unsafe(q, p);
        const first = r[0];
        return { changes: r.count || 0, lastInsertRowid: first && first.id !== undefined ? first.id : undefined };
      }
    };
  },
  async exec(query) { return await sql.unsafe(query); }
};

/* audit در کد اصلی sync بود؛ اینجا await می‌شود تا در سرورلس از دست نرود.
   خطا سرور را نمی‌شکند (فقط لاگ می‌شود). */
const audit = (uid, action, detail, ip) => db.prepare(
  'INSERT INTO audit_log(at,user_id,action,detail,ip) VALUES(?,?,?,?,?)'
).run(now(), uid || null, action, detail ? String(detail).slice(0, 300) : null, ip || null)
 .catch((e) => console.error('[audit]', e.message));

/* tx در فاز ۱ و ۲ کد اصلی استفاده نمی‌شود؛ برای سازگاری آینده از sql.begin استفاده می‌کند */
const tx = (fn) => sql.begin(async (tsx) => fn({ sql: tsx, now }));

module.exports = { sql, db, now, audit, tx };
