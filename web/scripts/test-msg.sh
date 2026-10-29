#!/bin/bash
# ============================================================
# CMD-007 — تست ماژول پیام/تیکت (فاز ۳ گام ۵) روی دیتابیس واقعی
# هارنس محلی web/ + Supabase؛ کاربران و داده‌های آزمایشی در پایان پاک می‌شوند.
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
APPSECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development DEV_SHOW_OTP=1 TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"
export APP_SECRET="$APPSECRET"

echo "===== 0) cleanup leftovers + seed test users ====="
node /home/z/my-project/scripts/cleanup-msg.js
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node /home/z/my-project/scripts/seed-test-users.pg.js

PORT=3205 node scripts/dev-server.js > /tmp/msg_harness.log 2>&1 &
SRV=$!
sleep 2
B=http://127.0.0.1:3205
CJ=/tmp/ms_client.jar; LJ=/tmp/ms_lawyer.jar; AJ=/tmp/ms_admin.jar
rm -f $CJ $LJ $AJ
trap 'kill $SRV 2>/dev/null' EXIT

login() { # jar user pass -> csrf
  curl -s -c "$1" -X POST $B/api/auth/login -H "Content-Type: application/json" -H "Origin: $B" \
    -d "{\"username\":\"$2\",\"password\":\"$3\"}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('csrf','FAIL:'+d.get('error','?')))"
}
apic() { # jar method path csrf [json]
  local m=$2 p=$3
  if [ "$m" = "GET" ]; then curl -s -b "$1" "$B$p"
  else curl -s -b "$1" -X "$m" "$B$p" -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $4" ${5:+-d "$5"}; fi
}

echo "===== 1) logins (client/lawyer/admin) ====="
CC=$(login $CJ client_t 'ClientT#2026'); echo "client csrf: ${CC:0:8}…"
LC=$(login $LJ lawyer_t 'LawyerT#2026'); echo "lawyer csrf: ${LC:0:8}…"
AC=$(login $AJ admin_t 'AdminT#2026x'); echo "admin csrf: ${AC:0:8}…"
[ "$CC" != "FAIL" ] && [ "$LC" != "FAIL" ] && [ "$AC" != "FAIL" ] || { echo LOGIN_FAILED; kill $SRV; exit 1; }

echo "===== 2) guest: tickets/threads/messages → 401 ====="
curl -s -o /dev/null -w "guest-tickets [%{http_code}]\n" $B/api/tickets
curl -s -o /dev/null -w "guest-threads [%{http_code}]\n" $B/api/threads
curl -s -o /dev/null -w "guest-messages [%{http_code}]\n" "$B/api/messages?case_id=1"

echo "===== 3) empty lists (all roles) ====="
apic $CJ GET /api/tickets | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['rows']==[], d; print('ok | client tickets empty')"
apic $LJ GET /api/tickets | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['rows']==[], d; print('ok | lawyer tickets empty')"
apic $AJ GET /api/tickets | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['rows']==[], d; print('ok | admin tickets empty')"
apic $CJ GET /api/threads | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['rows']==[], d; print('ok | client threads empty')"
curl -s -b $AJ "$B/api/threads" -o /dev/null -w "admin-threads [%{http_code}] (403 مورد انتظار)\n"

echo "===== 4) create ticket: validation ====="
apic $CJ POST /api/tickets "$CC" '{"subject":"ab","dept":"فنی","priority":"بالا","body":"متن تست"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'موضوع' in d.get('error',''), d; print('ok | short subject rejected')"
apic $CJ POST /api/tickets "$CC" '{"subject":"موضوع تست","dept":"فوتبول","priority":"بالا","body":"متن تست"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'بخش' in d.get('error',''), d; print('ok | invalid dept rejected')"
apic $CJ POST /api/tickets "$CC" '{"subject":"موضوع تست","dept":"فنی","priority":"خیلی بالا","body":"متن تست"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'اولویت' in d.get('error',''), d; print('ok | invalid priority rejected')"
apic $CJ POST /api/tickets "$CC" '{"subject":"موضوع تست","dept":"فنی","priority":"بالا","body":"   "}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'متن' in d.get('error','') or 'مقدار' in d.get('error',''), d; print('ok | empty body rejected')"
curl -s -o /dev/null -w "admin-POST-tickets [%{http_code}] (403 مورد انتظار)\n" -b $AJ -X POST $B/api/tickets -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $AC" -d '{"subject":"تست مدیر","dept":"فنی","priority":"بالا","body":"مدیر نباید تیکت بسازد"}'
curl -s -o /dev/null -w "no-csrf-POST [%{http_code}]\n" -b $CJ -X POST $B/api/tickets -H "Content-Type: application/json" -H "Origin: $B" -d '{"subject":"بی‌سی‌اس‌آراف","dept":"فنی","priority":"بالا","body":"بدون توکن"}'

echo "===== 5) client creates real ticket ====="
T1=$(apic $CJ POST /api/tickets "$CC" '{"subject":"خطا در بارگذاری فایل پرونده","dept":"فنی","priority":"بالا","body":"سلام، فایل پرونده بارگذاری نمی\u200cشود. لطفاً بررسی کنید."}' | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
echo "ticket_id=$T1"
L1=$(apic $LJ POST /api/tickets "$LC" '{"subject":"استعلام صورتحساب تسویه","dept":"مالی","priority":"متوسط","body":"برای پرونده‌ی قبلی صورتحساب تسویه می\u200cخواهم."}' | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
echo "lawyer_ticket_id=$L1"

echo "===== 6) lists: owner scoping + admin sees names ====="
apic $CJ GET /api/tickets | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==1 and d['rows'][0]['status']=='open' and d['rows'][0]['msg_count']==1, d
assert 'user_name' not in d['rows'][0], 'NAME LEAK TO CLIENT'
print('ok | client sees own ticket, msg_count=1, no user_name')"
apic $LJ GET /api/tickets | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==1 and d['rows'][0]['dept']=='مالی', d
print('ok | lawyer sees own ticket only')"
apic $AJ GET /api/tickets | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==2, d
names=sorted(r['user_name'] for r in d['rows'])
assert names==['مشتری تست چرخه','وکیل تست چرخه'], names
print('ok | admin sees both tickets with names')"

echo "===== 7) detail: access + privacy ====="
apic $CJ GET /api/tickets/$T1 | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and len(d['rows'])==1 and d['rows'][0]['mine']==True and d['rows'][0]['body'].startswith('سلام'), d
assert d['ticket']['user_name']=='', d
raw=json.dumps(d,ensure_ascii=False)
assert 'مشتری تست چرخه' not in raw, 'NAME LEAK IN DETAIL'
print('ok | owner detail: mine=true, no names')"
curl -s -o /dev/null -w "foreign-detail(lawyer→client ticket) [%{http_code}] (404 مورد انتظار)\n" -b $LJ "$B/api/tickets/$T1"
apic $CJ GET /api/tickets/987654 | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('error')=='تیکت یافت نشد.', d; print('ok | 404 anti-leak')"
apic $AJ GET /api/tickets/$T1 | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ticket']['user_name']=='مشتری تست چرخه' and d['rows'][0]['name']=='مشتری تست چرخه', d
print('ok | admin detail: names visible')"

echo "===== 8) replies + status transitions ====="
apic $AJ POST /api/tickets/$T1/replies "$AC" '{"body":"سلام، مشکل از فرمت فایل بود. لطفاً PDF کمتر از ۱۰ مگابایت ارسال کنید."}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok') and d['status']=='answered', d; print('ok | admin reply → answered')"
apic $CJ GET /api/tickets/$T1 | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ticket']['status']=='answered' and len(d['rows'])==2 and d['rows'][1]['mine']==False, d
print('ok | client sees admin reply, status answered')"
apic $CJ POST /api/tickets/$T1/replies "$CC" '{"body":"ممنون، با PDF مشکل حل شد."}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok') and d['status']=='open', d; print('ok | owner reply on answered → open')"
apic $AJ PATCH /api/tickets/$T1 "$AC" '{"status":"closed"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | admin closed')"
apic $CJ POST /api/tickets/$T1/replies "$CC" '{"body":"پاسخ روی تیکت بسته"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'بسته' in d.get('error',''), d; print('ok | owner reply on closed → 400')"
apic $AJ POST /api/tickets/$T1/replies "$AC" '{"body":"یادداشت نهایی: بسته شد."}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok') and d['status']=='closed', d; print('ok | admin append keeps closed')"

echo "===== 9) admin PATCH: validation + dept refer ====="
apic $AJ PATCH /api/tickets/$L1 "$AC" '{"status":"خراب"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'وضعیت' in d.get('error',''), d; print('ok | invalid status rejected')"
apic $AJ PATCH /api/tickets/$L1 "$AC" '{}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'تغییری' in d.get('error',''), d; print('ok | no-change rejected')"
apic $AJ PATCH /api/tickets/$L1 "$AC" '{"status":"review","dept":"حقوقی"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | status→review + dept→حقوقی')"
apic $LJ GET /api/tickets/$L1 | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ticket']['status']=='review' and d['ticket']['dept']=='حقوقی', d
print('ok | owner sees updated status/dept')"

echo "===== 10) admin filters ====="
apic $AJ GET "/api/tickets?status=closed" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert len(d['rows'])==1 and d['rows'][0]['status']=='closed', d; print('ok | filter status=closed')"
apic $AJ GET "/api/tickets?dept=$(python3 -c "import urllib.parse;print(urllib.parse.quote('فنی'))")" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert len(d['rows'])==1 and d['rows'][0]['dept']=='فنی', d; print('ok | filter dept=فنی')"
apic $AJ GET "/api/tickets?priority=$(python3 -c "import urllib.parse;print(urllib.parse.quote('بالا'))")" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert len(d['rows'])==1 and d['rows'][0]['priority']=='بالا', d; print('ok | filter priority=بالا')"
apic $AJ GET "/api/tickets?status=closed&dept=$(python3 -c "import urllib.parse;print(urllib.parse.quote('مالی'))")" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d['rows']==[], d; print('ok | combined filter empty')"

echo "===== 11) rate limit: 6th ticket in hour → 429 (client has 1+closed) ====="
for i in 2 3 4 5; do
apic $CJ POST /api/tickets "$CC" "{\"subject\":\"تیکت سهمیه $i\",\"dept\":\"عمومی\",\"priority\":\"کم\",\"body\":\"تست سقف نرخ ارسال تیکت شماره $i\"}" >/dev/null
done
apic $CJ POST /api/tickets "$CC" '{"subject":"تیکت ششم","dept":"عمومی","priority":"کم","body":"باید به سقف نرخ بخورد"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'سقف' in d.get('error',''), d; print('ok | 429 rate limit')"

echo "===== 12) messages: chat gate before assignment ====="
CASE=$(apic $CJ POST /api/cases "$CC" '{"category":"قرارداد","title":"تست پیام — قرارداد ساخت","description":"برای تست ماژول پیام"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
echo "case_id=$CASE"
apic $CJ POST /api/messages "$CC" "{\"case_id\":$CASE,\"body\":\"سلام\"}" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'فعال نیست' in d.get('error',''), d; print('ok | waiting case chat blocked')"
apic $CJ GET "/api/messages?case_id=$CASE" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['rows']==[], d; print('ok | owner GET empty messages (waiting)')"
curl -s -o /dev/null -w "lawyer-GET-unassigned-messages [%{http_code}] (404 مورد انتظار)\n" -b $LJ "$B/api/messages?case_id=$CASE"
apic $CJ GET "/api/messages?case_id=999999" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('error')=='پرونده یافت نشد.', d; print('ok | 404 anti-leak')"

echo "===== 13) cycle → assigned → chat opens ====="
PROP=$(apic $LJ POST /api/cases/$CASE/proposals "$LC" '{"amount":7000000,"days":20,"note":"پیشنهاد تست پیام"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
apic $AJ POST /api/proposals/$PROP/accept "$AC" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | accepted → assigned')"
apic $CJ POST /api/messages "$CC" "{\"case_id\":$CASE,\"body\":\"سلام، مدارک را ایمیل کنم؟\"}" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | client first message')"
apic $LJ POST /api/messages "$LC" "{\"case_id\":$CASE,\"body\":\"سلام، بله؛ شنبه تا چهارشنبه پاسخ می\u200cدهم.\"}" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | lawyer reply')"
apic $AJ POST /api/messages "$AC" "{\"case_id\":$CASE,\"body\":\"مدیر هم پیگیری می\u200cکند.\"}" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | admin oversight message')"

echo "===== 14) messages: read back + privacy + decryption ====="
apic $CJ GET "/api/messages?case_id=$CASE" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['case']['id']>0 and len(d['rows'])==3, d
assert d['rows'][0]['mine']==True and d['rows'][1]['mine']==False and d['rows'][2]['mine']==False, d
assert 'ایمیل کنم' in d['rows'][0]['body'] and 'شنبه تا چهارشنبه' in d['rows'][1]['body'], d
raw=json.dumps(d,ensure_ascii=False)
assert 'وکیل تست چرخه' not in raw, 'NAME LEAK TO CLIENT'
print('ok | client reads 3 messages, decrypted, no names')"
apic $LJ GET "/api/messages?case_id=$CASE" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==3 and d['rows'][0]['mine']==False and d['rows'][1]['mine']==True, d
assert 'name' not in d['rows'][0], d
print('ok | lawyer reads 3 messages, no names')"
apic $AJ GET "/api/messages?case_id=$CASE" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==3 and d['rows'][0]['name']=='مشتری تست چرخه', d
print('ok | admin sees names')"

echo "===== 15) threads: both sides see the case with last excerpt ====="
apic $CJ POST /api/messages "$CC" "{\"case_id\":$CASE,\"body\":\"متشکر، منتظر گزارش هستم.\"}" >/dev/null
apic $CJ GET /api/threads | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==1, d
r=d['rows'][0]
assert r['status']=='assigned' and 'گزارش' in r['last_excerpt'] and r['last_mine']==True, r
print('ok | client thread: last_excerpt + last_mine=true')"
apic $LJ GET /api/threads | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==1 and d['rows'][0]['last_mine']==False, d
print('ok | lawyer thread: last_mine=false')"

echo "===== 16) encryption at rest (AES-256-GCM) ====="
node -e "
const {db}=require('./lib/db.pg');
(async()=>{
  const t=(await db.prepare('SELECT body_enc FROM ticket_messages LIMIT 1').all()).map(r=>r.body_enc);
  const m=(await db.prepare('SELECT body_enc FROM messages LIMIT 1').all()).map(r=>r.body_enc);
  if(!t.length||!m.length) throw new Error('no rows');
  if(!t.every(x=>x.startsWith('v1.'))||!m.every(x=>x.startsWith('v1.'))) throw new Error('PLAINTEXT FOUND');
  console.log('ok | ticket_messages+messages stored encrypted (v1.*)');
  process.exit(0);
})().catch(e=>{console.error(e.message);process.exit(1)})"

echo "===== 17) running transition keeps thread (regression of gate) ====="
apic $AJ PATCH /api/cases/$CASE "$AC" '{"status":"running"}' >/dev/null
apic $CJ POST /api/messages "$CC" "{\"case_id\":$CASE,\"body\":\"اداره\u200cی پرونده در جریان است\"}" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | running chat works')"

echo "===== 18) cleanup ====="
kill $SRV 2>/dev/null || true
node /home/z/my-project/scripts/cleanup-msg.js
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node -e "
const {db}=require('./lib/db.pg');
(async()=>{
  const t=+(await db.prepare('SELECT COUNT(*) c FROM tickets').get()).c;
  const tm=+(await db.prepare('SELECT COUNT(*) c FROM ticket_messages').get()).c;
  const m=+(await db.prepare('SELECT COUNT(*) c FROM messages').get()).c;
  console.log('tickets left:',t,'| ticket_messages left:',tm,'| messages left:',m);
  if(t+tm+m!==0) throw new Error('not cleaned');
  process.exit(0);
})().catch(e=>{console.error(e.message);process.exit(1)})"
echo "ALL CMD-007 API TESTS PASSED"
