'use strict';
/* CMD-006 — پاکسازی داده‌های تست ماژول نظرات (idempotent).
 * نظرات متصل به کاربران آزمایشی + کلیدهای نرخ و Audit نظرات/وضعیت پرونده.
 * کاربران/پرونده‌ها/نشست‌ها توسط cleanup-cycle.js پاک می‌شوند — این اسکریپت قبل از آن اجرا شود. */
const path = require('path');
const { db } = require(path.join(__dirname, '..', 'dadgar', 'web', 'lib', 'db.pg'));
const TEST_USERS = ['client_t', 'lawyer_t', 'admin_t'];

(async () => {
  const ph = TEST_USERS.map(() => '?').join(',');
  const ids = (await db.prepare(`SELECT id FROM users WHERE lower(username) IN(${ph})`).all(...TEST_USERS)).map(r => r.id);
  if (!ids.length) { console.log('no test users; nothing to clean (rev)'); process.exit(0); }
  const iph = ids.map(() => '?').join(',');
  const rev = await db.prepare(`DELETE FROM reviews WHERE client_id IN(${iph}) OR lawyer_id IN(${iph}) RETURNING id`).all(...ids, ...ids);
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'rev:%'`).run();
  await db.prepare(`DELETE FROM audit_log WHERE user_id IN(${iph}) AND (action LIKE 'review%' OR action LIKE 'case_status%')`).all(...ids);
  console.log('cleaned reviews:', rev.length, 'rows | rev rate keys cleared');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
