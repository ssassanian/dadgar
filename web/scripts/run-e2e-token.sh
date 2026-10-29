#!/bin/bash
# ============================================================
# CMD-026 — اجرای تست e2e افزوده‌ی اول D-6 (توکن موبایل)
# پاکسازی نرخ + seed + هارنس تازه :3202 + e2e-token.py + پاکسازی نهایی
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
export DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
export APP_SECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"

clearkeys() { node -e "const {db}=require('./lib/db.pg');(async()=>{await db.prepare(\"DELETE FROM rate_limits WHERE key LIKE 'login:%' OR key LIKE 'refresh:%' OR key LIKE 'ip:%'\").run();console.log('rate keys cleared');process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"; }

echo "== cleanup + seed =="
node /home/z/my-project/scripts/cleanup-cycle.js 2>/dev/null || true
clearkeys
node /home/z/my-project/scripts/seed-test-users.pg.js

# هارنس تازه (کد جدید web.js)
pkill -f dev-server.js 2>/dev/null || true
sleep 1
echo "== starting fresh harness :3202 =="
(PORT=3202 nohup node scripts/dev-server.js > /tmp/token_e2e_harness.log 2>&1 &)
for i in $(seq 1 10); do sleep 1; curl -s -m 2 http://127.0.0.1:3202/api/health | grep -q ok && break; done
curl -s http://127.0.0.1:3202/api/health && echo " <- harness ready"

RC=0
python3 scripts/e2e-token.py || RC=$?
echo "== e2e-token finished (rc=$RC) =="

echo "== sessions by kind (before cleanup) =="
node -e "const {db}=require('./lib/db.pg');(async()=>{const rows=await db.prepare(\"SELECT kind, COUNT(*) c FROM sessions GROUP BY kind\").all();console.log(JSON.stringify(rows));process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"

echo "== final cleanup: revoke leftover api tokens of test user =="
node -e "const {db}=require('./lib/db.pg');(async()=>{const r=await db.prepare(\"DELETE FROM sessions WHERE kind LIKE 'api-%' AND user_id=(SELECT id FROM users WHERE username='client_t')\").run();console.log('api session rows removed:',r.changes);process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"
clearkeys
pkill -f dev-server.js 2>/dev/null || true
exit $RC
