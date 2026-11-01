'use strict';
const http = require('http'), fs = require('fs'), path = require('path'), crypto = require('crypto');
const cfg = require('./lib/config'), sec = require('./lib/security'), { db, now, audit, tx } = require('./lib/db'), sendSms = require('./lib/sms');
const PUB = path.join(__dirname, 'public');
const COOKIE = cfg.cookieSecure ? '__Host-sid' : 'sid';
class HttpError extends Error { constructor(s, m) { super(m); this.s = s; } }

/* ---------- small utilities ---------- */
const DIG = { '۰': 0, '۱': 1, '۲': 2, '۳': 3, '۴': 4, '۵': 5, '۶': 6, '۷': 7, '۸': 8, '۹': 9, '٠': 0, '١': 1, '٢': 2, '٣': 3, '٤': 4, '٥': 5, '٦': 6, '٧': 7, '٨': 8, '٩': 9 };
const ascii = (s) => String(s).replace(/[۰-۹٠-٩]/g, (d) => DIG[d]);
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

/* ---------- in-memory rate limiter ---------- */
const buckets = new Map();
function rl(key, max, ms) {
  const t = Date.now(); let a = buckets.get(key);
  if (!a) buckets.set(key, a = []);
  while (a.length && t - a[0] > ms) a.shift();
  if (a.length >= max) return false;
  a.push(t); return true;
}
setInterval(() => {
  const t = Date.now(); for (const [k, a] of buckets) if (!a.length || t - a[a.length - 1] > 3600e3) buckets.delete(k);
  const n = now();
  db.prepare('DELETE FROM sessions WHERE expires_at<?').run(n);
  db.prepare('DELETE FROM otp WHERE created_at<?').run(n - 86400);
  db.prepare('DELETE FROM login_attempts WHERE locked_until<? AND first_at<?').run(n, n - 3600);
}, 600e3).unref();

/* ---------- http helpers ---------- */
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
function startSession(res, user, req, ip) {
  const n = now(), t = sec.token(), csrf = sec.token();
  db.prepare('DELETE FROM sessions WHERE id IN (SELECT id FROM sessions WHERE user_id=? ORDER BY created_at DESC LIMIT -1 OFFSET 4)').run(user.id);
  db.prepare('INSERT INTO sessions(id,user_id,csrf,created_at,last_seen,expires_at,ip,ua) VALUES(?,?,?,?,?,?,?,?)').run(sec.sha(t), user.id, csrf, n, n, n + cfg.sessionMaxMs / 1000, ip, String(req.headers['user-agent'] || '').slice(0, 200));
  db.prepare('UPDATE users SET last_login=? WHERE id=?').run(n, user.id);
  setCookie(res, t, cfg.sessionMaxMs / 1000);
  return csrf;
}
function getSession(req) {
  const t = parseCookies(req.headers.cookie || '')[COOKIE];
  if (!t || t.length > 100) return null;
  const id = sec.sha(t), s = db.prepare('SELECT * FROM sessions WHERE id=?').get(id);
  if (!s) return null;
  const n = now();
  if (s.expires_at < n || n - s.last_seen > cfg.sessionIdleMs / 1000) { db.prepare('DELETE FROM sessions WHERE id=?').run(id); return null; }
  const user = db.prepare('SELECT * FROM users WHERE id=?').get(s.user_id);
  if (!user || user.status !== 'active') return null;
  if (n - s.last_seen > 60) db.prepare('UPDATE sessions SET last_seen=? WHERE id=?').run(n, id);
  return { id, csrf: s.csrf, user };
}

/* ---------- login throttling (persistent) ---------- */
const locked = (k) => { const r = db.prepare('SELECT locked_until FROM login_attempts WHERE key=?').get(k); return !!(r && r.locked_until > now()); };
function fail(k, limit) {
  const n = now(), r = db.prepare('SELECT * FROM login_attempts WHERE key=?').get(k);
  let count = 1, first = n; if (r && n - r.first_at < 900) { count = r.count + 1; first = r.first_at; }
  const lock = count >= limit ? n + Math.min(3600, 60 * 2 ** Math.min(count - limit, 6)) : 0;
  db.prepare('INSERT INTO login_attempts(key,count,first_at,locked_until) VALUES(?,?,?,?) ON CONFLICT(key) DO UPDATE SET count=?,first_at=?,locked_until=?').run(k, count, first, lock, count, first, lock);
}
const clearFail = (k) => db.prepare('DELETE FROM login_attempts WHERE key=?').run(k);

/* ---------- routing ---------- */
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
  if (!rl('login:' + c.ip, +process.env.LOGIN_RL_MAX || 30, 600e3)) throw new HttpError(429, 'تعداد درخواست‌ها زیاد است. کمی بعد دوباره تلاش کنید.');
  let username = str(c.body.username, 1, 64, 'نام کاربری').toLowerCase(); const password = str(c.body.password, 1, 200, 'رمز عبور', false);
  let byPhone = null;
  if (/^[0-9۰-۹٠-٩+\s-]{10,16}$/.test(username)) { try { byPhone = normPhone(username); username = byPhone; } catch { } } // phone number can be used as username
  const ku = 'u:' + username, ki = 'i:' + c.ip;
  if (locked(ku) || locked(ki)) { audit(null, 'login_locked', username, c.ip); throw new HttpError(429, 'تلاش‌های ناموفق زیاد بود. چند دقیقه بعد دوباره تلاش کنید.'); }
  const u = byPhone ? db.prepare('SELECT * FROM users WHERE phone_hash=? AND password_hash IS NOT NULL').get(sec.hmac('phone:' + byPhone)) : db.prepare('SELECT * FROM users WHERE username=? AND password_hash IS NOT NULL').get(username);
  let ok = false;
  if (u) ok = await sec.verifyPassword(password, u.password_hash); else await sec.dummyVerify(password);
  if (!ok || u.status !== 'active') { fail(ku, 5); fail(ki, 25); audit(u && u.id, 'login_fail', username, c.ip); throw new HttpError(401, 'نام کاربری یا رمز عبور اشتباه است.'); }
  clearFail(ku);
  const csrf = startSession(c.res, u, c.req, c.ip);
  audit(u.id, 'login', 'password', c.ip);
  return { user: pub(u), csrf };
});

route('POST', '/api/auth/logout', { auth: true, allowMust: true }, async (c) => {
  db.prepare('DELETE FROM sessions WHERE id=?').run(c.sess.id);
  setCookie(c.res, '', 0); audit(c.user.id, 'logout', null, c.ip);
  return { ok: true };
});

route('GET', '/api/me', {}, async (c) => {
  if (!c.user) return { user: null, csrf: '' }; // guests get 200 so the browser console stays clean
  return { user: pub(c.user), csrf: c.sess.csrf };
});

route('PATCH', '/api/me', isAuth, async (c) => {
  const name = str(c.body.name, 2, 60, 'نام'); const email = c.body.email ? str(c.body.email, 5, 120, 'ایمیل') : '';
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError(400, 'ایمیل معتبر نیست.');
  db.prepare('UPDATE users SET name=?,email=? WHERE id=?').run(name, email || null, c.user.id);
  audit(c.user.id, 'profile_update', null, c.ip);
  return { ok: true };
});

route('POST', '/api/me/password', { auth: true, allowMust: true }, async (c) => {
  if (!rl('pw:' + c.user.id, 8, 600e3)) throw new HttpError(429, 'تعداد تلاش‌ها زیاد است.');
  const cur = str(c.body.current, 1, 200, 'رمز فعلی', false), next = str(c.body.next, 1, 200, 'رمز جدید', false);
  if (!(await sec.verifyPassword(cur, c.user.password_hash))) { audit(c.user.id, 'password_change_fail', null, c.ip); throw new HttpError(400, 'رمز فعلی اشتباه است.'); }
  const p = sec.passwordProblem(next, c.user.username); if (p) throw new HttpError(400, p);
  if (next === cur) throw new HttpError(400, 'رمز جدید باید با رمز فعلی متفاوت باشد.');
  db.prepare('UPDATE users SET password_hash=?,must_change=0 WHERE id=?').run(await sec.hashPassword(next), c.user.id);
  db.prepare('DELETE FROM sessions WHERE user_id=? AND id<>?').run(c.user.id, c.sess.id);
  audit(c.user.id, 'password_change', null, c.ip);
  return { ok: true };
});

/* ---------- phone / OTP ---------- */
async function issueOtp(phone, ip) {
  const ph = sec.hmac('phone:' + phone), n = now();
  if (!rl('otpip:' + ip, 10, 600e3)) throw new HttpError(429, 'تعداد درخواست‌ها زیاد است. بعداً تلاش کنید.');
  const last = db.prepare('SELECT created_at FROM otp WHERE phone_hash=? ORDER BY id DESC LIMIT 1').get(ph);
  if (last && n - last.created_at < 60) throw new HttpError(429, 'برای دریافت کد جدید ' + (60 - (n - last.created_at)) + ' ثانیه صبر کنید.');
  if (db.prepare('SELECT COUNT(*) c FROM otp WHERE phone_hash=? AND created_at>?').get(ph, n - 3600).c >= 5) throw new HttpError(429, 'سقف درخواست کد برای این شماره تکمیل شده است. بعداً تلاش کنید.');
  const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  db.prepare('INSERT INTO otp(phone_hash,code_hash,expires_at,created_at,ip) VALUES(?,?,?,?,?)').run(ph, sec.hmac(ph + ':' + code), n + 120, n, ip);
  try { await sendSms(phone, 'کد ورود موسسه حقوقی دادگر: ' + code + '\nاین کد را به هیچ‌کس نگویید.'); } catch (e) { console.error('[sms]', e.message); }
  return code;
}
route('POST', '/api/auth/otp/request', {}, async (c) => {
  const phone = normPhone(c.body.phone), code = await issueOtp(phone, c.ip);
  audit(null, 'otp_request', phone.slice(-4), c.ip);
  return Object.assign({ ok: true, expiresIn: 120 }, cfg.showOtp ? { devCode: code } : {});
});
route('POST', '/api/auth/otp/verify', {}, async (c) => {
  const phone = normPhone(c.body.phone), code = ascii(str(c.body.code, 4, 10, 'کد'));
  if (!/^\d{6}$/.test(code)) throw new HttpError(400, 'کد باید ۶ رقم باشد.');
  if (!rl('otpv:' + c.ip, 20, 600e3)) throw new HttpError(429, 'تعداد تلاش‌ها زیاد است.');
  const ph = sec.hmac('phone:' + phone), n = now();
  const row = db.prepare('SELECT * FROM otp WHERE phone_hash=? AND used=0 AND expires_at>? ORDER BY id DESC LIMIT 1').get(ph, n);
  const bad = new HttpError(400, 'کد نامعتبر یا منقضی شده است.');
  if (!row || row.attempts >= 5) throw bad;
  if (!sec.safeEq(row.code_hash, sec.hmac(ph + ':' + code))) { db.prepare('UPDATE otp SET attempts=attempts+1 WHERE id=?').run(row.id); audit(null, 'otp_fail', phone.slice(-4), c.ip); throw bad; }
  db.prepare('UPDATE otp SET used=1 WHERE id=?').run(row.id);
  let u = db.prepare('SELECT * FROM users WHERE phone_hash=?').get(ph);
  if (!u) {
    const r = db.prepare("INSERT INTO users(role,name,phone_hash,phone_last4,phone_enc,status,created_at) VALUES('client',?,?,?,?,'active',?)").run('کاربر ' + phone.slice(-4), ph, phone.slice(-4), sec.encText(phone, 'user.phone'), n);
    u = db.prepare('SELECT * FROM users WHERE id=?').get(r.lastInsertRowid); audit(u.id, 'register_phone', null, c.ip);
  } else if (u.status === 'pending') { db.prepare("UPDATE users SET status='active' WHERE id=?").run(u.id); u.status = 'active'; }
  if (u.status !== 'active') throw new HttpError(403, 'دسترسی این حساب مسدود است.');
  if (u.role === 'admin') throw new HttpError(403, 'ورود مدیر فقط با نام کاربری و رمز عبور ممکن است.');
  const csrf = startSession(c.res, u, c.req, c.ip); audit(u.id, 'login', 'otp', c.ip);
  return { user: pub(u), csrf };
});
route('POST', '/api/auth/register', {}, async (c) => {
  const name = str(c.body.name, 2, 60, 'نام'), phone = normPhone(c.body.phone), pw = str(c.body.password, 1, 200, 'رمز عبور', false);
  const p = sec.passwordProblem(pw, phone); if (p) throw new HttpError(400, p);
  const ph = sec.hmac('phone:' + phone);
  const hash = await sec.hashPassword(pw);
  if (!db.prepare('SELECT 1 FROM users WHERE phone_hash=?').get(ph))
    db.prepare("INSERT INTO users(role,name,phone_hash,phone_last4,phone_enc,password_hash,status,created_at) VALUES('client',?,?,?,?,?,'pending',?)").run(name, ph, phone.slice(-4), sec.encText(phone, 'user.phone'), hash, now());
  const code = await issueOtp(phone, c.ip); audit(null, 'register_request', phone.slice(-4), c.ip);
  return Object.assign({ ok: true, expiresIn: 120 }, cfg.showOtp ? { devCode: code } : {}); // same answer whether or not the phone existed
});

/* ---------- API dispatcher ---------- */
async function api(req, res, url, ip) {
  baseHeaders(res);
  try {
    if (!rl('ip:' + ip, 300, 60000)) throw new HttpError(429, 'تعداد درخواست‌ها زیاد است.');
    const m = req.method;
    if (m !== 'GET' && m !== 'HEAD') { // CSRF layer 1: Origin / Fetch-Metadata
      const o = req.headers.origin;
      if (o) { let ok = false; try { ok = new URL(o).host === req.headers.host; } catch { } if (!ok) throw new HttpError(403, 'درخواست نامعتبر است.'); }
      else if (req.headers['sec-fetch-site'] === 'cross-site') throw new HttpError(403, 'درخواست نامعتبر است.');
    }
    let r = null, params = {};
    for (const x of routes) { if (x.method !== m) continue; const mm = url.pathname.match(x.re); if (mm) { r = x; params = Object.fromEntries(x.keys.map((k, i) => [k, +mm[i + 1]])); break; } }
    if (!r) throw new HttpError(routes.some((x) => x.re.test(url.pathname)) ? 405 : 404, 'یافت نشد.');
    const sess = getSession(req), user = sess && sess.user;
    if (r.opts.auth) {
      if (!user) throw new HttpError(401, 'ابتدا وارد شوید.');
      if (r.opts.roles && !r.opts.roles.includes(user.role)) { audit(user.id, 'forbidden', url.pathname, ip); throw new HttpError(403, 'دسترسی ندارید.'); }
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

/* ---------- static files (strict CSP with per-request nonce) ---------- */
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

async function handle(req, res) {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname.startsWith('/api/')) return api(req, res, url, ipOf(req));
  return serveStatic(req, res, url.pathname);
}
function start(port = cfg.port, host = cfg.host) {
  const s = http.createServer((req, res) => { handle(req, res).catch((e) => { console.error(e); try { json(res, 500, { error: 'خطا' }); } catch { } }); });
  s.headersTimeout = 15e3; s.requestTimeout = 60e3; s.keepAliveTimeout = 5e3;
  return new Promise((r) => s.listen(port, host, () => r(s)));
}
if (require.main === module) {
  start().then((s) => {
    console.log('Dadgar server listening on', s.address().address + ':' + s.address().port, cfg.prod ? '(production)' : '(development)');
    for (const sg of ['SIGTERM', 'SIGINT']) process.on(sg, () => s.close(() => process.exit(0)));
  });
}
module.exports = { start, routes, route, HttpError, str, int, oneOf, normPhone, CATS, ascii };
