'use strict';
const fs = require('fs'), path = require('path');
// tiny .env loader (no dependency)
(function () {
  const f = path.join(__dirname, '..', '.env');
  if (!fs.existsSync(f)) return;
  for (const l of fs.readFileSync(f, 'utf8').split(/\r?\n/)) {
    const m = l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m && !(m[1] in process.env)) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
})();
const prod = process.env.NODE_ENV === 'production';
let secret = process.env.APP_SECRET || '';
if (secret.length < 48) {
  if (prod) { console.error('FATAL: APP_SECRET must be set (>=48 chars) in production.'); process.exit(1); }
  secret = 'development-only-secret-' + 'x'.repeat(40);
  if (process.env.NODE_ENV !== 'test') console.warn('[warn] using an insecure development APP_SECRET');
}
module.exports = {
  prod,
  secret,
  port: +process.env.PORT || 3000,
  host: process.env.HOST || '127.0.0.1',
  trustProxy: process.env.TRUST_PROXY === '1',
  dataDir: path.resolve(process.env.DATA_DIR || path.join(__dirname, '..', 'data')),
  cookieSecure: process.env.COOKIE_SECURE ? process.env.COOKIE_SECURE === '1' : prod,
  showOtp: !prod && process.env.DEV_SHOW_OTP === '1',
  sessionIdleMs: 30 * 60 * 1000,
  sessionMaxMs: 12 * 60 * 60 * 1000,
  maxUpload: 10 * 1024 * 1024,
  /* CMD-028 — درگاه پرداخت (اسکلت بی‌طرف): تا انتخاب درگاه توسط مدیر،
     provider خالی می‌ماند و همه‌ی مسیرهای پرداخت پیام صادقانه می‌دهند.
     کلید پذیرنده فقط در env سرور (Vercel) — هرگز در کد یا موبایل. */
  pay: {
    provider: process.env.PAYMENT_PROVIDER || '',
    merchantId: process.env.PAYMENT_MERCHANT_ID || '',
    callbackBase: process.env.PAYMENT_CALLBACK_BASE || ''
  }
};
