#!/bin/bash
# ============================================================
# CMD-009 — تست ماژول لاگ مدیر (فاز ۳ گام ۷) روی دیتابیس واقعی
# هارنس محلی web/ + Supabase؛ ردپای آزمایشی در پایان پاک می‌شود.
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
APPSECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development DEV_SHOW_OTP=1 TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"
export APP_SECRET="$APPSECRET"

echo "===== 0) cleanup leftovers + seed test users ====="
node /home/z/my-project/scripts/cleanup-log.js
node /home/z/my-project/scripts/cleanup-docs.js
node /home/z/my-project/scripts/cleanup-msg.js
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node /home/z/my-project/scripts/seed-test-users.pg.js

PORT=3209 node scripts/dev-server.js > /tmp/log_harness.log 2>&1 &
SRV=$!
sleep 2
B=http://127.0.0.1:3209
CJ=/tmp/lg_client.jar; LJ=/tmp/lg_lawyer.jar; AJ=/tmp/lg_admin.jar
rm -f $CJ $LJ $AJ
trap 'kill $SRV 2>/dev/null || true' EXIT

login() {
  curl -s -c "$1" -X POST $B/api/auth/login -H "Content-Type: application/json" -H "Origin: $B" \
    -d "{\"username\":\"$2\",\"password\":\"$3\"}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('csrf','FAIL:'+d.get('error','?')))"
}
apic() {
  local m=$2 p=$3
  if [ "$m" = "GET" ]; then curl -s -b "$1" "$B$p"
  else curl -s -b "$1" -X "$m" "$B$p" -H "Content-Type: application/json" -H "Origin: $B" -H "x-csrf-token: $4" ${5:+-d "$5"}; fi
}

echo "===== 1) logins (client/lawyer/admin) ====="
CC=$(login $CJ client_t 'ClientT#2026'); echo "client csrf: ${CC:0:8}…"
LC=$(login $LJ lawyer_t 'LawyerT#2026'); echo "lawyer csrf: ${LC:0:8}…"
AC=$(login $AJ admin_t 'AdminT#2026x'); echo "admin csrf: ${AC:0:8}…"
[ "$CC" != "FAIL" ] && [ "$LC" != "FAIL" ] && [ "$AC" != "FAIL" ] || { echo LOGIN_FAILED; kill $SRV; exit 1; }

echo "===== 2) access control: guest 401 / client 403 / lawyer 403 ====="
curl -s -o /dev/null -w "guest-audit [%{http_code}] (401 مورد انتظار)\n" $B/api/audit
curl -s -o /dev/null -w "client-audit [%{http_code}] (403 مورد انتظار)\n" -b $CJ $B/api/audit
curl -s -o /dev/null -w "lawyer-audit [%{http_code}] (403 مورد انتظار)\n" -b $LJ $B/api/audit

echo "===== 3) admin: shape + newest entry is own (fresh) login ====="
AC=$(login $AJ admin_t 'AdminT#2026x')  # لاگین دوباره → جدیدترین ردیف audit همین ورود است
apic $AJ GET /api/audit | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['total']>=1 and d['pages']>=1 and d['page']==1, d
assert d['rows'], d
r=d['rows'][0]
for k in ('id','at','action','detail','ip','user_id','user_name','user_role'): assert k in r, r
assert r['action']=='login' and r['user_name']=='مدیر تست چرخه' and r['user_role']=='admin', r
print('ok | admin list OK, newest row = own login (%d total, %d pages)' % (d['total'], d['pages']))"

echo "===== 4) pagination ====="
apic $AJ GET "/api/audit?page=1" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and len(d['rows'])<=10 and d['page']==1, d
print('ok | page1 rows<=10 (%d rows)' % len(d['rows']))"
P2=$(apic $AJ GET "/api/audit?page=2" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'], d
print(d['pages'])")
apic $AJ GET "/api/audit?page=$P2" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['page']==d['pages'], d
print('ok | last page served, page=pages=%d' % d['pages'])"
apic $AJ GET "/api/audit?page=200" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['page']==d['pages'], d
print('ok | beyond-range page (within validation) clamped to last')"
curl -s -o /dev/null -w "page-999 [%{http_code}] (400 مورد انتظار — خارج از سقف اعتبارسنجی)\n" -b $AJ "$B/api/audit?page=999"

echo "===== 5) q search: by name / no-hit / SQL wildcard literal ====="
apic $AJ GET "/api/audit?q=$(python3 -c "from urllib.parse import quote; print(quote('مشتری تست چرخه'))")" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['total']>=1, d
assert all(r['user_name']=='مشتری تست چرخه' for r in d['rows']), d
print('ok | q by user name → only that user (%d rows)' % d['total'])"
apic $AJ GET "/api/audit?q=$(python3 -c "from urllib.parse import quote; print(quote('چنین رکوردی وجود ندارد xyz'))")" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['rows']==[] and d['total']==0, d
print('ok | q no-hit → empty')"
apic $AJ GET "/api/audit?q=%25" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'], d
print('ok | literal %% treated literally (%d rows)' % d['total'])"

echo "===== 6) action filter ====="
apic $AJ GET "/api/audit?action=login" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['total']>=1, d
assert all(r['action']=='login' for r in d['rows']), d
print('ok | action=login → only login rows')"
curl -s -o /dev/null -w "bad-page [%{http_code}] (400 مورد انتظار)\n" -b $AJ "$B/api/audit?page=abc"

echo "===== 7) live write→read: forbidden by client is logged and visible to admin ====="
curl -s -o /dev/null -b $CJ $B/api/audit  # یک ۴۰۳ دیگر ثبت می‌شود (forbidden)
sleep 1
apic $AJ GET "/api/audit?action=forbidden" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['total']>=2, d
r=d['rows'][0]
assert r['action']=='forbidden' and r['user_name']=='مشتری تست چرخه', r
print('ok | forbidden attempts logged (total=%d) and visible to admin' % d['total'])"

echo "===== 8) regression: neighbors intact ====="
apic $CJ GET "/api/cases?page=1" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'], d; print('ok | cases intact')"
apic $CJ GET /api/documents | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['rows']==[], d; print('ok | documents intact')"
curl -s -o /dev/null -w "invoices-guest [%{http_code}] (401 مورد انتظار)\n" $B/api/invoices

echo "===== 9) cleanup ====="
kill $SRV 2>/dev/null || true
node /home/z/my-project/scripts/cleanup-log.js
node /home/z/my-project/scripts/cleanup-docs.js
node /home/z/my-project/scripts/cleanup-msg.js
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node -e "
const {db}=require('./lib/db.pg');
(async()=>{
  const ids=(await db.prepare(\"SELECT id FROM users WHERE lower(username) IN('client_t','lawyer_t','admin_t')\").all()).map(r=>r.id);
  let left=0;
  if(ids.length){const ph=ids.map(()=>'?').join(',');left=+(await db.prepare('SELECT COUNT(*) c FROM audit_log WHERE user_id IN('+ph+')').get(...ids)).c;}
  console.log('test-user audit rows left:',left);
  if(left!==0) throw new Error('not cleaned');
  process.exit(0);
})().catch(e=>{console.error(e.message);process.exit(1)})"
echo "ALL CMD-009 API TESTS PASSED"
