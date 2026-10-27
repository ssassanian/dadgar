#!/bin/bash
# ============================================================
# CMD-006 — تست ماژول نظرات (فاز ۳ گام ۴) روی دیتابیس واقعی
# هارنس محلی web/ + Supabase؛ کاربران و داده‌های آزمایشی بعداً پاک می‌شوند.
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
APPSECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development DEV_SHOW_OTP=1 TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"
export APP_SECRET="$APPSECRET"

echo "===== 0) cleanup leftovers + seed test users ====="
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node /home/z/my-project/scripts/seed-test-users.pg.js

PORT=3203 node scripts/dev-server.js > /tmp/rev_harness.log 2>&1 &
SRV=$!
sleep 2
B=http://127.0.0.1:3203
CJ=/tmp/rv_client.jar; LJ=/tmp/rv_lawyer.jar; AJ=/tmp/rv_admin.jar
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

echo "===== 2) client GET reviews (empty: rows + cases) ====="
apic $CJ GET /api/reviews | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['rows']==[] and d['cases']==[], d
print('ok | client empty')"

echo "===== 3) guest: /api/reviews → 401 | /api/reviews/public → 200 empty ====="
curl -s -o /dev/null -w "guest-reviews [%{http_code}]\n" $B/api/reviews
curl -s $B/api/reviews/public | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['count']==0 and d['rows']==[], d
print('ok | public empty')"

echo "===== 4) lawyer/admin GET reviews (empty) ====="
apic $LJ GET /api/reviews | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['count']==0 and d['avg']==0 and d['rows']==[], d; print('ok | lawyer empty')"
apic $AJ GET /api/reviews | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['count']==0 and d['rows']==[], d; print('ok | admin empty')"

echo "===== 5) client creates case → review on waiting case → 400 ====="
CASE=$(apic $CJ POST /api/cases "$CC" '{"category":"قرارداد","title":"تست نظرات — قرارداد ساخت","description":"برای تست ماژول نظرات"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
echo "case_id=$CASE"
apic $CJ POST /api/reviews "$CC" "{\"case_id\":$CASE,\"rating\":5,\"body\":\"نظر زودهنگام\",\"consent\":true}" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'بسته‌شدن' in d.get('error',''), d; print('ok |', d['error'])"

echo "===== 6) anti-leak: foreign/nonexistent case → 404 ====="
apic $CJ POST /api/reviews "$CC" '{"case_id":999999,"rating":5,"body":"تست","consent":true}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('error')=='پرونده یافت نشد.', d; print('ok | 404 anti-leak')"

echo "===== 7) validation: rating 0/6, empty body, lawyer POST → 403 ====="
for R in 0 6; do
apic $CJ POST /api/reviews "$CC" "{\"case_id\":$CASE,\"rating\":$R,\"body\":\"تست امتیاز\",\"consent\":true}" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'امتیاز' in d.get('error',''), d; print('ok | rating', '$R', 'rejected')"
done
apic $CJ POST /api/reviews "$CC" "{\"case_id\":$CASE,\"rating\":5,\"body\":\"  \",\"consent\":true}" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'نظر' in d.get('error','') or 'مقدار' in d.get('error',''), d; print('ok | empty body rejected')"
curl -s -o /dev/null -w "lawyer-POST-reviews [%{http_code}]\n" -b $LJ -X POST $B/api/reviews -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $LC" -d "{\"case_id\":$CASE,\"rating\":5,\"body\":\"تست\",\"consent\":true}"

echo "===== 8) PATCH status transitions (admin) ====="
apic $AJ PATCH /api/cases/$CASE "$AC" '{"status":"done"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'تخصیص' in d.get('error',''), d; print('ok | waiting→done blocked')"
apic $AJ PATCH /api/cases/$CASE "$AC" '{"status":"destroyed"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'وضعیت' in d.get('error',''), d; print('ok | invalid status rejected')"

echo "===== 9) cycle: propose → accept → assigned ====="
PROP=$(apic $LJ POST /api/cases/$CASE/proposals "$LC" '{"amount":7000000,"days":20,"note":"پیشنهاد تست نظرات"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
apic $AJ POST /api/proposals/$PROP/accept "$AC" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | proposal accepted → assigned')"

echo "===== 10) assigned→running→done ====="
apic $AJ PATCH /api/cases/$CASE "$AC" '{"status":"running"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | → running')"
apic $AJ PATCH /api/cases/$CASE "$AC" '{"status":"done"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | → done')"
apic $AJ PATCH /api/cases/$CASE "$AC" '{"status":"running"}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'بسته شده' in d.get('error',''), d; print('ok | done is terminal')"

echo "===== 11) client: done case appears in reviewable list ====="
apic $CJ GET /api/reviews | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['cases'])==1 and d['cases'][0]['title'].startswith('تست نظرات'), d
print('ok | reviewable case:', d['cases'][0]['id'])"

echo "===== 12) client POST valid review (consent=1) ====="
RID=$(apic $CJ POST /api/reviews "$CC" "{\"case_id\":$CASE,\"rating\":4,\"body\":\"پیگیری دقیق و گزارش‌های منظم بود.\",\"consent\":true}" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
echo "review_id=$RID"

echo "===== 13) duplicate → 409 ====="
apic $CJ POST /api/reviews "$CC" "{\"case_id\":$CASE,\"rating\":5,\"body\":\"نظر دوم\",\"consent\":true}" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert 'قبلاً' in d.get('error',''), d; print('ok |', d['error'])"

echo "===== 14) client list shows review; case no longer reviewable ====="
apic $CJ GET /api/reviews | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==1 and d['rows'][0]['rating']==4 and d['rows'][0]['case_title'].startswith('تست نظرات'), d
assert d['rows'][0]['approved']==False and d['rows'][0]['consent']==True, d
assert d['cases']==[], d
print('ok | client sees own review pending approval')"

echo "===== 15) lawyer view: masked name + avg=4 count=1 ====="
apic $LJ GET /api/reviews | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['count']==1 and abs(d['avg']-4)<0.01, d
r=d['rows'][0]
assert r['client_initial']=='م. ت. چ.', r
assert 'client_name' not in r and 'مشتری تست چرخه' not in json.dumps(d,ensure_ascii=False), 'FULL NAME LEAK TO LAWYER'
print('ok | lawyer sees mask only:', r['client_initial'])"

echo "===== 16) public: still empty (not approved) ====="
curl -s $B/api/reviews/public | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d['count']==0, d; print('ok | moderation gate works')"

echo "===== 17) admin: full name visible + approve ====="
apic $AJ GET /api/reviews | python3 -c "
import json,sys; d=json.load(sys.stdin)
r=d['rows'][0]; assert r['client_name']=='مشتری تست چرخه' and r['lawyer_name']=='وکیل تست چرخه', r
print('ok | admin sees full names')"
apic $AJ PATCH /api/reviews/$RID "$AC" '{"approved":true}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | approved')"

echo "===== 18) public now shows masked review ====="
curl -s $B/api/reviews/public | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['count']==1 and abs(d['avg']-4)<0.01, d
r=d['rows'][0]
assert r['client_initial']=='م. ت. چ.' and 'پیگیری دقیق' in r['body'], r
raw=json.dumps(d,ensure_ascii=False)
assert 'مشتری تست چرخه' not in raw and 'case_id' not in r, 'PRIVACY LEAK IN PUBLIC'
print('ok | public masked, no case_id, no full name')"

echo "===== 19) unapprove → public empty again ====="
apic $AJ PATCH /api/reviews/$RID "$AC" '{"approved":false}' | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | unapproved')"
curl -s $B/api/reviews/public | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d['count']==0, d; print('ok | public gate again')"

echo "===== 20) admin DELETE review ====="
apic $AJ DELETE /api/reviews/$RID "$AC" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | deleted')"
apic $CJ GET /api/reviews | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['rows']==[] and len(d['cases'])==1, d
print('ok | case reviewable again after delete')"
curl -s -o /dev/null -w "guest-DELETE [%{http_code}]\n" -X DELETE $B/api/reviews/1

echo "===== 21) CSRF + 404 anti-leak on review endpoints ====="
curl -s -o /dev/null -w "no-csrf-POST [%{http_code}]\n" -b $CJ -X POST $B/api/reviews -H "Content-Type: application/json" -H "Origin: $B" -d '{}'
apic $AJ DELETE /api/reviews/987654 "$AC" | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d.get('error')=='نظر یافت نشد.', d; print('ok | 404 anti-leak')"

echo "===== 22) cleanup ====="
kill $SRV 2>/dev/null || true
node /home/z/my-project/scripts/cleanup-rev.js
node -e "const {db}=require('./lib/db.pg');(async()=>{const n=(await db.prepare('SELECT COUNT(*) c FROM reviews').get()).c;console.log('reviews left:',n);if(+n!==0) throw new Error('reviews not cleaned');process.exit(0)})().catch(e=>{console.error(e.message);process.exit(1)})"
echo "ALL CMD-006 API TESTS PASSED"
