'use strict';
/* CMD-003 — ساخت کاربران آزمایشی روی دیتابیس واقعی برای تست چرخه پرونده.
 * فقط برای تست محلی؛ در پایان تست با cleanup-cycle.py حذف می‌شوند. */
const path = require('path');
const cfg = require(path.join(__dirname, '..', 'dadgar', 'web', 'lib', 'config'));
const sec = require(path.join(__dirname, '..', 'dadgar', 'web', 'lib', 'security'));
const { db, now } = require(path.join(__dirname, '..', 'dadgar', 'web', 'lib', 'db.pg'));

const USERS = [
  { username: 'client_t', role: 'client', name: 'مشتری تست چرخه', pass: 'ClientT#2026' },
  { username: 'lawyer_t', role: 'lawyer', name: 'وکیل تست چرخه', pass: 'LawyerT#2026', specialty: 'قرارداد' },
  { username: 'admin_t', role: 'admin', name: 'مدیر تست چرخه', pass: 'AdminT#2026x' },
];

(async () => {
  const n = now();
  for (const u of USERS) {
    await db.prepare('DELETE FROM users WHERE lower(username)=lower(?)').run(u.username); // idempotent
    const r = await db.prepare("INSERT INTO users(username,role,name,password_hash,status,must_change,specialty,created_at) VALUES(?,?,?,?, 'active',0,?,?) RETURNING id")
      .run(u.username, u.role, u.name, await sec.hashPassword(u.pass), u.specialty || null, n);
    console.log('seeded', u.username, 'id=' + r.lastInsertRowid);
  }
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
