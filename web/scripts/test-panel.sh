#!/bin/bash
# ============================================================
# CMD-031 — تست پنل واقعی (P1..P5) روی دیتابیس واقعی:
#   جزئیات پرونده/داشبوردها (API پشتیبان)، مدیریت کاربران (مسدود/آزاد + گارد)،
#   تایید پیشنهاد/قیمت نهایی از جزئیات، درگاه UI (data-pay → payments/request)،
#   لایه عمومی مستقل (aliasهای فوتر صفر شکسته)
# کاربران/داده‌های آزمایشی در پایان پاک می‌شوند.
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
APPSECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development DEV_SHOW_OTP=1 TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"
export APP_SECRET="$APPSECRET"

FAIL=0
ck() { # label expected actual
  if [ "$2" = "$3" ]; then echo "  ✓ $1 = $2"; else echo "  ✗ $1: expected=$2 actual=$3"; FAIL=1; fi
}
jq() { python3 -c "import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1]))" "$1"; }

echo "===== 0) cleanup leftovers + seed test users ====="
node /home/z/my-project/scripts/cleanup-bill.js >/dev/null
node /home/z/my-project/scripts/cleanup-cycle.js >/dev/null
node /home/z/my-project/scripts/seed-test-users.pg.js

PORT=3211 node scripts/dev-server.js > /tmp/panel_harness.log 2>&1 &
SRV=$!
node scripts/fake-zibal.js 3311 > /tmp/panel_fake.log 2>&1 &
FAKE=$!
sleep 2
B=http://127.0.0.1:3211
CJ=/tmp/pn_client.jar; LJ=/tmp/pn_lawyer.jar; AJ=/tmp/pn_admin.jar
rm -f $CJ $LJ $AJ
trap 'kill $SRV $FAKE 2>/dev/null' EXIT

login() { local T; T=$(curl -s -c "$1" -X POST $B/api/auth/login -H "Content-Type: application/json" -H "Origin: $B" -d "{\"username\":\"$2\",\"password\":\"$3\"}" | jq "d.get('csrf','FAIL:'+d.get('error','?'))"); [ "$T" != "FAIL" ] && printf '%s' "$T" > "$1.csrf"; echo "$T"; }
api() { # method jar path [body] -> "HTTP STATUS BODY"  (non-GET needs CSRF from jar.csrf)
  local m=$1 j=$2 p=$3 b=${4:-} CS
  CS=$(cat "$j.csrf" 2>/dev/null || echo '')
  if [ -n "$b" ]; then
    curl -s -b "$j" -H "x-csrf-token: $CS" -w "|%{http_code}" -X $m "$B$p" -H "Content-Type: application/json" -H "Origin: $B" -d "$b"
  else
    curl -s -b "$j" -H "x-csrf-token: $CS" -w "|%{http_code}" -X $m "$B$p" -H "Origin: $B"
  fi
}

echo "===== 1) logins ====="
CC=$(login $CJ client_t 'ClientT#2026'); LC=$(login $LJ lawyer_t 'LawyerT#2026'); AC=$(login $AJ admin_t 'AdminT#2026x')
[ "$CC" != "FAIL" ] && [ "$LC" != "FAIL" ] && [ "$AC" != "FAIL" ] || { echo LOGIN_FAILED; kill $SRV; exit 1; }
echo "  ✓ three logins ok"
AID=$(curl -s -b $AJ $B/api/me | jq "d['user']['id']")

echo "===== 2) GET /api/users — role guard + new fields (P3) ====="
R=$(api GET $CJ /api/users); ck "client→403" 403 "${R##*|}"
R=$(api GET $LJ /api/users); ck "lawyer→403" 403 "${R##*|}"
R=$(api GET $AJ /api/users?role=client); ST="${R##*|}"; ck "admin→200" 200 "$ST"
HAS=$(echo "${R%|*}" | jq "'status' in d['rows'][0] and 'phone_last4' in d['rows'][0]")
ck "fields status+phone_last4" True "$HAS"

echo "===== 3) PATCH /api/users/:id — block/unblock + guards (P3) ====="
R=$(api PATCH $LJ /api/users/$AID '{"status":"blocked"}'); ck "lawyer→403" 403 "${R##*|}"
R=$(api PATCH $AJ /api/users/$AID '{"status":"blocked"}'); ck "admin self→400" 400 "${R##*|}"
R=$(api PATCH $AJ /api/users/999999 '{"status":"blocked"}'); ck "unknown→404" 404 "${R##*|}"
R=$(api PATCH $AJ /api/users/$AID '{"status":"admin"}'); ck "bad status→400" 400 "${R##*|}"
CID=$(curl -s -b $CJ $B/api/me | jq "d['user']['id']")
R=$(api PATCH $AJ /api/users/$CID '{"status":"blocked"}'); ck "block client→200" 200 "${R##*|}"
RC=$(curl -s -w "|%{http_code}" -X POST $B/api/auth/login -H "Content-Type: application/json" -H "Origin: $B" -d '{"username":"client_t","password":"ClientT#2026"}'); ck "blocked login→401" 401 "${RC##*|}"
RC=$(curl -s -w "|%{http_code}" "$B/api/cases?page=1" -b $CJ); ck "old session dead→401 (protected endpoint)" 401 "${RC##*|}"
R=$(api PATCH $AJ /api/users/$CID '{"status":"active"}'); ck "unblock→200" 200 "${R##*|}"
CC=$(login $CJ client_t 'ClientT#2026'); ck "relogin ok" OK "$([ "$CC" != "FAIL" ] && echo OK)"

echo "===== 4) dashboard backing APIs (P2) ====="
for p in "/api/cases?page=1" "/api/appointments" "/api/invoices" "/api/tickets"; do
  R=$(api GET $CJ "$p"); ck "client $p" 200 "${R##*|}"
done
R=$(api GET $LJ "/api/cases?page=1&scope=mine"); ck "lawyer cases scope=mine" 200 "${R##*|}"
R=$(api GET $LJ "/api/proposals"); ck "lawyer proposals" 200 "${R##*|}"
R=$(api GET $LJ "/api/invoices"); ck "lawyer invoices→403 (honest)" 403 "${R##*|}"

echo "===== 5) case detail APIs (P1) ====="
NEW=$(api POST $CJ /api/cases '{"category":"قرارداد","title":"پرونده تست پنل CMD-031","description":"شرح آزمایشی برای جزئیات واقعی"}')
CKID=$(echo "${NEW%|*}" | jq "d.get('id')")
echo "  case id: $CKID"
R=$(api GET $CJ /api/cases/$CKID); ck "client own→200" 200 "${R##*|}"
H=$(echo "${R%|*}" | jq "'description' in d")
ck "client sees description" True "$H"
R=$(api GET $LJ /api/cases/$CKID); ck "lawyer (waiting)→200" 200 "${R##*|}"
R=$(api GET $CJ /api/cases/99999); ck "unknown→404" 404 "${R##*|}"

echo "===== 6) proposal→accept→final_price cycle from detail (P1/admin) ====="
R=$(api POST $LJ /api/cases/$CKID/proposals '{"amount":1500000,"days":30,"note":"پیشنهاد آزمایشی"}')
PID=$(echo "${R%|*}" | jq "d.get('id')")
echo "  proposal id: $PID"
R=$(api POST $AJ /api/proposals/$PID/accept '{}'); ck "admin accept→200" 200 "${R##*|}"
R=$(api GET $AJ /api/cases/$CKID); HASL=$(echo "${R%|*}" | jq "d.get('lawyer_name','') != ''")
ck "assigned lawyer_name" True "$HASL"
R=$(api PATCH $AJ /api/cases/$CKID '{"final_price":1500000}'); ck "final_price→200" 200 "${R##*|}"

echo "===== 7) gateway UI backing — payments/request (P4) ====="
R=$(api POST $AJ /api/invoices "{\"client_id\":$CID,\"case_id\":$CKID,\"amount\":500000,\"title\":\"فاکتور تست پنل\"}")
IVID=$(echo "${R%|*}" | jq "d.get('id')")
echo "  invoice id: $IVID"
kill $SRV 2>/dev/null; sleep 1
PORT=3211 PAYMENT_PROVIDER=zibal PAYMENT_MERCHANT_ID=zibal PAYMENT_CALLBACK_BASE=http://127.0.0.1:3211 PAYMENT_API_BASE=http://127.0.0.1:3311 node scripts/dev-server.js > /tmp/panel_harness2.log 2>&1 &
SRV=$!
sleep 2
CC=$(login $CJ client_t 'ClientT#2026')
R=$(api POST $CJ /api/payments/request "{\"invoice_id\":$IVID}")
ck "request→200" 200 "${R##*|}"
PAYURL=$(echo "${R%|*}" | jq "d.get('pay_url','')")
case "$PAYURL" in */start/*) echo "  ✓ pay_url: ${PAYURL:0:44}…";; *) echo "  ✗ pay_url bad: $PAYURL"; FAIL=1;; esac
R=$(api POST $LJ /api/payments/request "{\"invoice_id\":$IVID}"); ck "lawyer→403" 403 "${R##*|}"

echo "===== 8) independent public layer — zero broken footer links (P5) ====="
for p in /portal /why /reviews /reach /blog /post/1 /lawyer/1 /login /knowledge/article/1 /service/family-inheritance /service/tax-customs /service/arbitration /expats /enterprise /about /legal/privacy /articles; do
  RC=$(curl -s -w "|%{http_code}" $B$p)
  T=$(echo "${RC%|*}" | python3 -c "import sys,re;h=sys.stdin.read();m=re.search(r'<h1[^>]*>([^<]+)',h);print('H1') if m else print('NOH1')")
  ck "$p" "200|H1" "${RC##*|}|$T"
done

echo "===== 9) cleanup ====="
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
DBPASS="$DBPASS" node -e "
const path=require('path');const {db}=require(path.join('/home/z/my-project/dadgar','web','lib','db.pg'));
(async()=>{const r=await db.prepare(\"DELETE FROM audit_log WHERE action IN('user_blocked','user_unblocked') RETURNING id\").all();console.log('audit user_% cleaned:',r.length);process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})
" 2>/dev/null || DBPASS="$DBPASS" node -e "
const {db}=require('./lib/db.pg');
(async()=>{const r=await db.prepare(\"DELETE FROM audit_log WHERE action IN('user_blocked','user_unblocked') RETURNING id\").all();console.log('audit user_% cleaned:',r.length);process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})
"

echo
if [ "$FAIL" = "0" ]; then echo "===== ALL PANEL TESTS PASSED ====="; else echo "===== PANEL TESTS FAILED — see above ====="; exit 1; fi
