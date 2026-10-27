#!/bin/bash
# ============================================================
# CMD-004 — تست نوبت‌دهی (فاز ۳ گام ۲) روی دیتابیس واقعی
# هارنس محلی web/ + Supabase؛ کاربران و نوبت‌های آزمایشی بعداً پاک می‌شوند.
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
APPSECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development DEV_SHOW_OTP=1 TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"
export APP_SECRET="$APPSECRET"

echo "===== 0) cleanup leftovers + clear book rate keys + seed test users ====="
node /home/z/my-project/scripts/cleanup-cycle.js
node -e "const {db}=require('./lib/db.pg');(async()=>{await db.prepare(\"DELETE FROM rate_limits WHERE key LIKE 'book:%'\").run();console.log('book rate keys cleared');process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"
node /home/z/my-project/scripts/seed-test-users.pg.js

PORT=3201 node scripts/dev-server.js > /tmp/book_harness.log 2>&1 &
SRV=$!
sleep 2
B=http://127.0.0.1:3201
CJ=/tmp/b_client.jar; LJ=/tmp/b_lawyer.jar; AJ=/tmp/b_admin.jar
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

echo "===== 2) client GET appointments (empty) ====="
curl -s -b $CJ $B/api/appointments | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['rows']==[] and d['taken']==[], d
print('ok | today_d:',d['today_d'],'| now:',d['now'])
assert 1<=d['today_d']<=31 and abs(d['now']-__import__('time').time())<120,'clock sanity'"

echo "===== 3) negatives: invalid slot/kind/day/past (همه 400 — قبل از سهمیه‌های بعدی) ====="
curl -s -o /dev/null -w "bad-slot  [%{http_code}]\n" -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":11,"slot":"۰۸:۰۰","kind":"حضوری"}'
curl -s -o /dev/null -w "bad-kind  [%{http_code}]\n" -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":11,"slot":"۱۰:۳۰","kind":"واتساپ"}'
curl -s -o /dev/null -w "day-0     [%{http_code}]\n" -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":0,"slot":"۱۰:۳۰","kind":"حضوری"}'
curl -s -o /dev/null -w "day-31    [%{http_code}]\n" -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":31,"slot":"۱۰:۳۰","kind":"حضوری"}'
curl -s -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":3,"slot":"۱۶:۰۰","kind":"حضوری"}' -w " [past %{http_code}]\n" | python3 -c "
import sys; t=sys.stdin.read()
assert '[past 400]' in t, t
print('past rejected with message:', 'گذشته' in t)"
# تست‌های منفی سهمیه‌ی نرخ را مصرف کرده‌اند — برای ادامه پاک می‌شود
clearbook() { node -e "const {db}=require('./lib/db.pg');(async()=>{await db.prepare(\"DELETE FROM rate_limits WHERE key LIKE 'book:%'\").run();process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"; }
clearbook

echo "===== 3b) client books day=10 ۰۹:۰۰ حضوری ====="
R1=$(curl -s -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" \
  -d '{"day":10,"slot":"۰۹:۰۰","kind":"حضوری"}')
echo "$R1"
AID1=$(echo "$R1" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
echo "appointment id: $AID1"

echo "===== 3c) duplicate same slot → 409 ====="
curl -s -o /dev/null -w "[%{http_code}]\n" -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":10,"slot":"۰۹:۰۰","kind":"آنلاین"}'

echo "===== 4) client list → 1 row booked day10; taken marked ====="
curl -s -b $CJ $B/api/appointments | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==1, d
r=d['rows'][0]
print('row:',{k:r[k] for k in ('id','day','slot','kind','status')})
assert r['day']==10 and r['slot']=='۰۹:۰۰' and r['kind']=='حضوری' and r['status']=='booked'
assert d['taken']==[{'d':10,'j':'۰۹:۰۰'}], d['taken']
assert 'client_name' not in r and 'client_id' not in r
print('TAKEN OK + no extra fields for client')"

echo "===== 5) lawyer view: anonymous client + privacy ====="
curl -s -b $LJ $B/api/appointments | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==1, d
r=d['rows'][0]
print('lawyer sees client_id:',r.get('client_id'),'| leaks name:', 'client_name' in r)
assert 'client_name' not in r and r['client_id']>0
print('PRIVACY OK')"

echo "===== 6) negative: lawyer cannot book/patch (403) ====="
curl -s -o /dev/null -w "lawyer-POST   [%{http_code}]\n" -b $LJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $LC" -d '{"day":12,"slot":"۱۲:۰۰","kind":"تلفنی"}'
curl -s -o /dev/null -w "lawyer-PATCH  [%{http_code}]\n" -b $LJ -X PATCH $B/api/appointments/$AID1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $LC" -d '{"status":"confirmed"}'

echo "===== 7) admin: sees names + confirm ====="
curl -s -b $AJ $B/api/appointments | python3 -c "
import json,sys; d=json.load(sys.stdin)
r=d['rows'][0]
print('admin row client:',r['client_name'],'| lawyer:',repr(r['lawyer_name']))
assert r['client_name']=='مشتری تست چرخه' and r['lawyer_name']=='', r"
curl -s -b $AJ -X PATCH $B/api/appointments/$AID1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"status":"confirmed"}' -w " [%{http_code}]\n"
echo "===== 7b) double confirm → 400 ====="
curl -s -o /dev/null -w "[%{http_code}]\n" -b $AJ -X PATCH $B/api/appointments/$AID1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"status":"confirmed"}'
echo "===== 7c) client sees confirmed ====="
curl -s -b $CJ $B/api/appointments | python3 -c "import json,sys; d=json.load(sys.stdin); print('status:',d['rows'][0]['status']); assert d['rows'][0]['status']=='confirmed'"

echo "===== 8) client cancels own → hidden from own list, visible to admin ====="
curl -s -b $CJ -X PATCH $B/api/appointments/$AID1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"status":"canceled"}' -w " [%{http_code}]\n"
curl -s -b $CJ $B/api/appointments | python3 -c "import json,sys; d=json.load(sys.stdin); print('client rows after cancel:',len(d['rows']),'| taken:',len(d['taken'])); assert d['rows']==[] and d['taken']==[]"
curl -s -b $AJ $B/api/appointments | python3 -c "import json,sys; d=json.load(sys.stdin); r=d['rows'][0]; print('admin sees canceled:',r['status']); assert r['status']=='canceled'"
echo "===== 8b) client cannot confirm (403) / admin cannot re-cancel canceled (400) ====="
curl -s -o /dev/null -w "client-confirm [%{http_code}]\n" -b $CJ -X PATCH $B/api/appointments/$AID1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"status":"confirmed"}'
curl -s -o /dev/null -w "admin-recancel [%{http_code}]\n" -b $AJ -X PATCH $B/api/appointments/$AID1 -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"status":"canceled"}'

echo "===== 9) slot freed after cancel → re-book OK + rate limit 5/hour ====="
clearbook
R2=$(curl -s -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":10,"slot":"۰۹:۰۰","kind":"آنلاین"}')
echo "$R2"
curl -s -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":20,"slot":"۱۰:۳۰","kind":"تلفنی"}' -o /dev/null -w "book#2 [%{http_code}]\n"
curl -s -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":20,"slot":"۱۲:۰۰","kind":"تلفنی"}' -o /dev/null -w "book#3 [%{http_code}]\n"
curl -s -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":20,"slot":"۱۶:۰۰","kind":"تلفنی"}' -o /dev/null -w "book#4 [%{http_code}]\n"
curl -s -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":20,"slot":"۱۷:۳۰","kind":"تلفنی"}' -o /dev/null -w "book#5 [%{http_code}]\n"
curl -s -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $CC" -d '{"day":21,"slot":"۰۹:۰۰","kind":"تلفنی"}' -o /dev/null -w "book#6 (expect 429) [%{http_code}]\n"

echo "===== 10) security: no-csrf → 403, guest → 401 ====="
curl -s -o /dev/null -w "no-csrf [%{http_code}]\n" -b $CJ -X POST $B/api/appointments -H "Content-Type: application/json" -H "Origin: $B" -d '{"day":21,"slot":"۱۷:۳۰","kind":"حضوری"}'
curl -s -o /dev/null -w "guest   [%{http_code}]\n" $B/api/appointments

echo "===== 11) audit log entries ====="
node -e "
const {db}=require('./lib/db.pg');
(async()=>{const r=await db.prepare(\"SELECT action,COUNT(*) n FROM audit_log WHERE action LIKE 'appointment%' GROUP BY action ORDER BY action\").all();
console.log(r);const m=Object.fromEntries(r.map(x=>[x.action,x.n]));
if(+m.appointment_create!==6||+m.appointment_confirm!==1||+m.appointment_cancel!==1){console.error('AUDIT MISMATCH');process.exit(1)}
console.log('AUDIT OK');process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"

kill $SRV 2>/dev/null || true
echo "===== 12) final cleanup: test data + rate keys ====="
node /home/z/my-project/scripts/cleanup-cycle.js
node -e "const {db}=require('./lib/db.pg');(async()=>{await db.prepare(\"DELETE FROM rate_limits WHERE key LIKE 'book:%'\").run();const n=(await db.prepare('SELECT COUNT(*) c FROM appointments').get()).c;console.log('appointments left in DB:',n);process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"
echo "===== ALL BOOKING API TESTS DONE ====="
