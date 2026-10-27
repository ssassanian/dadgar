'use strict';
/* CMD-003 — پاکسازی کامل داده‌های تست چرخه پرونده (به ترتیب FK). idempotent. */
const path = require('path');
const { db } = require(path.join(__dirname, '..', 'dadgar', 'web', 'lib', 'db.pg'));
const TEST_USERS = ['client_t', 'lawyer_t', 'admin_t'];

(async () => {
  const ph = TEST_USERS.map(() => '?').join(',');
  const ids = (await db.prepare(`SELECT id FROM users WHERE lower(username) IN(${ph})`).all(...TEST_USERS)).map(r => r.id);
  if (!ids.length) { console.log('no test users; nothing to clean'); process.exit(0); }
  const iph = ids.map(() => '?').join(',');
  const cas = (await db.prepare(`SELECT id FROM cases WHERE client_id IN(${iph}) OR lawyer_id IN(${iph})`).all(...ids, ...ids)).map(r => r.id);
  if (cas.length) {
    const cph = cas.map(() => '?').join(',');
    await db.prepare(`DELETE FROM invoices WHERE case_id IN(${cph})`).run(...cas);
    await db.prepare(`DELETE FROM reviews WHERE case_id IN(${cph})`).run(...cas);
    await db.prepare(`DELETE FROM messages WHERE case_id IN(${cph})`).run(...cas);
    await db.prepare(`DELETE FROM documents WHERE case_id IN(${cph})`).run(...cas);
    await db.prepare(`DELETE FROM proposals WHERE case_id IN(${cph})`).run(...cas);
    await db.prepare(`DELETE FROM cases WHERE id IN(${cph})`).run(...cas);
  }
  await db.prepare(`DELETE FROM proposals WHERE lawyer_id IN(${iph})`).run(...ids);
  await db.prepare(`DELETE FROM ticket_messages WHERE user_id IN(${iph})`).run(...ids);
  await db.prepare(`DELETE FROM tickets WHERE user_id IN(${iph})`).run(...ids);
  await db.prepare(`DELETE FROM appointments WHERE client_id IN(${iph}) OR lawyer_id IN(${iph})`).run(...ids, ...ids);
  await db.prepare(`DELETE FROM sessions WHERE user_id IN(${iph})`).run(...ids);
  for (const i of ids) await db.prepare('DELETE FROM rate_limits WHERE key=?').run('case:' + i);
  await db.prepare(`DELETE FROM audit_log WHERE user_id IN(${iph})`).run(...ids);
  await db.prepare(`DELETE FROM users WHERE id IN(${iph})`).run(...ids);
  console.log('cleaned users:', ids.join(','), '| cases:', cas.join(',') || 'none');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
