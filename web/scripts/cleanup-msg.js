'use strict';
/* CMD-007 — پاکسازی داده‌های تست ماژول پیام/تیکت (idempotent).
 * تیکت‌ها/پیام‌های تیکت/پیام‌های چت پرونده‌ی کاربران آزمایشی + کلیدهای نرخ + Audit مرتبط.
 * ترتیب مهم: این اسکریپت قبل از cleanup-cycle.js اجرا شود (messages به cases وابسته است
 * و cleanup-cycle پرونده‌ها را حذف می‌کند). کاربران/پرونده‌ها/نشست‌ها با cleanup-cycle پاک می‌شوند. */
const path = require('path');
const { db } = require(path.join(__dirname, '..', 'dadgar', 'web', 'lib', 'db.pg'));
const TEST_USERS = ['client_t', 'lawyer_t', 'admin_t'];

(async () => {
  const ph = TEST_USERS.map(() => '?').join(',');
  const ids = (await db.prepare(`SELECT id FROM users WHERE lower(username) IN(${ph})`).all(...TEST_USERS)).map(r => r.id);
  if (!ids.length) {
    await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'tkt:%' OR key LIKE 'tkr:%' OR key LIKE 'msg:%'`).run();
    console.log('no test users; rate keys cleared only (msg)'); process.exit(0);
  }
  const iph = ids.map(() => '?').join(',');
  const tm = await db.prepare(`DELETE FROM ticket_messages WHERE user_id IN(${iph}) RETURNING id`).all(...ids);
  const tk = await db.prepare(`DELETE FROM tickets WHERE user_id IN(${iph}) RETURNING id`).all(...ids);
  const ms = await db.prepare(`DELETE FROM messages WHERE user_id IN(${iph}) RETURNING id`).all(...ids);
  await db.prepare(`DELETE FROM rate_limits WHERE key LIKE 'tkt:%' OR key LIKE 'tkr:%' OR key LIKE 'msg:%'`).run();
  await db.prepare(`DELETE FROM audit_log WHERE user_id IN(${iph}) AND (action LIKE 'ticket%' OR action LIKE 'message%')`).all(...ids);
  console.log('cleaned ticket_messages:', tm.length, '| tickets:', tk.length, '| messages:', ms.length, '| rate keys cleared');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
