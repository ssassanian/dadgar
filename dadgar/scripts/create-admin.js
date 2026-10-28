'use strict';
// Creates the real administrator for a live site:
//   ADMIN_USER=owner ADMIN_PASS='a-long-strong-password-1' ADMIN_NAME='Name' npm run create-admin
const { db, now, audit } = require('../lib/db'), sec = require('../lib/security');
(async () => {
  const u = (process.env.ADMIN_USER || '').toLowerCase(), p = process.env.ADMIN_PASS || '', n = process.env.ADMIN_NAME || 'مدیر سامانه';
  if (!/^[a-z0-9_.-]{3,32}$/.test(u)) return console.error('ADMIN_USER must be 3-32 chars (a-z 0-9 _ . -).');
  const pr = sec.passwordProblem(p, u); if (pr) return console.error(pr);
  if (db.prepare('SELECT 1 FROM users WHERE username=?').get(u)) return console.error('This username already exists.');
  db.prepare("INSERT INTO users(username,role,name,password_hash,status,must_change,created_at) VALUES(?, 'admin', ?, ?, 'active', 0, ?)").run(u, n, await sec.hashPassword(p), now());
  audit(null, 'create_admin', u); console.log('Admin created:', u);
})();
