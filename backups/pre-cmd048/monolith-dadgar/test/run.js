'use strict';
process.env.NODE_ENV = 'test'; process.env.DEV_SHOW_OTP = '1'; process.env.LOGIN_RL_MAX = '500';
const os = require('os'), fs = require('fs'), path = require('path'), http = require('http');
process.env.DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'dadgar-'));
const { start } = require('../server'), { seed } = require('../scripts/seed-demo'), { db } = require('../lib/db'), sec = require('../lib/security');
let pass = 0, failN = 0;
const ok = (c, m) => { if (c) pass++; else { failN++; console.log('  FAIL:', m); } };
const section = (t) => console.log('• ' + t);
(async () => {
  await seed();
  const srv = await start(0, '127.0.0.1'), port = srv.address().port, base = 'http://127.0.0.1:' + port;
  function client() {
    const jar = {};
    return { csrf: '', jar, async req(method, p, body, extra) {
      const h = Object.assign({ 'content-type': 'application/json' }, extra || {});
      const ck = Object.entries(jar).map(([k, v]) => k + '=' + v).join('; '); if (ck) h.cookie = ck;
      if (this.csrf && method !== 'GET' && !(extra && extra.nocsrf)) h['x-csrf-token'] = this.csrf;
      delete h.nocsrf;
      const r = await fetch(base + p, { method, headers: h, body: body === undefined ? undefined : (typeof body === 'string' ? body : JSON.stringify(body)) });
      const sc = r.headers.getSetCookie(); for (const c of sc) { const kv = c.split(';')[0], i = kv.indexOf('='), k = kv.slice(0, i), v = kv.slice(i + 1); if (v) jar[k] = v; else delete jar[k]; }
      let j = null; try { j = await r.json(); } catch { } return { s: r.status, j, h: r.headers, sc };
    } };
  }
  const login = async (u, p) => { const c = client(); const r = await c.req('POST', '/api/auth/login', { username: u, password: p }); if (r.j && r.j.csrf) c.csrf = r.j.csrf; return { c, r }; };
  const raw = (p) => new Promise((res) => http.get({ host: '127.0.0.1', port, path: p }, (r) => { r.resume(); res(r.statusCode); }));

  section('headers, static files and path traversal');
  const home = await fetch(base + '/'); const html = await home.text(), csp = home.headers.get('content-security-policy') || '';
  const nonce = (csp.match(/nonce-([^']+)/) || [])[1];
  ok(home.status === 200 && nonce && html.includes('nonce="' + nonce + '"'), 'CSP nonce is injected into inline tags');
  ok(csp.includes("default-src 'self'") && csp.includes("frame-ancestors 'none'") && !/script-src[^;]*unsafe-inline/.test(csp), 'CSP has no unsafe-inline for scripts');
  ok(home.headers.get('x-frame-options') === 'DENY' && home.headers.get('x-content-type-options') === 'nosniff', 'security headers set');
  const h = await client().req('GET', '/api/health'); ok(h.s === 200 && h.j.ok && /no-store/.test(h.h.get('cache-control')), 'health + no-store on API');
  for (const p of ['/%2e%2e/server.js', '/..%2fserver.js', '/.env', '/data/dadgar.sqlite', '/lib/db.js', '/package.json', '/%2e%2e%2f%2e%2e%2fetc/passwd'])
    ok((await raw(p)) === 404, 'blocked path ' + p);

  section('password login, lockout, enumeration, injection');
  const a = await client().req('POST', '/api/auth/login', { username: 'lawyer', password: 'wrong-password' });
  const b = await client().req('POST', '/api/auth/login', { username: 'nobody-here', password: 'wrong-password' });
  ok(a.s === 401 && b.s === 401 && a.j.error === b.j.error, 'same generic error for wrong password and unknown user');
  const sq = await client().req('POST', '/api/auth/login', { username: "' OR '1'='1", password: "x' OR '1'='1" }); ok(sq.s === 401, 'SQL injection attempt rejected cleanly');
  const bad = await client().req('POST', '/api/auth/login', 'not json'); ok(bad.s === 415 || bad.s === 400, 'non-JSON body rejected (' + bad.s + ')');
  const big = await client().req('POST', '/api/auth/login', JSON.stringify({ username: 'a', password: 'x'.repeat(200000) })); ok(big.s === 413, 'oversized body rejected (' + big.s + ')');
  for (let i = 0; i < 5; i++) await client().req('POST', '/api/auth/login', { username: 'lawyer4', password: 'bad' + i });
  const locked = await client().req('POST', '/api/auth/login', { username: 'lawyer4', password: 'Lawyer#2026' });
  ok(locked.s === 429, 'account locks after 5 failures even with the right password');
  const okl = await login('admin', 'Admin#2026');
  ok(okl.r.s === 200 && okl.r.j.user.role === 'admin' && okl.r.j.csrf, 'admin can log in');
  const ck = okl.r.sc.join(' '); ok(/HttpOnly/i.test(ck) && /SameSite=Strict/i.test(ck), 'session cookie is HttpOnly + SameSite=Strict');
  ok(okl.r.j.user.mustChange === true, 'seeded account must change its password');

  section('forced password change, CSRF, origin check, session invalidation');
  const A = await login('client', 'Client#2026');
  const g1 = await A.c.req('PATCH', '/api/me', { name: 'x y' }); ok(g1.s === 403 && g1.j.error === 'must_change_password', 'API is blocked until the password is changed');
  const nocsrf = await A.c.req('POST', '/api/me/password', { current: 'Client#2026', next: 'New#Passw0rd22' }, { nocsrf: 1 }); ok(nocsrf.s === 403, 'POST without CSRF token rejected');
  const evil = await A.c.req('POST', '/api/me/password', { current: 'Client#2026', next: 'New#Passw0rd22' }, { origin: 'http://evil.example' }); ok(evil.s === 403, 'cross-origin POST rejected');
  ok((await A.c.req('POST', '/api/me/password', { current: 'wrong', next: 'New#Passw0rd22' })).s === 400, 'wrong current password rejected');
  ok((await A.c.req('POST', '/api/me/password', { current: 'Client#2026', next: 'short1' })).s === 400, 'weak password rejected');
  ok((await A.c.req('POST', '/api/me/password', { current: 'Client#2026', next: 'client-abcdefghij' })).s === 400, 'password without digit rejected');
  ok((await A.c.req('POST', '/api/me/password', { current: 'Client#2026', next: 'New#Passw0rd22' })).s === 200, 'strong password accepted');
  ok((await A.c.req('PATCH', '/api/me', { name: 'مریم رضایی' })).s === 200, 'API works after the password change');
  const B = await login('client', 'New#Passw0rd22'); ok(B.r.s === 200 && B.r.j.user.mustChange === false, 'login with the new password');
  ok((await client().req('POST', '/api/auth/login', { username: 'client', password: 'Client#2026' })).s === 401, 'old password no longer works');
  ok((await B.c.req('POST', '/api/me/password', { current: 'New#Passw0rd22', next: 'Another#Pass33x' })).s === 200, 'second password change');
  const oldMe = await A.c.req('GET', '/api/me'); ok(oldMe.s === 200 && oldMe.j.user === null, 'other sessions are invalidated after a password change');
  const lo = await B.c.req('POST', '/api/auth/logout'); const afterLo = await B.c.req('GET', '/api/me'); ok(lo.s === 200 && afterLo.j.user === null, 'logout kills the session');
  const t1 = (await login('admin', 'Admin#2026')).c.jar, t2 = (await login('admin', 'Admin#2026')).c.jar; ok(Object.values(t1)[0] !== Object.values(t2)[0], 'every login issues a fresh session token');

  section('stored data is hashed / encrypted');
  const u = db.prepare("SELECT * FROM users WHERE username='client'").get();
  ok(u.password_hash.startsWith('scrypt$32768$8$1$') && !u.password_hash.includes('Passw0rd') && !u.password_hash.includes('Pass33'), 'password stored as salted scrypt hash');
  ok(u.phone_hash && !u.phone_hash.includes('09120000001') && u.phone_enc.startsWith('v1.') && !u.phone_enc.includes('0912'), 'phone stored as HMAC + AES-GCM, not plaintext');
  ok(sec.decText(u.phone_enc, 'user.phone') === '09120000001' && sec.decText(u.phone_enc, 'wrong.aad') === '', 'field encryption round-trips and is bound to its context (AAD)');
  const sess = db.prepare('SELECT id FROM sessions LIMIT 1').get(); ok(!sess || sess.id.length === 64, 'session ids are stored hashed (sha-256)');

  section('phone login with SMS code (dev driver)');
  const ph1 = '۰۹۱۳۰۰۰۰۰۰۱', cA = client();
  const r1 = await cA.req('POST', '/api/auth/otp/request', { phone: ph1 }); ok(r1.s === 200 && /^\d{6}$/.test(r1.j.devCode), 'OTP issued (Persian digits accepted)');
  ok((await cA.req('POST', '/api/auth/otp/request', { phone: '09130000001' })).s === 429, 'resend cooldown enforced');
  ok(!JSON.stringify(db.prepare('SELECT * FROM otp').all()).includes(r1.j.devCode), 'OTP stored only as HMAC');
  const wrong = r1.j.devCode === '000000' ? '111111' : '000000';
  for (let i = 0; i < 5; i++) await cA.req('POST', '/api/auth/otp/verify', { phone: '09130000001', code: wrong });
  ok((await cA.req('POST', '/api/auth/otp/verify', { phone: '09130000001', code: r1.j.devCode })).s === 400, 'code dies after 5 wrong attempts');
  const cB = client(), r2 = await cB.req('POST', '/api/auth/otp/request', { phone: '09130000002' });
  const v2 = await cB.req('POST', '/api/auth/otp/verify', { phone: '09130000002', code: r2.j.devCode });
  ok(v2.s === 200 && v2.j.user.role === 'client' && v2.j.user.phone.endsWith('0002'), 'phone login creates a client account and a session');
  ok((await cB.req('POST', '/api/auth/otp/verify', { phone: '09130000002', code: r2.j.devCode })).s === 400, 'a code cannot be reused');
  db.prepare('UPDATE users SET phone_hash=? WHERE username=?').run(sec.hmac('phone:09140000000'), 'admin');
  const cC = client(), r3 = await cC.req('POST', '/api/auth/otp/request', { phone: '09140000000' });
  ok((await cC.req('POST', '/api/auth/otp/verify', { phone: '09140000000', code: r3.j.devCode })).s === 403, 'admin cannot log in by SMS code');
  ok((await client().req('POST', '/api/auth/otp/request', { phone: '12345' })).s === 400, 'invalid phone rejected');

  section('registration with phone + password');
  const cD = client();
  ok((await cD.req('POST', '/api/auth/register', { name: 'علی', phone: '09150000003', password: 'weak' })).s === 400, 'weak password rejected at registration');
  const rg = await cD.req('POST', '/api/auth/register', { name: 'علی کریمی', phone: '09150000003', password: 'Strong#Pass99' }); ok(rg.s === 200, 'registration accepted');
  ok((await client().req('POST', '/api/auth/login', { username: '09150000003', password: 'Strong#Pass99' })).s === 401, 'cannot log in before the phone is verified');
  const vg = await cD.req('POST', '/api/auth/otp/verify', { phone: '09150000003', code: rg.j.devCode }); ok(vg.s === 200, 'phone verification activates the account');
  ok((await login('09150000003', 'Strong#Pass99')).r.s === 200, 'password login by phone number works after activation');
  const dup = await client().req('POST', '/api/auth/register', { name: 'x y', phone: '09120000001', password: 'Strong#Pass99' }); ok(dup.s === 200 && Object.keys(dup.j).sort().join() === Object.keys(rg.j).sort().join(), 'existing phone gets the same response as a new one (no enumeration)');
  ok(db.prepare("SELECT status FROM users WHERE username='client'").get().status === 'active' && db.prepare("SELECT password_hash FROM users WHERE username='client'").get().password_hash.length > 50, 'registering an existing phone does not overwrite the account');
  ok(db.prepare("SELECT COUNT(*) c FROM audit_log WHERE action IN('login','login_fail','otp_request')").get().c > 5, 'security events are written to the audit log');

  srv.close(); console.log(`\n${pass} passed, ${failN} failed`); process.exit(failN ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
