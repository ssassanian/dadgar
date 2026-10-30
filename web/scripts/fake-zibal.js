'use strict';
/* CMD-029 — درگاه زبال تقلبی برای هارنس محلی (جایگزین PAYMENT_API_BASE).
 * رفتار عین مستند زیبال: پاسخ همیشه HTTP 200؛ فقط «result» ملاک است.
 * کنترل قطعی نتیجه‌ی verify با GET /__set?mode=ok|already|fail|mismatch
 *   ok       → result=100 + مبلغ همان درخواست + ref RF-TEST
 *   already  → result=201 + مبلغ همان درخواست (تکرار ایدمپوتنت)
 *   fail     → result=202 (پرداخت نشده)
 *   mismatch → result=100 با مبلغ +۱۰۰۰ (آزمون گارد مغایرت مبلغ)
 * بدون هیچ خروجی حساس؛ فقط روی 127.0.0.1 گوش می‌دهد. */
const http = require('http');
const PORT = Number(process.argv[2] || 3300);
const MODES = new Set(['ok', 'already', 'fail', 'mismatch']);
let mode = 'ok';
let nextTrack = 7100000000;
const byTrack = new Map(); // trackId → amountRial

const json = (res, o) => { const b = Buffer.from(JSON.stringify(o)); res.writeHead(200, { 'Content-Type': 'application/json', 'Content-Length': b.length }); res.end(b); };

http.createServer((req, res) => {
  const u = new URL(req.url, 'http://127.0.0.1');
  if (req.method === 'GET' && u.pathname === '/__set') {
    const m = u.searchParams.get('mode');
    if (!MODES.has(m)) { res.writeHead(400); return res.end('bad mode'); }
    mode = m;
    return json(res, { ok: true, mode });
  }
  if (req.method === 'POST' && u.pathname === '/v1/request') {
    let body = '';
    req.on('data', (c) => { body += c; if (body.length > 1e5) req.destroy(); });
    req.on('end', () => {
      try {
        const d = JSON.parse(body || '{}');
        const amount = Math.floor(Number(d.amount) || 0);
        if (!amount) return json(res, { result: 106, message: 'invalid amount' });
        const trackId = ++nextTrack;
        byTrack.set(trackId, amount);
        json(res, { trackId, result: 100, message: 'success' });
      } catch { json(res, { result: 105, message: 'bad json' }); }
    });
    return;
  }
  if (req.method === 'POST' && u.pathname === '/v1/verify') {
    let body = '';
    req.on('data', (c) => { body += c; if (body.length > 1e5) req.destroy(); });
    req.on('end', () => {
      try {
        const d = JSON.parse(body || '{}');
        const trackId = Number(d.trackId);
        const amount = byTrack.get(trackId);
        if (!amount) return json(res, { result: 202, message: 'track not found' });
        if (mode === 'fail') return json(res, { result: 202, message: 'transaction failed', status: -2 });
        if (mode === 'already') return json(res, { result: 201, message: 'verified before', status: 1, amount, refNumber: 'RF-TEST', cardNumber: '6104-****-****-1234', paidAt: new Date().toISOString() });
        const amt = mode === 'mismatch' ? amount + 1000 : amount;
        json(res, { result: 100, message: 'success', status: 1, amount: amt, refNumber: 'RF-TEST', cardNumber: '6104-****-****-1234', paidAt: new Date().toISOString() });
      } catch { json(res, { result: 202, message: 'bad json' }); }
    });
    return;
  }
  res.writeHead(404); res.end('not found');
}).listen(PORT, '127.0.0.1', () => console.log('fake-zibal on 127.0.0.1:' + PORT));
