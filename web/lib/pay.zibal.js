'use strict';
/* CMD-029 — ماژول درگاه زبال (تنها provider فعلی؛ رابط بی‌طرف برای providerهای آینده)
 * منبع: مستندات رسمی IPG زیبال (help.zibal.ir/ipg) + مدل OpenAPI رسمی زیبال.
 *   POST {base}/v1/request  {merchant, amount(ریال), callbackUrl, orderId?, description?}
 *         → {trackId, result, message}   — result=100 یعنی موفق (trackId معتبر)
 *   صفحه‌ی پرداخت: {base}/start/{trackId}  (ریدایرکت مرورگر کاربر)
 *   POST {base}/v1/verify   {merchant, trackId}
 *         → {result, status, amount(ریال), refNumber?, cardNumber?, paidAt?, message}
 * قواعد امنیتی مستند زیبال که این ماژول اجرا می‌کند:
 *   ۱) پاسخ درگاه همیشه HTTP 200 است؛ فقط «result» ملاک تصمیم است — کد HTTP هرگز.
 *   ۲) success=1 در callback فقط راهنمای کاربر است؛ تایید نهایی فقط با verify سمت سرور.
 *   ۳) مبلغ پاسخ verify باید با مبلغ ثبت‌شده یکی باشد؛ در غیر این صورت تحویل ممنوع.
 *   ۴) merchant (کلید پذیرنده) فقط در env سرور — هرگز در کد/موبایل/لاگ.
 * result های verify: 100 = پرداخت‌شده (تایید اول) / 201 = قبلا تاییدشده (تکرار ایدمپوتنت)
 *                    / 202 = پرداخت نشده / بقیه = ناموفق.
 * PAYMENT_API_BASE فقط برای هارنس محلی (fake-zibal) — پیش‌فرض درگاه رسمی است.
 * خطاها بدون HTTP status پرتاب می‌شوند: e.payGateway (شبکه/JSON) و e.payResult (رد درگاه)
 * — نگاشت به HttpError در web.js انجام می‌شود تا ماژول به لایه‌ی HTTP وابسته نباشد. */
const API_BASE = () => String(process.env.PAYMENT_API_BASE || 'https://gateway.zibal.ir').replace(/\/+$/, '');
const RESULT_OK = 100;
const RESULT_ALREADY = 201;

function fail(code, extra) { const e = new Error(code); if (extra) Object.assign(e, extra); return e; }

async function post(path, body) {
  let r;
  try {
    r = await fetch(API_BASE() + path, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(15000),
    });
  } catch { throw fail('pay_gateway_unreachable', { payGateway: true }); }
  let d;
  try { d = await r.json(); } catch { throw fail('pay_gateway_bad_json', { payGateway: true }); }
  if (!d || typeof d !== 'object') throw fail('pay_gateway_bad_json', { payGateway: true });
  return d;
}

/* ساخت درخواست پرداخت → { trackId, payUrl } — مبلغ به ریال */
async function createRequest(cfg, { amountRial, callbackUrl, orderId, description }) {
  const d = await post('/v1/request', {
    merchant: String(cfg.merchantId || ''),
    amount: Math.floor(Number(amountRial) || 0),
    callbackUrl: String(callbackUrl || ''),
    orderId: String(orderId || '').slice(0, 64) || undefined,
    description: String(description || '').slice(0, 255) || undefined,
  });
  const result = Number(d.result);
  if (result === RESULT_OK && d.trackId != null) {
    const trackId = Number(d.trackId);
    if (Number.isFinite(trackId) && trackId > 0) return { trackId, payUrl: API_BASE() + '/start/' + trackId };
  }
  throw fail('pay_gateway_rejected', { payResult: result, payMessage: String(d.message || '') });
}

/* استعلام/تایید پرداخت → { result, status, amount, refNumber, cardNumber, paidAt } */
async function verify(cfg, trackId) {
  const d = await post('/v1/verify', { merchant: String(cfg.merchantId || ''), trackId: Number(trackId) });
  return {
    result: Number(d.result),
    status: d.status != null ? Number(d.status) : null,
    amount: d.amount != null ? Number(d.amount) : null,
    refNumber: d.refNumber != null ? String(d.refNumber) : '',
    cardNumber: d.cardNumber != null ? String(d.cardNumber) : '',
    paidAt: d.paidAt != null ? String(d.paidAt) : '',
  };
}

module.exports = { createRequest, verify, startUrl: (trackId) => API_BASE() + '/start/' + trackId, RESULT_OK, RESULT_ALREADY };
