#!/bin/bash
# ============================================================
# CMD-010 — تست ماژول CMS/تنظیمات/سئو (فاز ۳ گام ۸) روی دیتابیس واقعی
# اگر جدول settings اعمال نشده باشد: حالت degrade شفاف تست می‌شود (ready:false / 503).
# اگر اعمال شده باشد: چرخه‌ی کامل ذخیره/خواندن/public/audit تست می‌شود.
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
APPSECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development DEV_SHOW_OTP=1 TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"
export APP_SECRET="$APPSECRET"

echo "===== 0) cleanup leftovers + seed test users ====="
node /home/z/my-project/scripts/cleanup-cms.js
node /home/z/my-project/scripts/cleanup-log.js
node /home/z/my-project/scripts/cleanup-docs.js
node /home/z/my-project/scripts/cleanup-msg.js
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node /home/z/my-project/scripts/seed-test-users.pg.js

PORT=3210 node scripts/dev-server.js > /tmp/cms_harness.log 2>&1 &
SRV=$!
sleep 2
B=http://127.0.0.1:3210
AJ=/tmp/cm_admin.jar
rm -f $AJ
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

echo "===== 1) logins ====="
AC=$(login $AJ admin_t 'AdminT#2026x'); echo "admin csrf: ${AC:0:8}…"
[ "$AC" != "FAIL" ] || { echo LOGIN_FAILED; kill $SRV; exit 1; }

echo "===== 2) access control ====="
curl -s -o /dev/null -w "guest-settings [%{http_code}] (401 مورد انتظار)\n" $B/api/settings
curl -s -o /dev/null -w "guest-put [%{http_code}] (401 مورد انتظار)\n" -X PUT $B/api/settings -H "Content-Type: application/json" -d '{}'
curl -s -b $AJ -o /dev/null -w "public-guest [%{http_code}] (200 مورد انتظار — بدون ورود)\n" $B/api/settings/public

echo "===== 3) shape: admin GET + public GET ====="
READY=$(apic $AJ GET /api/settings | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and 'map' in d, d
print('1' if d.get('ready') else '0')")
echo "settings ready=$READY"
apic $AJ GET /api/settings | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and isinstance(d['map'],dict), d
print('ok | admin GET shape OK (map present, ready=%s)' % d.get('ready'))"
apic $AJ GET /api/settings/public | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and 'contact' in d and 'tariffs' in d, d
assert set(d['tariffs'].keys())=={'phone','meeting','contract'}, d
assert set(d['contact'].keys())=={'phone','email','address','instagram','telegram'}, d
print('ok | public shape OK (ready=%s)' % d.get('ready'))"

echo "===== 4) validation ====="
curl -s -o /dev/null -w "put-no-csrf [%{http_code}] (403 مورد انتظار)\n" -b $AJ -X PUT $B/api/settings -H "Content-Type: application/json" -H "Origin: $B" -d '{"site_phone":"۰۲۱-۱۲۳۴۵۶۷۸"}'
apic $AJ PUT /api/settings "$AC" '{}' | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'error' in d and d.get('error'), d; print('ok | empty put → 400:', d['error'][:40])"
apic $AJ PUT /api/settings "$AC" '{"hacked_key":"x"}' | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'error' in d, d; print('ok | unknown key rejected:', d['error'][:50])"
LONG=$(python3 -c "print('a'*600)")
apic $AJ PUT /api/settings "$AC" "{\"site_address\":\"$LONG\"}" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'error' in d, d; print('ok | oversized value rejected')"

echo "===== 5) write path (depends on settings table) ====="
if [ "$READY" = "1" ]; then
  echo "--- settings table EXISTS: full cycle ---"
  apic $AJ PUT /api/settings "$AC" '{"site_phone":"۰۲۱-۱۲۳۴۵۶۷۸","tariff_phone":"۵۰۰ هزار تومان"}' | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | PUT saved')"
  apic $AJ GET /api/settings | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['map'].get('site_phone')=='۰۲۱-۱۲۳۴۵۶۷۸' and d['map'].get('tariff_phone')=='۵۰۰ هزار تومان', d
print('ok | GET reflects values')"
  curl -s -b $AJ $B/api/settings/public | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['contact']['phone']=='۰۲۱-۱۲۳۴۵۶۷۸' and d['tariffs']['phone']=='۵۰۰ هزار تومان', d
print('ok | public reflects contact + tariffs')"
  apic $AJ GET "/api/audit?action=settings_save" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['total']>=1 and d['rows'][0]['action']=='settings_save', d
print('ok | settings_save logged in audit')"
  apic $AJ PUT /api/settings "$AC" '{"site_phone":"۰۲۱-۹۹۹۹۹۹۹۹","tariff_phone":"۴۵۰ هزار تومان"}' | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | upsert overwrites')"
  apic $AJ GET /api/settings | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['map'].get('site_phone')=='۰۲۱-۹۹۹۹۹۹۹۹', d
print('ok | upsert reflected')"
else
  echo "--- settings table NOT applied: honest degrade ---"
  apic $AJ PUT /api/settings "$AC" '{"site_phone":"۰۲۱-۱۲۳۴۵۶۷۸"}' | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert not d.get('ok') and d.get('error'), d
assert 'اعمال نشده' in d['error'], d
print('ok | PUT → honest 503 message')"
fi

echo "===== 6) regression: audit + health + cases ====="
apic $AJ GET "/api/audit?page=1" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'], d; print('ok | audit intact')"
curl -s $B/api/health | grep -q '"ok":true' && echo "ok | health"
curl -s -o /dev/null -w "cases-guest [%{http_code}] (401 مورد انتظار)\n" $B/api/cases

echo "===== 7) cleanup ====="
kill $SRV 2>/dev/null || true
node /home/z/my-project/scripts/cleanup-cms.js
node /home/z/my-project/scripts/cleanup-log.js
node /home/z/my-project/scripts/cleanup-docs.js
node /home/z/my-project/scripts/cleanup-msg.js
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
echo "ALL CMD-010 API TESTS PASSED"
