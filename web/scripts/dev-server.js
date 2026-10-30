'use strict';
/* هارنس تست محلی: همان منطق وب با دیتابیس واقعی (Supabase) — فقط برای تست مهاجرت، در دیپلوی نیست. */
const http = require('http');
const { handle } = require('../lib/web');
const html = require('../api/html');
const page = require('../api/page');
const mobilePreview = require('../api/mobile-preview');
const PORT = +process.env.PORT || 3200;

function dispatch(req, res) {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  if (pathname === '/') return html(req, res);
  if (pathname === '/mobile-preview') return mobilePreview(req, res);
  if (!pathname.startsWith('/api/')) return page(req, res);
  return handle(req, res);
}

http.createServer((req, res) => dispatch(req, res).catch((e) => {
  console.error(e);
  try { res.writeHead(500); res.end(); } catch { }
})).listen(PORT, '127.0.0.1', () => console.log('dadgar dev harness on http://127.0.0.1:' + PORT));
