'use strict';
/* CMD-005 — پاکسازی داده‌های تست ماژول مالی (idempotent).
 * فاکتورهای متصل به کاربران آزمایشی (هم دستی، هم case-dar) + کلیدهای نرخ و Audit مالی.
 * CMD-029: ردیف‌های payment_requests (با cascade همراه فاکتورها) + audit پرداخت درگاهی هم پاک می‌شود.
 * کاربران/پرونده‌ها/نشست‌ها توسط cleanup-cycle.js پاک می‌شوند — این اسکریپت قبل از آن اجرا شود. */
const path = require('path');
const { db } = require(path.join(__dirname, '..', 'dadgar', 'web', 'lib', 'db.pg'));
const TEST_USERS = ['client_t', 'lawyer_t', 'admin_t'];

(async () => {
  const ph = TEST_USERS.map(() => '?').join(',');
  const ids = (await db.prepare(`SELECT id FROM users WHERE lower(username) IN(${ph})`).all(...TEST_USERS)).map(r => r.id);
  if (!ids.length) { console.log('no test users; nothing to clean (bill)'); process.exit(0); }
  const iph = ids.map(() => '?').join(',');
  const pr = await db.prepare(`DELETE FROM payment_requests WHERE client_id IN(${iph}) RETURNING id`).all(...ids).catch((e) => { if (e.code === '42P01') return []; throw e; });
  const inv = await db.prepare(`DELETE FROM invoices WHERE client_id IN(${iph}) RETURNING id`).all(...ids);
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'bill:%' OR key LIKE 'inv:%'`).run();
  await db.prepare(`DELETE FROM audit_log WHERE user_id IN(${iph}) AND (action LIKE 'invoice%' OR action LIKE 'payment%')`).all(...ids);
  console.log(`cleaned invoices: ${inv.length} rows | payment_requests: ${pr.length} rows | bill rate keys cleared`);
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
