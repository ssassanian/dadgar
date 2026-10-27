#!/bin/bash
# ============================================================
# CMD-003 — اجرای کامل تست e2e چرخه پرونده (پاکسازی + seed + هارنس + مرورگر)
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
export DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
export APP_SECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"

echo "== cleanup + seed (با APP_SECRET درست) =="
node /home/z/my-project/scripts/cleanup-cycle.js
node /home/z/my-project/scripts/seed-test-users.pg.js

# هارنس: اگر بالا نیست بالا بیاور
if ! curl -s -m 2 http://127.0.0.1:3202/api/health | grep -q ok; then
  echo "== starting harness :3202 =="
  (PORT=3202 nohup node scripts/dev-server.js > /tmp/e2e_harness.log 2>&1 &)
  sleep 3
fi
curl -s http://127.0.0.1:3202/api/health && echo " <- harness ready"

python3 /home/z/my-project/scripts/e2e-cycle.py
RC=$?
echo "== e2e finished (rc=$RC) =="
