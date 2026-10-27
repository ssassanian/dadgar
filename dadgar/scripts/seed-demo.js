'use strict';
// Creates demo accounts with simple passwords. FOR TESTING ONLY - never run on a live site.
// By default each account must change its password at first login (set SEED_MUST_CHANGE=0 to disable).
const { db, now, audit } = require('../lib/db'), sec = require('../lib/security');
const ACCOUNTS = [
  { username: 'admin', role: 'admin', name: 'مدیر سامانه', pass: 'Admin#2026' },
  { username: 'lawyer', role: 'lawyer', name: 'دکتر علی دادگر', pass: 'Lawyer#2026', specialty: 'ملکی و تجاری' },
  { username: 'lawyer2', role: 'lawyer', name: 'سارا احمدی', pass: 'Lawyer#2026', specialty: 'خانواده و ارث' },
  { username: 'lawyer3', role: 'lawyer', name: 'مهدی رضایی', pass: 'Lawyer#2026', specialty: 'کیفری' },
  { username: 'lawyer4', role: 'lawyer', name: 'نگار موسوی', pass: 'Lawyer#2026', specialty: 'قرارداد و شرکت‌ها' },
  { username: 'client', role: 'client', name: 'مریم رضایی', pass: 'Client#2026', phone: '09120000001' }
];
async function seed() {
  const must = process.env.SEED_MUST_CHANGE === '0' ? 0 : 1, out = [];
  for (const a of ACCOUNTS) {
    if (db.prepare('SELECT 1 FROM users WHERE username=?').get(a.username)) continue;
    const ph = a.phone ? sec.hmac('phone:' + a.phone) : null;
    db.prepare('INSERT INTO users(username,role,name,phone_hash,phone_last4,phone_enc,password_hash,status,must_change,specialty,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)')
      .run(a.username, a.role, a.name, ph, a.phone ? a.phone.slice(-4) : null, a.phone ? sec.encText(a.phone, 'user.phone') : null, await sec.hashPassword(a.pass), 'active', must, a.specialty || null, now());
    out.push(a); audit(null, 'seed_user', a.username);
  }
  return out;
}
module.exports = { seed, ACCOUNTS };
if (require.main === module) seed().then((c) => {
  if (!c.length) return console.log('Demo accounts already exist.');
  console.log('\nDemo accounts created (change the passwords at first login):');
  c.forEach((a) => console.log(`  ${a.role.padEnd(7)} username: ${a.username.padEnd(8)} password: ${a.pass}`));
});
