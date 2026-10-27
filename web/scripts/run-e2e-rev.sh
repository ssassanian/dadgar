#!/bin/bash
# ============================================================
# CMD-006 — اجرای کامل تست e2e ماژول نظرات (پاکسازی + seed + هارنس تازه + مرورگر + پاکسازی نهایی)
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
export DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
export APP_SECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"

clearrev() { node /home/z/my-project/scripts/cleanup-rev.js; }

echo "== cleanup + seed =="
clearrev
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node /home/z/my-project/scripts/seed-test-users.pg.js

# هارنس تازه (تا dynamic/index.html جدید سرو شود) — هارنس قدیمی بسته می‌شود
pkill -f dev-server.js 2>/dev/null || true
sleep 1
echo "== starting fresh harness :3204 =="
(PORT=3204 nohup node scripts/dev-server.js > /tmp/rev_e2e_harness.log 2>&1 &)
for i in $(seq 1 10); do sleep 1; curl -s -m 2 http://127.0.0.1:3204/api/health | grep -q ok && break; done
curl -s http://127.0.0.1:3204/api/health && echo " <- harness ready"

RC=0
python3 /home/z/my-project/scripts/e2e-rev.py || RC=$?
echo "== e2e finished (rc=$RC) =="

echo "== final cleanup =="
pkill -f dev-server.js 2>/dev/null || true
clearrev
node /home/z/my-project/scripts/cleanup-cycle.js
node -e "const {db}=require('./lib/db.pg');(async()=>{const n=(await db.prepare('SELECT COUNT(*) c FROM reviews').get()).c;console.log('reviews left:',n);if(+n!==0) throw new Error('reviews not cleaned');process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"
exit $RC
