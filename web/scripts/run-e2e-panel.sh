#!/bin/bash
# CMD-031 — e2e runner: seed + prep data (case+invoice) + server + browser tests + cleanup
set -e
cd /home/z/my-project/dadgar/web
export NODE_ENV=development DEV_SHOW_OTP=1 TRUST_PROXY=0 SMS_DRIVER=console
export APP_SECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:$(cat /home/z/my-project/.secrets_supabase_db.txt)@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"

node /home/z/my-project/scripts/cleanup-bill.js >/dev/null
node /home/z/my-project/scripts/cleanup-cycle.js >/dev/null
node /home/z/my-project/scripts/seed-test-users.pg.js

node scripts/fake-zibal.js 3300 > /tmp/e2ep_fake.log 2>&1 &
FAKE=$!
PORT=3202 PAYMENT_PROVIDER=zibal PAYMENT_MERCHANT_ID=zibal PAYMENT_CALLBACK_BASE=http://127.0.0.1:3202 PAYMENT_API_BASE=http://127.0.0.1:3300 node scripts/dev-server.js > /tmp/e2ep_harness.log 2>&1 &
SRV=$!
sleep 3
B=http://127.0.0.1:3202
trap 'kill $SRV $FAKE 2>/dev/null' EXIT

jqf() { python3 -c "import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1]))" "$1"; }

# logins
TC=$(curl -s -c /tmp/ep_c.jar -X POST $B/api/auth/login -H "Content-Type: application/json" -H "Origin: $B" -d '{"username":"client_t","password":"ClientT#2026"}' | jqf "d['csrf']")
TA=$(curl -s -c /tmp/ep_a.jar -X POST $B/api/auth/login -H "Content-Type: application/json" -H "Origin: $B" -d '{"username":"admin_t","password":"AdminT#2026x"}' | jqf "d['csrf']")
CID=$(curl -s -b /tmp/ep_c.jar $B/api/me | jqf "d['user']['id']")
KID=$(curl -s -b /tmp/ep_c.jar -H "x-csrf-token: $TC" -X POST $B/api/cases -H "Content-Type: application/json" -H "Origin: $B" -d '{"category":"قرارداد","title":"پرونده e2e پنل CMD-031","description":"شرح آزمایشی پرونده برای صفحه جزئیات واقعی"}' | jqf "d.get('id')")
IID=$(curl -s -b /tmp/ep_a.jar -H "x-csrf-token: $TA" -X POST $B/api/invoices -H "Content-Type: application/json" -H "Origin: $B" -d "{\"client_id\":$CID,\"case_id\":$KID,\"amount\":800000}" | jqf "d.get('id')")
echo "prep: client=$CID case=$KID invoice=$IID"
E2E_CASE_ID=$KID python3 scripts/e2e-panel.py
E2E=$?

node /home/z/my-project/scripts/cleanup-bill.js || true
node /home/z/my-project/scripts/cleanup-cycle.js || true
echo "cleanup done (always)"
exit $E2E
