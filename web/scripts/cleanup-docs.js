'use strict';
/* CMD-008 — پاکسازی داده‌های تست ماژول اسناد (idempotent).
 * اسنادِ بارگذاری‌شده توسط کاربران آزمایشی یا پیوسته به پرونده‌های آن‌ها + کلیدهای نرخ + Audit مرتبط.
 * ترتیب مهم: این اسکریپت قبل از cleanup-cycle.js اجرا شود (documents به cases وابسته است
 * و cleanup-cycle پرونده‌ها را حذف می‌کند). کاربران/پرونده‌ها/نشست‌ها با cleanup-cycle پاک می‌شوند. */
const path = require('path');
const { db } = require(path.join(__dirname, '..', 'dadgar', 'web', 'lib', 'db.pg'));
const TEST_USERS = ['client_t', 'lawyer_t', 'admin_t'];

(async () => {
  const ph = TEST_USERS.map(() => '?').join(',');
  const ids = (await db.prepare(`SELECT id FROM users WHERE lower(username) IN(${ph})`).all(...TEST_USERS)).map(r => r.id);
  if (!ids.length) {
    await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'doc:%'`).run();
    console.log('no test users; rate keys cleared only (docs)'); process.exit(0);
  }
  const iph = ids.map(() => '?').join(',');
  const dc = await db.prepare(`DELETE FROM documents WHERE owner_id IN(${iph}) OR case_id IN (SELECT id FROM cases WHERE client_id IN(${iph}) OR lawyer_id IN(${iph})) RETURNING id`).all(...ids, ...ids, ...ids);
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'doc:%'`).run();
  await db.prepare(`DELETE FROM audit_log WHERE user_id IN(${iph}) AND action LIKE 'doc%'`).all(...ids);
  console.log('cleaned documents:', dc.length, '| rate keys cleared');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
