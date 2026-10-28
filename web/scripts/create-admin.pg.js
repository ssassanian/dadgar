'use strict';
/* معادل scripts/create-admin.js برای دیتابیس Postgres (Supabase) — ابزار عملیاتی، بخشی از دیپلوی نیست.
   استفاده: ADMIN_USER=owner ADMIN_PASS='رمز-قوی-۱' node scripts/create-admin.pg.js */
const { db, now, audit } = require('../lib/db.pg'), sec = require('../lib/security');
(async () => {
  const u = (process.env.ADMIN_USER || '').toLowerCase(), p = process.env.ADMIN_PASS || '', n = process.env.ADMIN_NAME || 'مدیر سامانه';
  if (!/^[a-z0-9_.-]{3,32}$/.test(u)) return console.error('ADMIN_USER must be 3-32 chars (a-z 0-9 _ . -).');
  const pr = sec.passwordProblem(p, u); if (pr) return console.error(pr);
  if (await db.prepare('SELECT 1 FROM users WHERE lower(username)=lower(?)').get(u)) return console.error('This username already exists.');
  await db.prepare("INSERT INTO users(username,role,name,password_hash,status,must_change,created_at) VALUES(?, 'admin', ?, ?, 'active', 0, ?)").run(u, n, await sec.hashPassword(p), now());
  await audit(null, 'create_admin', u, null);
  console.log('Admin created:', u);
  process.exit(0);
})().catch((e) => { console.error('[create-admin]', e.message); process.exit(1); });
