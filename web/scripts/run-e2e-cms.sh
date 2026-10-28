#!/bin/bash
# ============================================================
# CMD-010 — اجرای کامل تست e2e CMS/تنظیمات (پاکسازی + seed + هارنس تازه + مرورگر + پاکسازی نهایی)
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
export DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
export APP_SECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"

echo "== cleanup + seed =="
node /home/z/my-project/scripts/cleanup-cms.js
node /home/z/my-project/scripts/cleanup-log.js
node /home/z/my-project/scripts/cleanup-docs.js
node /home/z/my-project/scripts/cleanup-msg.js
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node /home/z/my-project/scripts/seed-test-users.pg.js

pkill -f dev-server.js 2>/dev/null || true
sleep 1
echo "== starting fresh harness :3210 =="
(PORT=3210 nohup node scripts/dev-server.js > /tmp/cms_e2e_harness.log 2>&1 &)
for i in $(seq 1 10); do sleep 1; curl -s -m 2 http://127.0.0.1:3210/api/health | grep -q ok && break; done
curl -s http://127.0.0.1:3210/api/health && echo " <- harness ready"

RC=0
python3 /home/z/my-project/scripts/e2e-cms.py || RC=$?
echo "== e2e finished (rc=$RC) =="

echo "== final cleanup =="
pkill -f dev-server.js 2>/dev/null || true
node /home/z/my-project/scripts/cleanup-cms.js
node /home/z/my-project/scripts/cleanup-log.js
node /home/z/my-project/scripts/cleanup-docs.js
node /home/z/my-project/scripts/cleanup-msg.js
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
echo "cleanup done"
exit $RC
