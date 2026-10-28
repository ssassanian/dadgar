'use strict';
/* هارنس تست محلی: همان منطق وب با دیتابیس واقعی (Supabase) — فقط برای تست مهاجرت، در دیپلوی نیست. */
const http = require('http');
const { handle } = require('../lib/web');
const PORT = +process.env.PORT || 3200;
http.createServer((req, res) => handle(req, res).catch((e) => { console.error(e); try { res.writeHead(500); res.end(); } catch { } })).listen(PORT, '127.0.0.1', () => console.log('dadgar dev harness on http://127.0.0.1:' + PORT));
