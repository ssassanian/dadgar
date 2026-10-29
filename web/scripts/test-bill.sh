#!/bin/bash
# ============================================================
# CMD-005 — تست ماژول مالی (فاز ۳ گام ۳) روی دیتابیس واقعی
# هارنس محلی web/ + Supabase؛ کاربران و فاکتورهای آزمایشی بعداً پاک می‌شوند.
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
APPSECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development DEV_SHOW_OTP=1 TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"
export APP_SECRET="$APPSECRET"

echo "===== 0) cleanup leftovers + seed test users ====="
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node /home/z/my-project/scripts/seed-test-users.pg.js

PORT=3201 node scripts/dev-server.js > /tmp/bill_harness.log 2>&1 &
SRV=$!
sleep 2
B=http://127.0.0.1:3201
CJ=/tmp/bl_client.jar; LJ=/tmp/bl_lawyer.jar; AJ=/tmp/bl_admin.jar
rm -f $CJ $LJ $AJ
trap 'kill $SRV 2>/dev/null' EXIT

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

echo "===== 2) client GET invoices (empty) + clock sanity ====="
curl -s -b $CJ $B/api/invoices | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['rows']==[], d
assert 1<=d['today_d']<=31 and abs(d['now']-__import__('time').time())<120,'clock sanity'
print('ok | today_d:',d['today_d'])"

echo "===== 3) lawyer GET invoices → 403 (صفحه مالی وکیل وجود ندارد) ====="
curl -s -o /dev/null -w "[lawyer-GET %{http_code}]\n" -b $LJ $B/api/invoices

echo "===== 4) admin users list: minimal fields only ====="
curl -s -b $AJ "$B/api/users?role=client" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and len(d['rows'])==1, d
r=d['rows'][0]
assert set(r.keys())=={'id','name','role','created_at'}, r
assert r['name']=='مشتری تست چرخه' and r['role']=='client'
print('users minimal OK | no phone/email/username leak:', all(k not in r for k in ('phone','email','username','password_hash')))"
curl -s -o /dev/null -w "guest-users [%{http_code}]\n" "$B/api/users?role=client"
curl -s -o /dev/null -w "lawyer-users [%{http_code}]\n" -b $LJ "$B/api/users?role=client"
curl -s -o /dev/null -w "bad-role    [%{http_code}]\n" -b $AJ "$B/api/users?role=hacker"

echo "===== 5) admin POST negatives ====="
curl -s -o /dev/null -w "client-0     [%{http_code}]\n" -b $AJ -X POST $B/api/invoices -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"client_id":0,"amount":5000000}'
curl -s -o /dev/null -w "amount-low   [%{http_code}]\n" -b $AJ -X POST $B/api/invoices -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"client_id":1,"amount":500}'
curl -s -w " [%{http_code}]\n" -b $AJ -X POST $B/api/invoices -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"client_id":999999999,"amount":5000000}' | python3 -c "
import sys; t=sys.stdin.read(); assert 'مشتری یافت نشد' in t and '[404]' in t, t; print('missing client → 404 with anti-enumeration message')"
ADMID=$(curl -s -b $AJ $B/api/me | python3 -c "import json,sys; print(json.load(sys.stdin)['user']['id'])")
curl -s -o /dev/null -w "admin-as-client [%{http_code}]\n" -b $AJ -X POST $B/api/invoices -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d "{\"client_id\":$ADMID,\"amount\":5000000}"
curl -s -o /dev/null -w "case-mismatch  [%{http_code}]\n" -b $AJ -X POST $B/api/invoices -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"client_id":1,"amount":5000000,"case_id":999999999}'

echo "===== 6) get test client id ====="
CID=$(curl -s -b $AJ "$B/api/users?role=client" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['rows'][0]['id'])")
echo "client id: $CID"

echo "===== 7) admin issues two manual invoices ====="
INV1=$(curl -s -b $AJ -X POST $B/api/invoices -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d "{\"client_id\":$CID,\"amount\":5000000}")
echo "$INV1"
I1=$(echo "$INV1" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
I2=$(curl -s -b $AJ -X POST $B/api/invoices -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d "{\"client_id\":$CID,\"amount\":3000000}" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
echo "invoice ids: $I1 / $I2"

echo "===== 8) client sees own invoices; no admin-only fields ====="
curl -s -b $CJ $B/api/invoices | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==2, d
r=d['rows'][0]
assert set(r.keys())=={'id','amount','status','created_at','paid_at','case_id'}, r
assert r['status']=='pending' and r['paid_at'] is None and r['case_id'] is None
assert 'client_name' not in r
print('client rows OK | privacy OK')"

echo "===== 9) admin sees names ====="
curl -s -b $AJ $B/api/invoices | python3 -c "
import json,sys; d=json.load(sys.stdin)
r=[x for x in d['rows'] if x['case_id'] is None][0]
assert r['client_name']=='مشتری تست چرخه' and r['lawyer_name']=='', r
print('admin names OK | lawyer_name empty for manual invoice')"

echo "===== 10) case-linked invoice (چرخه پرونده → فاکتور) ====="
ccid=$(curl -s -b $CJ -X POST $B/api/cases -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"category":"ملکی","title":"تست مالی — اختلاف اجاره","description":"برای تست اتصال فاکتور به پرونده"}' | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
cpid=$(curl -s -b $LJ -X POST $B/api/cases/$ccid/proposals -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $LC" -d '{"amount":7000000,"days":20,"note":"تست"}' | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
curl -s -o /dev/null -w "accept [%{http_code}]\n" -b $AJ -X POST $B/api/proposals/$cpid/accept -H "Origin: $B" -H "x-csrf-token: $AC"
I3=$(curl -s -b $AJ -X POST $B/api/invoices -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d "{\"client_id\":$CID,\"amount\":7000000,\"case_id\":$ccid}" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
curl -s -b $AJ $B/api/invoices | python3 -c "
import json,sys; d=json.load(sys.stdin)
r=[x for x in d['rows'] if x['id']==$I3][0]
assert r['lawyer_name']=='وکیل تست چرخه' and r['case_id']==$ccid, r
print('case-linked invoice OK | lawyer_name from case:', r['lawyer_name'])"

echo "===== 11) PATCH flows ====="
curl -s -o /dev/null -w "client-patch  [%{http_code}]\n" -b $CJ -X PATCH $B/api/invoices/$I1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"status":"paid"}'
curl -s -o /dev/null -w "lawyer-patch  [%{http_code}]\n" -b $LJ -X PATCH $B/api/invoices/$I1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $LC" -d '{"status":"paid"}'
curl -s -o /dev/null -w "bad-status    [%{http_code}]\n" -b $AJ -X PATCH $B/api/invoices/$I1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"status":"refunded"}'
curl -s -b $AJ -X PATCH $B/api/invoices/$I1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"status":"paid"}' -w " [%{http_code}]\n" | tail -c 12
curl -s -b $CJ $B/api/invoices | python3 -c "
import json,sys,time; d=json.load(sys.stdin)
r=[x for x in d['rows'] if x['status']=='paid'][0]
assert r['paid_at'] and abs(r['paid_at']-time.time())<120, r
print('paid OK with paid_at set')"
curl -s -o /dev/null -w "double-paid   [%{http_code}]\n" -b $AJ -X PATCH $B/api/invoices/$I1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"status":"paid"}'
curl -s -o /dev/null -w "reopen-nonpaid[%{http_code}]\n" -b $AJ -X PATCH $B/api/invoices/$I2 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"status":"pending"}'
curl -s -o /dev/null -w "reopen-paid   [%{http_code}]\n" -b $AJ -X PATCH $B/api/invoices/$I1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"status":"pending"}'
curl -s -b $CJ $B/api/invoices | python3 -c "
import json,sys; d=json.load(sys.stdin)
r=[x for x in d['rows'] if x['id']==$I1][0]
assert r['status']=='pending' and r['paid_at'] is None, r
print('reopen OK — back to pending, paid_at cleared')"
curl -s -o /dev/null -w "missing-inv   [%{http_code}]\n" -b $AJ -X PATCH $B/api/invoices/999999999 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"status":"paid"}'

echo "===== 12) security: no-csrf → 403, guest → 401 ====="
curl -s -o /dev/null -w "no-csrf [%{http_code}]\n" -b $AJ -X POST $B/api/invoices -H "Content-Type: application/json" -H "Origin: $B" -d "{\"client_id\":$CID,\"amount\":5000000}"
curl -s -o /dev/null -w "guest-GET    [%{http_code}]\n" $B/api/invoices
curl -s -o /dev/null -w "guest-PATCH  [%{http_code}]\n" -X PATCH $B/api/invoices/$I1 -H "Content-Type: application/json" -H "Origin: $B" -d '{"status":"paid"}'

echo "===== 13) audit log entries ====="
node -e "
const {db}=require('./lib/db.pg');
(async()=>{const r=await db.prepare(\"SELECT action,COUNT(*) n FROM audit_log WHERE action LIKE 'invoice%' GROUP BY action ORDER BY action\").all();
console.log(r);const m=Object.fromEntries(r.map(x=>[x.action,x.n]));
if(+m.invoice_create!==3||+m.invoice_mark_paid!==1||+m.invoice_reopen!==1) throw new Error('audit mismatch');
console.log('AUDIT OK');process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"

echo "===== 14) cleanup + zero invoices left ====="
kill $SRV 2>/dev/null
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node -e "
const {db}=require('./lib/db.pg');
(async()=>{const n=(await db.prepare('SELECT COUNT(*) c FROM invoices').get()).c;
console.log('invoices left:',n);if(+n!==0) throw new Error('invoices not cleaned');process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"

echo "ALL API BILL TESTS PASSED"
