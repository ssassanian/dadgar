'use strict';
/* CMD-054 — اعمال DDL جدول media روی Supabase (idempotent — IF NOT EXISTS).
 * اجرا: DATABASE_URL="postgresql://…" node scripts/apply-media-ddl.js
 * (الگوی apply-settings-ddl.js — CMD-011؛ رمز اتصال فقط از env، هرگز در کد یا کامیت.) */
const { sql } = require('../lib/db.pg');

(async () => {
  await sql.unsafe(`CREATE TABLE IF NOT EXISTS media(
    name TEXT PRIMARY KEY,
    mime TEXT,
    size BIGINT,
    file TEXT,
    updated_at BIGINT NOT NULL,
    updated_by BIGINT REFERENCES users(id))`);
  await sql.unsafe(`ALTER TABLE media DISABLE ROW LEVEL SECURITY`);
  await sql.unsafe(`GRANT SELECT, INSERT, UPDATE, DELETE ON media TO dadgar_app`);
  const cols = await sql.unsafe(`SELECT column_name FROM information_schema.columns WHERE table_name='media' ORDER BY ordinal_position`);
  console.log('media table ready. columns:', cols.map((c) => c.column_name).join(', '));
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
