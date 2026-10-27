'use strict';
/* =====================================================================
 * دادگر — منطق وب (پورت وفادار server.js برای Vercel Serverless + Supabase)
 * بخشی از مهاجرت CMD-002. فایل مرجع: dadgar/server.js (بدون تغییر باقی مانده است)
 *
 * تفاوت‌های پورت (همه مستند و حداقلی):
 *  1) تمام فراخوانی‌های db.prepare(...) با await (Postgres async است؛ هندلرها از قبل async بودند)
 *  2) محدودکننده نرخ درون‌حافظه‌ای (Map) → جدول rate_limits در Postgres (پنجره ثابت)
 *  3) پاکسازی دوره‌ای setInterval → در startSession اجرا می‌شود (سرورلس پردازش همیشگی ندارد)
 *  4) «LIMIT -1 OFFSET 4» سبک SQLite → «NOT IN (... LIMIT 4)» معادل
 *  5) ساخت کاربر با «RETURNING id» به‌جای lastInsertRowid SQLite
 *  6) جست‌وجوی username با lower() = معادل COLLATE NOCASE
 *  7) serveStatic فقط از پوشه dynamic/ سرو می‌کند (فقط index.html وجود دارد) — همان CSP nonce
 * ===================================================================== */
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const cfg = require('./config'), sec = require('./security'), { db, now, audit, tx, toPg } = require('./db.pg'), sendSms = require('./sms');
const PUB = path.join(__dirname, '..', 'dynamic');
const COOKIE = cfg.cookieSecure ? '__Host-sid' : 'sid';
class HttpError extends Error { constructor(s, m) { super(m); this.s = s; } }

/* ---------- small utilities (identical) ---------- */
const DIG = { '۰': 0, '۱': 1, '۲': 2, '۳': 3, '۴': 4, '۵': 5, '۶': 6, '۷': 7, '۸': 8, '۹': 9, '٠': 0, '١': 1, '٢': 2, '٣': 3, '٤': 4, '٥': 5, '٦': 6, '٧': 7, '٨': 8, '٩': 9 };
const ascii = (s) => String(s || '').replace(/[۰-۹٠-٩]/g, (d) => DIG[d]);
function normPhone(v) {
  let s = ascii(String(v || '')).replace(/[\s\-()]/g, '');
  s = s.replace(/^(\+98|0098|98)/, '0');
  if (!/^09\d{9}$/.test(s)) throw new HttpError(400, 'شماره‌ی تماس معتبر نیست (مثال: ۰۹۱۲۰۰۰۰۰۰۰).');
  return s;
}
function str(v, min, max, label, trim = true) {
  if (typeof v !== 'string') throw new HttpError(400, (label || 'مقدار') + ' نامعتبر است.');
  const s = trim ? v.trim() : v;
  if (s.length < min || s.length > max) throw new HttpError(400, (label || 'مقدار') + ' نامعتبر است.');
  if (/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/.test(s)) throw new HttpError(400, (label || 'مقدار') + ' نامعتبر است.');
  return s;
}
function int(v, min, max, label) {
  const n = typeof v === 'number' ? v : parseInt(ascii(String(v)), 10);
  if (!Number.isInteger(n) || n < min || n > max) throw new HttpError(400, (label || 'عدد') + ' نامعتبر است.');
  return n;
}
const oneOf = (v, list, label) => { if (!list.includes(v)) throw new HttpError(400, (label || 'مقدار') + ' نامعتبر است.'); return v; };
const ipOf = (req) => (cfg.trustProxy && req.headers['x-real-ip']) ? String(req.headers['x-real-ip']).slice(0, 64) : (req.socket.remoteAddress || '');
const CATS = ['ملکی', 'خانواده', 'کیفری', 'شرکت‌ها', 'ارث و وصیت', 'قرارداد'];

/* ---------- rate limiter (ported: in-memory Map → Postgres fixed-window) ---------- */
async function rl(key, max, ms) {
  const n = now(), win = Math.floor(ms / 1000);
  try {
    const r = await db.prepare(`INSERT INTO rate_limits(key,hits,window_start) VALUES(?,1,?)
      ON CONFLICT(key) DO UPDATE SET
        hits = CASE WHEN rate_limits.window_start <= ? THEN 1 ELSE rate_limits.hits + 1 END,
        window_start = CASE WHEN rate_limits.window_start <= ? THEN ? ELSE rate_limits.window_start END
      RETURNING hits`).get(key, n, n - win, n - win, n);
    return r.hits <= max;
  } catch (e) { console.error('[rl]', e.message); return true; } // در خطای دیتابیس دسترس‌پذیری مقدم است
}

/* ---------- http helpers (identical) ---------- */
function baseHeaders(res) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
  if (cfg.cookieSecure) res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
}
function json(res, code, obj, headers) {
  const b = Buffer.from(JSON.stringify(obj));
  res.writeHead(code, Object.assign({ 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': b.length, 'Cache-Control': 'no-store' }, headers || {}));
  res.end(b);
}
function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const parts = []; let n = 0;
    req.on('data', (c) => { if (n > limit) return; n += c.length; if (n > limit) { parts.length = 0; reject(new HttpError(413, 'حجم درخواست بیش از حد مجاز است.')); } else parts.push(c); });
    req.on('end', () => resolve(Buffer.concat(parts)));
    req.on('error', reject);
  });
}
const parseCookies = (h) => Object.fromEntries(String(h).split(';').map((x) => x.trim().split('=')).filter((x) => x[0]).map((x) => [x[0], x.slice(1).join('=')]));
const setCookie = (res, v, maxAge) => res.setHeader('Set-Cookie', `${COOKIE}=${v}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${maxAge}` + (cfg.cookieSecure ? '; Secure' : ''));

/* ---------- sessions ---------- */
function pub(u) {
  return { id: u.id, role: u.role, name: u.name, username: u.username, email: u.email || '', phone: u.phone_last4 ? '0•••••' + u.phone_last4 : '', mustChange: !!u.must_change, specialty: u.specialty || '' };
}
async function startSession(res, user, req, ip) {
  const n = now(), t = sec.token(), csrf = sec.token();
  await db.prepare('DELETE FROM sessions WHERE user_id=? AND id NOT IN (SELECT id FROM sessions WHERE user_id=? ORDER BY created_at DESC LIMIT 4)').run(user.id, user.id);
  /* پاکسازی‌های دوره‌ای (در نسخه اصلی: setInterval هر ۱۰ دقیقه) */
  await db.prepare('DELETE FROM sessions WHERE expires_at<?').run(n);
  await db.prepare('DELETE FROM otp WHERE created_at<?').run(n - 86400);
  await db.prepare('DELETE FROM login_attempts WHERE locked_until<? AND first_at<?').run(n, n - 3600);
  await db.prepare('INSERT INTO sessions(id,user_id,csrf,created_at,last_seen,expires_at,ip,ua) VALUES(?,?,?,?,?,?,?,?)').run(sec.sha(t), user.id, csrf, n, n, n + cfg.sessionMaxMs / 1000, ip, String(req.headers['user-agent'] || '').slice(0, 200));
  await db.prepare('UPDATE users SET last_login=? WHERE id=?').run(n, user.id);
  setCookie(res, t, cfg.sessionMaxMs / 1000);
  return csrf;
}
async function getSession(req) {
  const t = parseCookies(req.headers.cookie || '')[COOKIE];
  if (!t || t.length > 100) return null;
  const id = sec.sha(t), s = await db.prepare('SELECT * FROM sessions WHERE id=?').get(id);
  if (!s) return null;
  const n = now();
  if (s.expires_at < n || n - s.last_seen > cfg.sessionIdleMs / 1000) { await db.prepare('DELETE FROM sessions WHERE id=?').run(id); return null; }
  const user = await db.prepare('SELECT * FROM users WHERE id=?').get(s.user_id);
  if (!user || user.status !== 'active') return null;
  if (n - s.last_seen > 60) await db.prepare('UPDATE sessions SET last_seen=? WHERE id=?').run(n, id);
  return { id, csrf: s.csrf, user };
}

/* ---------- login throttling (persistent, identical logic) ---------- */
const locked = async (k) => { const r = await db.prepare('SELECT locked_until FROM login_attempts WHERE key=?').get(k); return !!(r && r.locked_until > now()); };
async function fail(k, limit) {
  const n = now(), r = await db.prepare('SELECT * FROM login_attempts WHERE key=?').get(k);
  let count = 1, first = n; if (r && n - r.first_at < 900) { count = r.count + 1; first = r.first_at; }
  const lock = count >= limit ? n + Math.min(3600, 60 * 2 ** Math.min(count - limit, 6)) : 0;
  await db.prepare('INSERT INTO login_attempts(key,count,first_at,locked_until) VALUES(?,?,?,?) ON CONFLICT(key) DO UPDATE SET count=?,first_at=?,locked_until=?').run(k, count, first, lock, count, first, lock);
}
const clearFail = async (k) => { await db.prepare('DELETE FROM login_attempts WHERE key=?').run(k); };

/* ---------- routing (identical) ---------- */
const routes = [];
function route(method, pattern, opts, fn) {
  const keys = []; const re = new RegExp('^' + pattern.replace(/:(\w+)/g, (_, k) => { keys.push(k); return '(\\d+)'; }) + '$');
  routes.push({ method, re, keys, opts, fn });
}
const isAuth = { auth: true };
const ROLE = (...r) => ({ auth: true, roles: r });

/* ---------- auth routes ---------- */
route('GET', '/api/health', {}, async () => ({ ok: true }));

route('POST', '/api/auth/login', {}, async (c) => {
  if (!(await rl('login:' + c.ip, +process.env.LOGIN_RL_MAX || 30, 600e3))) throw new HttpError(429, 'تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید.');
  let username = str(c.body.username, 1, 64, 'نام کاربری').toLowerCase(); const password = str(c.body.password, 1, 200, 'رمز عبور', false);
  let byPhone = null;
  if (/^[0-9۰-۹٠-٩+\s-]{10,16}$/.test(username)) { try { byPhone = normPhone(username); username = byPhone; } catch { } } // phone number can be used as username
  const ku = 'u:' + username, ki = 'i:' + c.ip;
  if ((await locked(ku)) || (await locked(ki))) { await audit(null, 'login_locked', username, c.ip); throw new HttpError(429, 'تلاش‌های ناموفق زیاد بود. چند دقیقه بعد دوباره تلاش کنید.'); }
  const u = byPhone ? await db.prepare('SELECT * FROM users WHERE phone_hash=? AND password_hash IS NOT NULL').get(sec.hmac('phone:' + byPhone)) : await db.prepare('SELECT * FROM users WHERE lower(username)=lower(?) AND password_hash IS NOT NULL').get(username);
  let ok = false;
  if (u) ok = await sec.verifyPassword(password, u.password_hash); else await sec.dummyVerify(password);
  if (!ok || u.status !== 'active') { await fail(ku, 5); await fail(ki, 25); await audit(u && u.id, 'login_fail', username, c.ip); throw new HttpError(401, 'نام کاربری یا رمز عبور اشتباه است.'); }
  await clearFail(ku);
  const csrf = await startSession(c.res, u, c.req, c.ip);
  await audit(u.id, 'login', 'password', c.ip);
  return { user: pub(u), csrf };
});

route('POST', '/api/auth/logout', { auth: true, allowMust: true }, async (c) => {
  await db.prepare('DELETE FROM sessions WHERE id=?').run(c.sess.id);
  setCookie(c.res, '', 0); await audit(c.user.id, 'logout', null, c.ip);
  return { ok: true };
});

route('GET', '/api/me', {}, async (c) => {
  if (!c.user) return { user: null, csrf: '' }; // guests get 200 so the browser console stays clean
  return { user: pub(c.user), csrf: c.sess.csrf };
});

route('PATCH', '/api/me', isAuth, async (c) => {
  const name = str(c.body.name, 2, 60, 'نام'); const email = c.body.email ? str(c.body.email, 5, 120, 'ایمیل') : '';
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError(400, 'ایمیل معتبر نیست.');
  await db.prepare('UPDATE users SET name=?,email=? WHERE id=?').run(name, email || null, c.user.id);
  await audit(c.user.id, 'profile_update', null, c.ip);
  return { ok: true };
});

route('POST', '/api/me/password', { auth: true, allowMust: true }, async (c) => {
  if (!(await rl('pw:' + c.user.id, 8, 600e3))) throw new HttpError(429, 'تعداد تلاش‌ها زیاد است.');
  const cur = str(c.body.current, 1, 200, 'رمز فعلی', false), next = str(c.body.next, 1, 200, 'رمز جدید', false);
  if (!(await sec.verifyPassword(cur, c.user.password_hash))) { await audit(c.user.id, 'password_change_fail', null, c.ip); throw new HttpError(400, 'رمز فعلی اشتباه است.'); }
  const p = sec.passwordProblem(next, c.user.username); if (p) throw new HttpError(400, p);
  if (next === cur) throw new HttpError(400, 'رمز جدید باید با رمز فعلی متفاوت باشد.');
  await db.prepare('UPDATE users SET password_hash=?,must_change=0 WHERE id=?').run(await sec.hashPassword(next), c.user.id);
  await db.prepare('DELETE FROM sessions WHERE user_id=? AND id<>?').run(c.user.id, c.sess.id);
  await audit(c.user.id, 'password_change', null, c.ip);
  return { ok: true };
});

/* ---------- phone / OTP ---------- */
async function issueOtp(phone, ip) {
  const ph = sec.hmac('phone:' + phone), n = now();
  if (!(await rl('otpip:' + ip, 10, 600e3))) throw new HttpError(429, 'تعداد درخواست‌ها زیاد است. بعداً تلاش کنید.');
  const last = await db.prepare('SELECT created_at FROM otp WHERE phone_hash=? ORDER BY id DESC LIMIT 1').get(ph);
  if (last && n - last.created_at < 60) throw new HttpError(429, 'برای دریافت کد جدید ' + (60 - (n - last.created_at)) + ' ثانیه صبر کنید.');
  if ((await db.prepare('SELECT COUNT(*) c FROM otp WHERE phone_hash=? AND created_at>?').get(ph, n - 3600)).c >= 5) throw new HttpError(429, 'سقف درخواست کد برای این شماره تکمیل شده است. بعداً تلاش کنید.');
  const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  await db.prepare('INSERT INTO otp(phone_hash,code_hash,expires_at,created_at,ip) VALUES(?,?,?,?,?)').run(ph, sec.hmac(ph + ':' + code), n + 120, n, ip);
  try { await sendSms(phone, 'کد ورود موسسه حقوقی دادگر: ' + code + '\nاین کد را به هیچ‌کس نگویید.'); } catch (e) { console.error('[sms]', e.message); }
  return code;
}
route('POST', '/api/auth/otp/request', {}, async (c) => {
  const phone = normPhone(c.body.phone), code = await issueOtp(phone, c.ip);
  await audit(null, 'otp_request', phone.slice(-4), c.ip);
  return Object.assign({ ok: true, expiresIn: 120 }, cfg.showOtp ? { devCode: code } : {});
});
route('POST', '/api/auth/otp/verify', {}, async (c) => {
  const phone = normPhone(c.body.phone), code = ascii(str(c.body.code, 4, 10, 'کد'));
  if (!/^\d{6}$/.test(code)) throw new HttpError(400, 'کد باید ۶ رقم باشد.');
  if (!(await rl('otpv:' + c.ip, 20, 600e3))) throw new HttpError(429, 'تعداد تلاش‌ها زیاد است.');
  const ph = sec.hmac('phone:' + phone), n = now();
  const row = await db.prepare('SELECT * FROM otp WHERE phone_hash=? AND used=0 AND expires_at>? ORDER BY id DESC LIMIT 1').get(ph, n);
  const bad = new HttpError(400, 'کد نامعتبر یا منقضی شده است.');
  if (!row || row.attempts >= 5) throw bad;
  if (!sec.safeEq(row.code_hash, sec.hmac(ph + ':' + code))) { await db.prepare('UPDATE otp SET attempts=attempts+1 WHERE id=?').run(row.id); await audit(null, 'otp_fail', phone.slice(-4), c.ip); throw bad; }
  await db.prepare('UPDATE otp SET used=1 WHERE id=?').run(row.id);
  let u = await db.prepare('SELECT * FROM users WHERE phone_hash=?').get(ph);
  if (!u) {
    const r = await db.prepare("INSERT INTO users(role,name,phone_hash,phone_last4,phone_enc,status,created_at) VALUES('client',?,?,?,?,'active',?) RETURNING id").run('کاربر ' + phone.slice(-4), ph, phone.slice(-4), sec.encText(phone, 'user.phone'), n);
    u = await db.prepare('SELECT * FROM users WHERE id=?').get(r.lastInsertRowid); await audit(u.id, 'register_phone', null, c.ip);
  } else if (u.status === 'pending') { await db.prepare("UPDATE users SET status='active' WHERE id=?").run(u.id); u.status = 'active'; }
  if (u.status !== 'active') throw new HttpError(403, 'دسترسی این حساب مسدود است.');
  if (u.role === 'admin') throw new HttpError(403, 'ورود مدیر فقط با نام کاربری و رمز عبور ممکن است.');
  const csrf = await startSession(c.res, u, c.req, c.ip); await audit(u.id, 'login', 'otp', c.ip);
  return { user: pub(u), csrf };
});
route('POST', '/api/auth/register', {}, async (c) => {
  const name = str(c.body.name, 2, 60, 'نام'), phone = normPhone(c.body.phone), pw = str(c.body.password, 1, 200, 'رمز عبور', false);
  const p = sec.passwordProblem(pw, phone); if (p) throw new HttpError(400, p);
  const ph = sec.hmac('phone:' + phone);
  const hash = await sec.hashPassword(pw);
  if (!(await db.prepare('SELECT 1 FROM users WHERE phone_hash=?').get(ph)))
    await db.prepare("INSERT INTO users(role,name,phone_hash,phone_last4,phone_enc,password_hash,status,created_at) VALUES('client',?,?,?,?,?,'pending',?)").run(name, ph, phone.slice(-4), sec.encText(phone, 'user.phone'), hash, now());
  const code = await issueOtp(phone, c.ip); await audit(null, 'register_request', phone.slice(-4), c.ip);
  return Object.assign({ ok: true, expiresIn: 120 }, cfg.showOtp ? { devCode: code } : {}); // same answer whether or not the phone existed
});

/* ---------- CMD-003 — فاز ۳ گام ۱: چرخه پرونده (cases + proposals) ----------
 * وضعیت‌ها مطابق اسکیمای مرجع: waiting → proposing → assigned → running → done
 * «running/done» در گام‌های بعدی (گزارش کار/بستن پرونده) وصل می‌شوند.
 * امنیت: توضیحات پرونده و یادداشت پیشنهاد با AES-256-GCM (encText) در دیتابیس ذخیره می‌شوند.
 * حریم خصوصی: نام/شماره مشتری فقط به خودش و مدیر می‌رسد؛ وکیلِ ناشناس فقط خلاصه را می‌بیند.
 * ========================================================================== */
const CASES_PER = 10, EXCERPT_LEN = 160;

function caseListRow(r, ctx) {
  const o = { id: r.id, title: r.title, category: r.category, status: r.status, created_at: r.created_at, updated_at: r.updated_at, final_price: r.final_price, client_id: r.client_id, lawyer_id: r.lawyer_id, lawyer_name: r.lawyer_name || '' };
  if (ctx.excerpt) o.excerpt = String(sec.decText(r.description_enc, 'case.description') || '').slice(0, EXCERPT_LEN);
  if (ctx.clientInfo) { o.client_name = r.client_name || ''; o.client_phone = r.phone_last4 ? '0•••••' + r.phone_last4 : ''; }
  return o;
}

route('GET', '/api/cases', isAuth, async (c) => {
  const page = Math.max(1, int(ascii(c.query.page || '1') || '1', 1, 500, 'صفحه'));
  const off = (page - 1) * CASES_PER;
  const SEL = 'SELECT cs.*, cl.name AS client_name, cl.phone_last4, lw.name AS lawyer_name FROM cases cs LEFT JOIN users cl ON cl.id=cs.client_id LEFT JOIN users lw ON lw.id=cs.lawyer_id';
  let rows, total, ctx = {};
  if (c.user.role === 'client') {
    total = (await db.prepare('SELECT COUNT(*) n FROM cases WHERE client_id=?').get(c.user.id)).n;
    rows = await db.prepare(SEL + ' WHERE cs.client_id=? ORDER BY cs.created_at DESC, cs.id DESC LIMIT ? OFFSET ?').all(c.user.id, CASES_PER, off);
  } else if (c.user.role === 'lawyer' && c.query.scope === 'open') {
    // پرونده‌های درجریانِ پیشنهاد — بدون مشخصات مشتری، با خلاصه (سقف ۵۰)
    rows = await db.prepare(SEL + " WHERE cs.status IN('waiting','proposing') ORDER BY cs.created_at DESC, cs.id DESC LIMIT 50").all();
    total = rows.length;
    ctx.excerpt = true;
    return { ok: true, rows: rows.map((r) => caseListRow(r, ctx)), page: 1, pages: 1, total };
  } else if (c.user.role === 'lawyer') {
    total = (await db.prepare('SELECT COUNT(*) n FROM cases WHERE lawyer_id=?').get(c.user.id)).n;
    rows = await db.prepare(SEL + ' WHERE cs.lawyer_id=? ORDER BY cs.created_at DESC, cs.id DESC LIMIT ? OFFSET ?').all(c.user.id, CASES_PER, off);
  } else {
    total = (await db.prepare('SELECT COUNT(*) n FROM cases').get()).n;
    rows = await db.prepare(SEL + ' ORDER BY cs.created_at DESC, cs.id DESC LIMIT ? OFFSET ?').all(CASES_PER, off);
    ctx.clientInfo = true;
  }
  return { ok: true, rows: rows.map((r) => caseListRow(r, ctx)), page, pages: Math.max(1, Math.ceil(total / CASES_PER)), total };
});

route('POST', '/api/cases', ROLE('client'), async (c) => {
  if (!(await rl('case:' + c.user.id, 5, 3600e3))) throw new HttpError(429, 'سقف ثبت پرونده در یک ساعت تکمیل شده است. بعداً تلاش کنید.');
  const category = oneOf(c.body.category, CATS, 'دسته‌بندی');
  const title = str(c.body.title, 5, 120, 'عنوان پرونده');
  const description = c.body.description == null ? '' : str(c.body.description, 0, 5000, 'توضیحات');
  const n = now();
  const r = await db.prepare("INSERT INTO cases(client_id,category,title,description_enc,status,created_at,updated_at) VALUES(?,?,?,?,'waiting',?,?) RETURNING id")
    .run(c.user.id, category, title, sec.encText(description, 'case.description'), n, n);
  await audit(c.user.id, 'case_create', 'case:' + r.lastInsertRowid, c.ip);
  return { ok: true, id: r.lastInsertRowid };
});

route('GET', '/api/cases/:id', isAuth, async (c) => {
  const cs = await db.prepare('SELECT cs.*, cl.name AS client_name, cl.phone_last4, lw.name AS lawyer_name FROM cases cs LEFT JOIN users cl ON cl.id=cs.client_id LEFT JOIN users lw ON lw.id=cs.lawyer_id WHERE cs.id=?').get(c.params.id);
  if (!cs) throw new HttpError(404, 'پرونده یافت نشد.');
  const me = c.user;
  let canSee = false, full = false;
  if (me.role === 'admin') { canSee = true; full = true; }
  else if (me.role === 'client') { canSee = cs.client_id === me.id; full = true; }
  else if (me.role === 'lawyer') { canSee = cs.lawyer_id === me.id || cs.status === 'waiting' || cs.status === 'proposing'; full = cs.lawyer_id === me.id; }
  if (!canSee) throw new HttpError(404, 'پرونده یافت نشد.'); // بدون افشای وجود پرونده
  const o = { ok: true, id: cs.id, title: cs.title, category: cs.category, status: cs.status, created_at: cs.created_at, updated_at: cs.updated_at, final_price: cs.final_price, lawyer_name: cs.lawyer_name || '' };
  if (full) o.description = sec.decText(cs.description_enc, 'case.description');
  else o.excerpt = String(sec.decText(cs.description_enc, 'case.description') || '').slice(0, EXCERPT_LEN);
  if (me.role === 'admin') { o.client_name = cs.client_name || ''; o.client_phone = cs.phone_last4 ? '0•••••' + cs.phone_last4 : ''; }
  if (me.role === 'admin') {
    const ps = await db.prepare('SELECT p.*, u.name AS lawyer_name FROM proposals p LEFT JOIN users u ON u.id=p.lawyer_id WHERE p.case_id=? ORDER BY p.created_at ASC, p.id ASC').all(cs.id);
    o.proposals = ps.map((p) => ({ id: p.id, lawyer_name: p.lawyer_name || '', amount: p.amount, days: p.days, note: sec.decText(p.note_enc, 'proposal.note'), status: p.status, created_at: p.created_at }));
  }
  if (me.role === 'lawyer') {
    const mine = await db.prepare('SELECT * FROM proposals WHERE case_id=? AND lawyer_id=?').get(cs.id, me.id);
    o.my_proposal = mine ? { id: mine.id, amount: mine.amount, days: mine.days, note: sec.decText(mine.note_enc, 'proposal.note'), status: mine.status, created_at: mine.created_at } : null;
  }
  return o;
});

route('PATCH', '/api/cases/:id', ROLE('admin'), async (c) => {
  const cs = await db.prepare('SELECT * FROM cases WHERE id=?').get(c.params.id);
  if (!cs) throw new HttpError(404, 'پرونده یافت نشد.');
  if (c.body.final_price !== undefined) {
    const fp = int(c.body.final_price, 0, 10 * 1000 * 1000 * 1000, 'مبلغ نهایی');
    await db.prepare('UPDATE cases SET final_price=?,updated_at=? WHERE id=?').run(fp, now(), cs.id);
    await audit(c.user.id, 'case_final_price', 'case:' + cs.id, c.ip);
  }
  return { ok: true };
});

route('POST', '/api/cases/:id/proposals', ROLE('lawyer'), async (c) => {
  const amount = int(c.body.amount, 1000, 10 * 1000 * 1000 * 1000, 'مبلغ پیشنهادی');
  const days = int(c.body.days, 1, 3650, 'مدت زمان');
  const note = c.body.note == null ? '' : str(c.body.note, 0, 2000, 'یادداشت');
  const cs = await db.prepare('SELECT * FROM cases WHERE id=?').get(c.params.id);
  if (!cs || (cs.status !== 'waiting' && cs.status !== 'proposing')) throw new HttpError(404, 'این پرونده در مرحله‌ی دریافت پیشنهاد نیست.');
  if (await db.prepare('SELECT 1 FROM proposals WHERE case_id=? AND lawyer_id=?').get(cs.id, c.user.id)) throw new HttpError(409, 'شما قبلاً برای این پرونده پیشنهاد ثبت کرده‌اید؛ همان را ویرایش کنید.');
  const r = await db.prepare("INSERT INTO proposals(case_id,lawyer_id,amount,days,note_enc,status,created_at) VALUES(?,?,?,?,?,'pending',?) RETURNING id")
    .run(cs.id, c.user.id, amount, days, sec.encText(note, 'proposal.note'), now());
  await db.prepare("UPDATE cases SET status='proposing',updated_at=? WHERE id=? AND status='waiting'").run(now(), cs.id);
  await audit(c.user.id, 'proposal_create', 'case:' + cs.id, c.ip);
  return { ok: true, id: r.lastInsertRowid };
});

route('GET', '/api/proposals', ROLE('lawyer'), async (c) => {
  const ps = await db.prepare('SELECT p.*, cs.title AS case_title, cs.status AS case_status FROM proposals p LEFT JOIN cases cs ON cs.id=p.case_id WHERE p.lawyer_id=? ORDER BY p.created_at DESC, p.id DESC LIMIT 100').all(c.user.id);
  return { ok: true, rows: ps.map((p) => ({ id: p.id, case_id: p.case_id, case_title: p.case_title || '', case_status: p.case_status || '', amount: p.amount, days: p.days, status: p.status, created_at: p.created_at })) };
});

async function ownPendingProposal(c) {
  const p = await db.prepare('SELECT p.*, cs.status AS case_status FROM proposals p LEFT JOIN cases cs ON cs.id=p.case_id WHERE p.id=? AND p.lawyer_id=?').get(c.params.id, c.user.id);
  if (!p) throw new HttpError(404, 'پیشنهاد یافت نشد.');
  if (p.status !== 'pending') throw new HttpError(400, 'فقط پیشنهاد «در انتظار» قابل تغییر است.');
  if (p.case_status !== 'waiting' && p.case_status !== 'proposing') throw new HttpError(400, 'این پرونده دیگر در مرحله‌ی پیشنهاد نیست.');
  return p;
}

route('PATCH', '/api/proposals/:id', ROLE('lawyer'), async (c) => {
  const p = await ownPendingProposal(c);
  const amount = int(c.body.amount, 1000, 10 * 1000 * 1000 * 1000, 'مبلغ پیشنهادی');
  const days = int(c.body.days, 1, 3650, 'مدت زمان');
  const note = c.body.note == null ? '' : str(c.body.note, 0, 2000, 'یادداشت');
  await db.prepare('UPDATE proposals SET amount=?,days=?,note_enc=? WHERE id=?').run(amount, days, sec.encText(note, 'proposal.note'), p.id);
  await audit(c.user.id, 'proposal_edit', 'case:' + p.case_id, c.ip);
  return { ok: true };
});

route('DELETE', '/api/proposals/:id', ROLE('lawyer'), async (c) => {
  const p = await ownPendingProposal(c);
  await db.prepare('DELETE FROM proposals WHERE id=?').run(p.id);
  // اگر آخرین پیشنهاد بود، پرونده به «در انتظار بررسی» برمی‌گردد
  await db.prepare("UPDATE cases SET status='waiting',updated_at=? WHERE id=? AND status='proposing' AND NOT EXISTS(SELECT 1 FROM proposals WHERE case_id=?)").run(now(), p.case_id, p.case_id);
  await audit(c.user.id, 'proposal_delete', 'case:' + p.case_id, c.ip);
  return { ok: true };
});

route('POST', '/api/proposals/:id/accept', ROLE('admin'), async (c) => {
  const p = await db.prepare('SELECT p.*, cs.status AS case_status FROM proposals p LEFT JOIN cases cs ON cs.id=p.case_id WHERE p.id=?').get(c.params.id);
  if (!p) throw new HttpError(404, 'پیشنهاد یافت نشد.');
  if (p.status !== 'pending') throw new HttpError(400, 'این پیشنهاد قبلاً تعیین تکلیف شده است.');
  if (p.case_status !== 'waiting' && p.case_status !== 'proposing') throw new HttpError(400, 'این پرونده دیگر در مرحله‌ی پیشنهاد نیست.');
  const n = now();
  await tx(async (t) => { // اتمیک: تایید یکی، رد بقیه، تخصیص وکیل
    await t.sql.unsafe(toPg("UPDATE proposals SET status='accepted' WHERE id=?"), [p.id]);
    await t.sql.unsafe(toPg("UPDATE proposals SET status='rejected' WHERE case_id=? AND id<>? AND status='pending'"), [p.case_id, p.id]);
    await t.sql.unsafe(toPg("UPDATE cases SET lawyer_id=?,final_price=?,status='assigned',updated_at=? WHERE id=?"), [p.lawyer_id, p.amount, n, p.case_id]);
  });
  await audit(c.user.id, 'proposal_accept', 'case:' + p.case_id + ' lawyer:' + p.lawyer_id, c.ip);
  return { ok: true };
});

/* ---------- CMD-004 — فاز ۳ گام ۲: نوبت‌دهی (appointments) ----------
 * تقویم مرجع همان تقویم نمایشی خود پروژه است: ماه «آبان ۱۴۰۵»، روزهای ۱..۳۰، ۵ بازه‌ی ثابت.
 * starts_at = epoch-seconds لحظه‌ی تهران (UTC+03:30 ثابت — ایران از ۱۴۰۱ ساعت تابستانی ندارد).
 * وضعیت‌ها مطابق UI مرجع: booked → confirmed (تایید مدیر) / canceled (لغو مشتری یا رد مدیر).
 * حریم خصوصی: وکیل فقط «مراجعه‌کننده #id» می‌بیند؛ نام مشتری/وکیل فقط برای مدیر می‌آید.
 * تصمیم طراحی (در انتظار تصمیم مدیر): تخصیص وکیل به نوبت و «بازه‌های در دسترس» وکیل نیازمند
 * جدول جدید است (مانند گام CMS) — در این گام انجام نشد؛ در دسترس بودن بازه‌ها از نوبت‌های
 * ثبت‌شده استخراج می‌شود و lawyer_id هنگام رزرو NULL می‌ماند.
 * ========================================================================== */
const BK_MONTH_START = Date.UTC(2026, 9, 23, 0, 0) / 1000 - 12600; /* ۱۴۰۵/۰۸/۰۱ ۰۰:۰۰ تهران */
const BK_SLOTS = { '۰۹:۰۰': 540, '۱۰:۳۰': 630, '۱۲:۰۰': 720, '۱۶:۰۰': 960, '۱۷:۳۰': 1050 };
const BK_KINDS = ['حضوری', 'آنلاین', 'تلفنی'];
const bkDayOf = (t) => Math.floor((t - BK_MONTH_START) / 86400) + 1;
const bkSlotLabel = (t) => { const m = (t - BK_MONTH_START) % 86400 / 60; for (const k in BK_SLOTS) if (BK_SLOTS[k] === m) return k; return ''; };

route('GET', '/api/appointments', isAuth, async (c) => {
  const role = c.user.role, n = now();
  const SEL = 'SELECT a.*, cl.name AS client_name, lw.name AS lawyer_name FROM appointments a LEFT JOIN users cl ON cl.id=a.client_id LEFT JOIN users lw ON lw.id=a.lawyer_id';
  let rows;
  if (role === 'client') rows = await db.prepare(SEL + " WHERE a.client_id=? AND a.status<>'canceled' ORDER BY a.starts_at ASC, a.id ASC LIMIT 100").all(c.user.id);
  else if (role === 'lawyer') rows = await db.prepare(SEL + " WHERE a.status<>'canceled' ORDER BY a.starts_at ASC, a.id ASC LIMIT 300").all();
  else rows = await db.prepare(SEL + ' ORDER BY a.starts_at ASC, a.id ASC LIMIT 300').all();
  /* taken = بازه‌های اشغال‌شدهٔ ماه جاری (برای غیرفعال‌سازی اسلات‌ها و علامت «پر» در تقویم) */
  const tks = await db.prepare("SELECT DISTINCT starts_at FROM appointments WHERE status<>'canceled' AND starts_at>=? ORDER BY starts_at ASC LIMIT 400").all(BK_MONTH_START);
  return {
    ok: true, now: n, today_d: Math.min(31, Math.max(1, bkDayOf(n))),
    rows: rows.map((r) => {
      const o = { id: r.id, starts_at: r.starts_at, day: bkDayOf(r.starts_at), slot: bkSlotLabel(r.starts_at), kind: r.kind, status: r.status, created_at: r.created_at };
      if (role !== 'client') o.client_id = r.client_id;
      if (role === 'admin') { o.client_name = r.client_name || ''; o.lawyer_name = r.lawyer_name || ''; }
      return o;
    }),
    taken: tks.map((r) => ({ d: bkDayOf(r.starts_at), j: bkSlotLabel(r.starts_at) })).filter((x) => x.j)
  };
});

route('POST', '/api/appointments', ROLE('client'), async (c) => {
  if (!(await rl('book:' + c.user.id, 5, 3600e3))) throw new HttpError(429, 'سقف رزرو نوبت در یک ساعت تکمیل شده است. بعداً تلاش کنید.');
  const day = int(c.body.day, 1, 30, 'روز');
  const slot = oneOf(str(c.body.slot, 4, 5, 'ساعت'), Object.keys(BK_SLOTS), 'ساعت');
  const kind = oneOf(c.body.kind, BK_KINDS, 'نوع ملاقات');
  const starts = BK_MONTH_START + (day - 1) * 86400 + BK_SLOTS[slot] * 60;
  const n = now();
  if (starts <= n) throw new HttpError(400, 'این زمان گذشته است؛ روز یا ساعت دیگری انتخاب کنید.');
  if (await db.prepare("SELECT 1 FROM appointments WHERE starts_at=? AND status<>'canceled'").get(starts)) throw new HttpError(409, 'این بازه قبلاً رزرو شده است؛ بازه‌ی دیگری انتخاب کنید.');
  const r = await db.prepare("INSERT INTO appointments(client_id,lawyer_id,starts_at,kind,status,created_at) VALUES(?,NULL,?,?,'booked',?) RETURNING id").run(c.user.id, starts, kind, n);
  await audit(c.user.id, 'appointment_create', 'appt:' + r.lastInsertRowid, c.ip);
  return { ok: true, id: r.lastInsertRowid };
});

route('PATCH', '/api/appointments/:id', isAuth, async (c) => {
  const st = oneOf(c.body.status, ['canceled', 'confirmed'], 'وضعیت');
  const a = await db.prepare('SELECT * FROM appointments WHERE id=?').get(c.params.id);
  if (!a) throw new HttpError(404, 'نوبت یافت نشد.');
  if (c.user.role === 'client') {
    if (a.client_id !== c.user.id) throw new HttpError(404, 'نوبت یافت نشد.'); // بدون افشای وجود نوبت دیگران
    if (st !== 'canceled') throw new HttpError(403, 'دسترسی ندارید.');
    if (a.status === 'canceled') throw new HttpError(400, 'این نوبت قبلاً لغو شده است.');
    if (a.starts_at <= now()) throw new HttpError(400, 'زمان این نوبت گذشته است؛ امکان لغو نیست.');
  } else if (c.user.role === 'admin') {
    if (a.status === 'canceled') throw new HttpError(400, 'این نوبت قبلاً لغو/رد شده است.');
    if (st === 'confirmed' && a.status !== 'booked') throw new HttpError(400, 'فقط نوبت «رزرو‌شده» قابل تایید است.');
  } else throw new HttpError(403, 'دسترسی ندارید.');
  await db.prepare('UPDATE appointments SET status=? WHERE id=?').run(st, a.id);
  await audit(c.user.id, st === 'canceled' ? 'appointment_cancel' : 'appointment_confirm', 'appt:' + a.id, c.ip);
  return { ok: true };
});

/* ---------- API dispatcher (identical flow) ---------- */
async function api(req, res, url, ip) {
  baseHeaders(res);
  try {
    if (!(await rl('ip:' + ip, 300, 60000))) throw new HttpError(429, 'تعداد درخواست‌ها زیاد است.');
    const m = req.method;
    if (m !== 'GET' && m !== 'HEAD') { // CSRF layer 1: Origin / Fetch-Metadata
      const o = req.headers.origin;
      if (o) { let ok = false; try { ok = new URL(o).host === req.headers.host; } catch { } if (!ok) throw new HttpError(403, 'درخواست نامعتبر است.'); }
      else if (req.headers['sec-fetch-site'] === 'cross-site') throw new HttpError(403, 'درخواست نامعتبر است.');
    }
    let r = null, params = {};
    for (const x of routes) { if (x.method !== m) continue; const mm = url.pathname.match(x.re); if (mm) { r = x; params = Object.fromEntries(x.keys.map((k, i) => [k, +mm[i + 1]])); break; } }
    if (!r) throw new HttpError(routes.some((x) => x.re.test(url.pathname)) ? 405 : 404, 'یافت نشد.');
    const sess = await getSession(req), user = sess && sess.user;
    if (r.opts.auth) {
      if (!user) throw new HttpError(401, 'ابتدا وارد شوید.');
      if (r.opts.roles && !r.opts.roles.includes(user.role)) { await audit(user.id, 'forbidden', url.pathname, ip); throw new HttpError(403, 'دسترسی ندارید.'); }
      if (user.must_change && !r.opts.allowMust) throw new HttpError(403, 'must_change_password');
      if (m !== 'GET' && !sec.safeEq(req.headers['x-csrf-token'] || '', sess.csrf)) throw new HttpError(403, 'درخواست نامعتبر است (CSRF).');
    }
    let body = {};
    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(m) && !r.opts.raw) {
      const b = await readBody(req, 100 * 1024);
      if (b.length) {
        if (!/^application\/json/i.test(req.headers['content-type'] || '')) throw new HttpError(415, 'نوع محتوا پشتیبانی نمی‌شود.');
        try { body = JSON.parse(b.toString('utf8')); } catch { throw new HttpError(400, 'داده‌ی ارسالی نامعتبر است.'); }
        if (!body || typeof body !== 'object' || Array.isArray(body)) throw new HttpError(400, 'داده‌ی ارسالی نامعتبر است.');
      }
    }
    const out = await r.fn({ req, res, user, sess, ip, params, body, query: Object.fromEntries(url.searchParams) });
    if (out !== undefined && !res.headersSent) json(res, 200, out);
  } catch (e) {
    if (res.headersSent) return;
    if (e instanceof HttpError) return json(res, e.s, { error: e.message }, e.s === 413 ? { Connection: 'close' } : undefined);
    console.error('[error]', e); json(res, 500, { error: 'خطای داخلی سرور.' });
  }
}

/* ---------- static files (strict CSP with per-request nonce — identical) ---------- */
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.woff2': 'font/woff2', '.json': 'application/json', '.txt': 'text/plain; charset=utf-8' };
function serveStatic(req, res, p) {
  baseHeaders(res);
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); return res.end(); }
  let rel; try { rel = decodeURIComponent(p); } catch { res.writeHead(400); return res.end(); }
  if (rel.includes('\0') || rel.includes('\\') || rel.split('/').some((s) => s === '..' || (s.startsWith('.') && s.length > 0))) { res.writeHead(404); return res.end('Not found'); }
  if (rel === '/' || rel === '') rel = '/index.html';
  const file = path.join(PUB, rel);
  const ext = path.extname(file).toLowerCase();
  if (!file.startsWith(PUB + path.sep) || !MIME[ext]) { res.writeHead(404); return res.end('Not found'); }
  let st; try { st = fs.statSync(file); } catch { res.writeHead(404); return res.end('Not found'); }
  if (!st.isFile()) { res.writeHead(404); return res.end('Not found'); }
  if (ext === '.html') {
    const nonce = crypto.randomBytes(16).toString('base64');
    const html = fs.readFileSync(file, 'utf8').replace(/<(script|style)(\s|>)/g, `<$1 nonce="${nonce}"$2`);
    res.writeHead(200, {
      'Content-Type': MIME[ext], 'Cache-Control': 'no-cache',
      'Content-Security-Policy': `default-src 'self'; script-src 'self' 'nonce-${nonce}'; style-src 'self' 'nonce-${nonce}' https://fonts.googleapis.com; style-src-attr 'unsafe-inline'; font-src https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'; object-src 'none'`
    });
    return res.end(req.method === 'HEAD' ? undefined : html);
  }
  res.writeHead(200, { 'Content-Type': MIME[ext], 'Content-Length': st.size, 'Cache-Control': 'public, max-age=3600' });
  if (req.method === 'HEAD') return res.end();
  fs.createReadStream(file).pipe(res);
}

/* ---------- entries ---------- */
async function handle(req, res) {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname.startsWith('/api/')) return api(req, res, url, ipOf(req));
  return serveStatic(req, res, url.pathname);
}
/* ورودی API برای تابع سرورلس (فقط از مسیر /api/* صدا زده می‌شود) */
async function apiEntry(req, res) {
  const url = new URL(req.url, 'http://localhost');
  return api(req, res, url, ipOf(req));
}
/* ورودی HTML: فقط «/» به این تابع ریرایت می‌شود؛ بقیه به notFoundEntry */
function htmlEntry(req, res) { return serveStatic(req, res, '/'); }
function notFoundEntry(req, res) { return serveStatic(req, res, '/__notfound__'); }

/* start فقط برای اجرای محلی (هارنس تست) استفاده می‌شود — روی Vercel استفاده نمی‌شود */
function start(port = cfg.port, host = cfg.host) {
  const http = require('http');
  const s = http.createServer((req, res) => { handle(req, res).catch((e) => { console.error(e); try { json(res, 500, { error: 'خطا' }); } catch { } }); });
  s.headersTimeout = 15e3; s.requestTimeout = 60e3; s.keepAliveTimeout = 5e3;
  return new Promise((r) => s.listen(port, host, () => r(s)));
}

module.exports = { start, handle, apiEntry, htmlEntry, notFoundEntry, routes, route, HttpError, str, int, oneOf, normPhone, CATS, ascii };
