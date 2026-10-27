'use strict';
const c = require('crypto'), cfg = require('./config');
const sub = (label) => Buffer.from(c.hkdfSync('sha256', cfg.secret, 'dadgar-v1', label, 32));
const K = { file: sub('file'), field: sub('field'), hmac: sub('hmac'), pepper: sub('pepper') };

/* ---------- passwords: HMAC pepper + scrypt (memory-hard, salted) ---------- */
const N = 1 << 15, R = 8, P = 1;
const scrypt = (pw, salt, n, r, p) => new Promise((res, rej) =>
  c.scrypt(pw, salt, 64, { N: n, r, p, maxmem: 128 * n * r * 2 }, (e, k) => (e ? rej(e) : res(k))));
const pre = (pw) => c.createHmac('sha256', K.pepper).update(String(pw).normalize('NFKC')).digest();
async function hashPassword(pw) {
  const salt = c.randomBytes(16);
  const k = await scrypt(pre(pw), salt, N, R, P);
  return ['scrypt', N, R, P, salt.toString('base64'), k.toString('base64')].join('$');
}
async function verifyPassword(pw, stored) {
  try {
    const [t, n, r, p, s, h] = String(stored).split('$');
    if (t !== 'scrypt') return false;
    const k = await scrypt(pre(pw), Buffer.from(s, 'base64'), +n, +r, +p);
    const e = Buffer.from(h, 'base64');
    return e.length === k.length && c.timingSafeEqual(e, k);
  } catch { return false; }
}
let dummy; // equalises timing for unknown usernames
async function dummyVerify(pw) { dummy = dummy || (await hashPassword('dummy-password-not-used')); await verifyPassword(pw, dummy); }
const WEAK = ['password', '1234567890', 'qwertyuiop', 'abcdefghij', 'admin1234', 'iloveyou12', '0123456789', 'asdfghjkl'];
function passwordProblem(pw, username) {
  pw = String(pw || '');
  if (pw.length < 10) return 'رمز عبور باید حداقل ۱۰ نویسه باشد.';
  if (pw.length > 128) return 'رمز عبور بیش از حد طولانی است.';
  if (!/[A-Za-z\u0600-\u06FF]/.test(pw) || !/[0-9۰-۹]/.test(pw)) return 'رمز عبور باید شامل حرف و عدد باشد.';
  const l = pw.toLowerCase();
  if (username && l.includes(String(username).toLowerCase())) return 'رمز عبور نباید شامل نام کاربری باشد.';
  if (WEAK.some((w) => l.includes(w))) return 'این رمز عبور بیش از حد رایج است.';
  return '';
}

/* ---------- tokens / hashes ---------- */
const token = () => c.randomBytes(32).toString('base64url');
const sha = (s) => c.createHash('sha256').update(String(s)).digest('hex');
const hmac = (s) => c.createHmac('sha256', K.hmac).update(String(s)).digest('hex');
const safeEq = (a, b) => { const x = Buffer.from(String(a)), y = Buffer.from(String(b)); return x.length === y.length && c.timingSafeEqual(x, y); };

/* ---------- AES-256-GCM (files and text fields) ---------- */
function encBuf(buf, key, aad) {
  const iv = c.randomBytes(12), ci = c.createCipheriv('aes-256-gcm', key, iv);
  if (aad) ci.setAAD(Buffer.from(aad));
  const ct = Buffer.concat([ci.update(buf), ci.final()]);
  return Buffer.concat([iv, ci.getAuthTag(), ct]);
}
function decBuf(buf, key, aad) {
  const iv = buf.subarray(0, 12), tag = buf.subarray(12, 28), ct = buf.subarray(28);
  const d = c.createDecipheriv('aes-256-gcm', key, iv);
  if (aad) d.setAAD(Buffer.from(aad));
  d.setAuthTag(tag);
  return Buffer.concat([d.update(ct), d.final()]);
}
const encFile = (b, aad) => encBuf(b, K.file, aad);
const decFile = (b, aad) => decBuf(b, K.file, aad);
const encText = (s, aad) => (s == null || s === '' ? null : 'v1.' + encBuf(Buffer.from(String(s), 'utf8'), K.field, aad).toString('base64url'));
const decText = (s, aad) => { if (!s) return ''; try { return decBuf(Buffer.from(String(s).slice(3), 'base64url'), K.field, aad).toString('utf8'); } catch { return ''; } };

module.exports = { hashPassword, verifyPassword, dummyVerify, passwordProblem, token, sha, hmac, safeEq, encFile, decFile, encText, decText };
