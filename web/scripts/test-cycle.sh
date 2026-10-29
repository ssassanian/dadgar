#!/bin/bash
# ============================================================
# CMD-003 — تست چرخه پرونده (فاز ۳ گام ۱) روی دیتابیس واقعی
# هارنس محلی web/ + Supabase؛ کاربران آزمایشی بعداً پاک می‌شوند.
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
APPSECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development DEV_SHOW_OTP=1 TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"
export APP_SECRET="$APPSECRET"

echo "===== 0) cleanup leftovers + seed test users ====="
node /home/z/my-project/scripts/cleanup-cycle.js
node /home/z/my-project/scripts/seed-test-users.pg.js

PORT=3201 node scripts/dev-server.js > /tmp/cycle_harness.log 2>&1 &
SRV=$!
sleep 2
B=http://127.0.0.1:3201
CJ=/tmp/c_client.jar; LJ=/tmp/c_lawyer.jar; AJ=/tmp/c_admin.jar
rm -f $CJ $LJ $AJ

login() { # jar user pass -> csrf
  curl -s -c "$1" -X POST $B/api/auth/login -H "Content-Type: application/json" -H "Origin: $B" \
    -d "{\"username\":\"$2\",\"password\":\"$3\"}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('csrf','FAIL:'+d.get('error','?')))"
}

echo "===== 1) logins (client/lawyer/admin) ====="
CC=$(login $CJ client_t 'ClientT#2026'); echo "client csrf: ${CC:0:8}…"
LC=$(login $LJ lawyer_t 'LawyerT#2026'); echo "lawyer csrf: ${LC:0:8}…"
AC=$(login $AJ admin_t 'AdminT#2026x'); echo "admin csrf: ${AC:0:8}…"
[ "$CC" != "FAIL" ] && [ "$LC" != "FAIL" ] && [ "$AC" != "FAIL" ] || { echo LOGIN_FAILED; kill $SRV; exit 1; }

echo "===== 2) client creates two cases ====="
CASE1=$(curl -s -b $CJ -X POST $B/api/cases -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" \
  -d '{"category":"قرارداد","title":"بازبینی قرارداد اجاره‌ی تجاری","description":"قرارداد اجاره‌ی مغازه با بند فسخ مبهم؛ نیاز به بازبینی حقوقی دارم."}')
echo "$CASE1"
CASE2=$(curl -s -b $CJ -X POST $B/api/cases -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" \
  -d '{"category":"ملکی","title":"اختلاف در تخلیه‌ی ملک مسکونی","description":"مستأجر علیرغم پایان قرارداد ملک را تخلیه نمی‌کند."}')
echo "$CASE2"
CID1=$(echo "$CASE1" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
CID2=$(echo "$CASE2" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
echo "case ids: $CID1, $CID2"

echo "===== 3) client list (should be 2 rows, status waiting) ====="
curl -s -b $CJ "$B/api/cases" | python3 -c "import json,sys; d=json.load(sys.stdin); print('total:',d['total'],'pages:',d['pages'],'statuses:',[r['status'] for r in d['rows']])"

echo "===== 4) negative: lawyer cannot create case (403) ====="
curl -s -o /dev/null -w "[%{http_code}]\n" -b $LJ -X POST $B/api/cases -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $LC" -d '{"category":"ملکی","title":"تست غیرمجاز ۱۲۳","description":"x"}'
echo "===== 4b) negative: client cannot see proposals API (403) ====="
curl -s -o /dev/null -w "[%{http_code}]\n" -b $CJ "$B/api/proposals"

echo "===== 5) lawyer open list (should include both, with excerpt, WITHOUT client name) ====="
curl -s -b $LJ "$B/api/cases?scope=open" | python3 -c "
import json,sys; d=json.load(sys.stdin)
print('open total:', d['total'])
r=d['rows'][0]
print('has excerpt:', bool(r.get('excerpt')), '| leaks client_name:', 'client_name' in r)
assert 'client_name' not in r, 'PRIVACY LEAK'
print('PRIVACY OK')"

echo "===== 6) lawyer proposes on case $CID1 ====="
PROP=$(curl -s -b $LJ -X POST $B/api/cases/$CID1/proposals -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $LC" \
  -d '{"amount":7500000,"days":25,"note":"سابقه‌ی مشابه زیاد؛ می‌توانم زودتر شروع کنم."}')
echo "$PROP"
PID=$(echo "$PROP" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
echo "===== 6b) duplicate proposal → 409 ====="
curl -s -o /dev/null -w "[%{http_code}]\n" -b $LJ -X POST $B/api/cases/$CID1/proposals -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $LC" -d '{"amount":2000000,"days":10}'
echo "===== 6c) case status now proposing (client view) ====="
curl -s -b $CJ $B/api/cases/$CID1 | python3 -c "import json,sys; d=json.load(sys.stdin); print('status:',d['status'])"
echo "===== 6d) lawyer sees own pending proposal ====="
curl -s -b $LJ $B/api/cases/$CID1 | python3 -c "import json,sys; d=json.load(sys.stdin); print('my_proposal:',d['my_proposal']['status'],'| note kept:',d['my_proposal']['note']=='سابقه‌ی مشابه زیاد؛ می‌توانم زودتر شروع کنم.')"

echo "===== 7) lawyer edits + lists own proposals ====="
curl -s -b $LJ -X PATCH $B/api/proposals/$PID -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $LC" -d '{"amount":7200000,"days":22,"note":"با تخفیف"}' -w " [%{http_code}]\n"
curl -s -b $LJ "$B/api/proposals" | python3 -c "import json,sys; d=json.load(sys.stdin); print('my proposals:',[(r['case_id'],r['amount'],r['status']) for r in d['rows']])"

echo "===== 8) admin detail of case $CID1 (sees note + client) ====="
curl -s -b $AJ $B/api/cases/$CID1 | python3 -c "
import json,sys; d=json.load(sys.stdin)
p=d['proposals'][0]
print('client:',d['client_name'],d['client_phone'],'| proposal note:',p['note'])
assert p['note']=='با تخفیف','DECRYPT MISMATCH'
print('DECRYPT OK')"

echo "===== 9) negative: client cannot accept (403) ====="
curl -s -o /dev/null -w "[%{http_code}]\n" -b $CJ -X POST $B/api/proposals/$PID/accept -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC"
echo "===== 9b) admin accepts → case assigned ====="
curl -s -b $AJ -X POST $B/api/proposals/$PID/accept -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -w " [%{http_code}]\n"
curl -s -b $AJ $B/api/cases/$CID1 | python3 -c "
import json,sys; d=json.load(sys.stdin)
print('status:',d['status'],'| final_price:',d['final_price'],'| lawyer:',d['lawyer_name'])
assert d['status']=='assigned' and d['final_price']==7200000
ps=d['proposals']; assert ps[0]['status']=='accepted'
print('ASSIGN OK')"

echo "===== 10) lawyer scope=mine now sees the case ====="
curl -s -b $LJ "$B/api/cases?scope=mine" | python3 -c "import json,sys; d=json.load(sys.stdin); print('mine total:',d['total'],[ (r['id'],r['status']) for r in d['rows']])"

echo "===== 11) admin sets final price manually ====="
curl -s -b $AJ -X PATCH $B/api/cases/$CID1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"final_price":7000000}' -w " [%{http_code}]\n"
echo "===== 11b) lawyer proposes on case $CID2 then deletes it → back to waiting ====="
PROP2=$(curl -s -b $LJ -X POST $B/api/cases/$CID2/proposals -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $LC" -d '{"amount":9000000,"days":15,"note":"x"}')
PID2=$(echo "$PROP2" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
curl -s -b $LJ -X DELETE $B/api/proposals/$PID2 -H "Origin: $B" -H "x-csrf-token: $LC" -w " [del %{http_code}]\n"
curl -s -b $CJ $B/api/cases/$CID2 | python3 -c "import json,sys; d=json.load(sys.stdin); print('case2 status after delete:',d['status']); assert d['status']=='waiting'"

echo "===== 12) audit log entries ====="
curl -s -o /dev/null -w "audit visible via DB only [%{http_code}]\n" $B/api/health
node -e "
const {db}=require('./lib/db.pg');
(async()=>{const r=await db.prepare(\"SELECT action,COUNT(*) n FROM audit_log WHERE action IN('case_create','proposal_create','proposal_edit','proposal_delete','proposal_accept','case_final_price') GROUP BY action ORDER BY action\").all();
console.log(r);process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"

echo "===== 13) pagination sanity (page beyond range) ====="
curl -s -b $CJ "$B/api/cases?page=99" | python3 -c "import json,sys; d=json.load(sys.stdin); print('page:',d['page'],'pages:',d['pages'],'rows:',len(d['rows']))"

kill $SRV 2>/dev/null || true
echo "===== ALL CYCLE TESTS DONE ====="
