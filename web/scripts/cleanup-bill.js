'use strict';
/* CMD-005 — پاکسازی داده‌های تست ماژول مالی (idempotent).
 * فاکتورهای متصل به کاربران آزمایشی (هم دستی، هم case-dar) + کلیدهای نرخ و Audit مالی.
 * کاربران/پرونده‌ها/نشست‌ها توسط cleanup-cycle.js پاک می‌شوند — این اسکریپت قبل از آن اجرا شود. */
const path = require('path');
const { db } = require(path.join(__dirname, '..', 'dadgar', 'web', 'lib', 'db.pg'));
const TEST_USERS = ['client_t', 'lawyer_t', 'admin_t'];

(async () => {
  const ph = TEST_USERS.map(() => '?').join(',');
  const ids = (await db.prepare(`SELECT id FROM users WHERE lower(username) IN(${ph})`).all(...TEST_USERS)).map(r => r.id);
  if (!ids.length) { console.log('no test users; nothing to clean (bill)'); process.exit(0); }
  const iph = ids.map(() => '?').join(',');
  const inv = await db.prepare(`DELETE FROM invoices WHERE client_id IN(${iph}) RETURNING id`).all(...ids);
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'bill:%' OR key LIKE 'inv:%'`).run();
  await db.prepare(`DELETE FROM audit_log WHERE user_id IN(${iph}) AND action LIKE 'invoice%'`).all(...ids);
  console.log('cleaned invoices:', inv.length, 'rows | bill rate keys cleared');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
