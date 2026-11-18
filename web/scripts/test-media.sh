#!/bin/bash
# ============================================================
# CMD-054 — تست ماژول تصاویر سایت (media) روی دیتابیس واقعی
# دو حالت خودکار:
#   - جدول media اعمال نشده (42P01): degrade شفاف تست می‌شود (ready:false / 503 / 404 عمومی)
#   - جدول media اعمال شده: چرخه‌ی کامل آپلود/جایگزینی/سرو عمومی/حذف/audit تست می‌شود
# ایمنی داده: ابتدا و انتهای اجرا جدول media خالی می‌شود (الگوی cleanup سایر تست‌ها).
# ⚠️ تنها پیش از آپلود تصاویر واقعیِ سایت اجرا شود؛ اجرای آن تصاویر واقعی را پاک می‌کند.
# ============================================================
set -e
cd /home/z/my-project/dadgar/web
DBPASS=$(cat /home/z/my-project/.secrets_supabase_db.txt)
APPSECRET=$(cat /home/z/my-project/.secrets_app_secret.txt)
export NODE_ENV=development DEV_SHOW_OTP=1 TRUST_PROXY=0 SMS_DRIVER=console
export DATABASE_URL="postgresql://dadgar_app.oyoywxgudbqmptwkxzpi:${DBPASS}@aws-0-eu-west-1.pooler.supabase.com:6543/postgres?sslmode=require"
export APP_SECRET="$APPSECRET"

echo "===== 0) cleanup media + seed test users ====="
node -e "const {sql}=require('./lib/db.pg'); sql.unsafe('DELETE FROM media').then(()=>sql.end()).then(()=>{console.log('media cleaned');process.exit(0)}).catch((e)=>{console.log('cleanup skipped:',e.message);process.exit(0)})"
node /home/z/my-project/scripts/seed-test-users.pg.js

PORT=3211 node scripts/dev-server.js > /tmp/media_harness.log 2>&1 &
SRV=$!
sleep 2
B=http://127.0.0.1:3211
AJ=/tmp/md_admin.jar
CJ=/tmp/md_client.jar
rm -f $AJ $CJ
trap 'kill $SRV 2>/dev/null || true' EXIT

# فایل‌های آزمایشی پیش از بخش ۲ ساخته می‌شوند (بخش ۲ در حالت degrade هم به PNG نیاز دارد)
python3 - <<'PYEOF'
import base64
png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
jpg = base64.b64decode('/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==')
open('/tmp/md_test.png','wb').write(png)
open('/tmp/md_test.jpg','wb').write(jpg)
open('/tmp/md_test_big.png','wb').write(png + b'\x00'*(2*1024*1024))
open('/tmp/md_test_fake.png','wb').write(b'this is not an image at all')
PYEOF

login() {
  curl -s -c "$1" -X POST $B/api/auth/login -H "Content-Type: application/json" -H "Origin: $B" \
    -d "{\"username\":\"$2\",\"password\":\"$3\"}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('csrf','FAIL:'+d.get('error','?')))"
}

echo "===== 1) logins ====="
AC=$(login $AJ admin_t 'AdminT#2026x'); echo "admin csrf: ${AC:0:8}…"
[ "$AC" != "FAIL" ] || { echo LOGIN_FAILED; kill $SRV; exit 1; }
CC=$(login $CJ client_t 'ClientT#2026'); echo "client csrf: ${CC:0:8}…"
[ "$CC" != "FAIL" ] || { echo LOGIN_FAILED; kill $SRV; exit 1; }

echo "===== 2) access control ====="
curl -s -o /dev/null -w "guest-list [%{http_code}] (401 مورد انتظار)\n" $B/api/media
curl -s -o /dev/null -w "guest-upload [%{http_code}] (401 مورد انتظار)\n" -X POST "$B/api/media/ali" -H "Content-Type: image/png" --data-binary @/tmp/md_test.png
curl -s -o /dev/null -w "guest-delete [%{http_code}] (401 مورد انتظار)\n" -X DELETE "$B/api/media/ali" -H "Origin: $B"
curl -s -b $CJ -o /dev/null -w "client-list [%{http_code}] (403 مورد انتظار)\n" $B/api/media
curl -s -b $CJ -o /dev/null -w "client-upload [%{http_code}] (403 مورد انتظار)\n" -X POST "$B/api/media/ali" -H "Content-Type: image/png" -H "Origin: $B" -H "x-csrf-token: $CC" --data-binary @/tmp/md_test.png
curl -s -b $AJ -o /dev/null -w "public-serve-unset [%{http_code}] (404 مورد انتظار — بدون ورود)\n" $B/api/media/ali

echo "===== 3) shape: admin GET + وضعیت degrade/کامل ====="
READY=$(curl -s -b $AJ $B/api/media | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'], d
if d.get('ready') is False:
    assert d['rows']==[], d
    print('0')
else:
    names=sorted(r['name'] for r in d['rows'])
    assert names==['ali','mahdi','office','sara'], names
    print('1')")
echo "media ready=$READY (1=چرخه‌ی کامل، 0=حالت degrade)"

if [ "$READY" = "0" ]; then
  echo "--- جدول media اعمال نشده: تست degrade ---"
  curl -s -b $AJ -o /dev/null -w "upload-degrade [%{http_code}] (503 مورد انتظار)\n" -X POST "$B/api/media/ali" -H "Content-Type: image/png" -H "Origin: $B" -H "x-csrf-token: $AC" --data-binary @/tmp/md_test.png
  curl -s -b $AJ $B/api/media | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ready'] is False and d['rows']==[], d; print('ok | degrade shape (ready:false, rows:[])')"
  echo "PASS-degrade"
  kill $SRV
  exit 0
fi

echo "===== 4) full cycle: upload → serve → replace → delete ====="

curl -s -b $AJ -X POST "$B/api/media/ali" -H "Content-Type: image/png" -H "Origin: $B" -H "x-csrf-token: $AC" --data-binary @/tmp/md_test.png | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok') and d['name']=='ali' and d['mime']=='image/png' and d['size']>0, d; print('ok | PNG uploaded:', d['size'], 'bytes')"
curl -s -D /tmp/md_headers.txt -o /tmp/md_served.png $B/api/media/ali
python3 - <<'PYEOF'
h = open('/tmp/md_headers.txt').read().lower()
body = open('/tmp/md_served.png','rb').read()
orig = open('/tmp/md_test.png','rb').read()
assert 'content-type: image/png' in h, h
assert 'max-age=60' in h, h
assert 'nosniff' in h, h
assert body == orig, (len(body), len(orig))
print('ok | public serve: 200 image/png + cache:60 + nosniff + bytes match')
PYEOF
curl -s -b $AJ -X POST "$B/api/media/ali" -H "Content-Type: image/jpeg" -H "Origin: $B" -H "x-csrf-token: $AC" --data-binary @/tmp/md_test.jpg | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok') and d['mime']=='image/jpeg', d; print('ok | replaced with JPEG (upsert overwrites)')"
curl -s -o /dev/null -w "public-serve-jpeg [%{http_code}] content-type=%{content_type} (200 image/jpeg مورد انتظار)\n" $B/api/media/ali
curl -s -b $AJ $B/api/media | python3 -c "
import json,sys; d=json.load(sys.stdin)
ali=[r for r in d['rows'] if r['name']=='ali'][0]
assert ali['set'] and ali['mime']=='image/jpeg' and ali['updated_at']>0, ali
print('ok | admin list reflects set:true + mime + updated_at')"

echo "===== 5) validation ====="
curl -s -b $AJ -o /dev/null -w "upload-no-csrf [%{http_code}] (403 مورد انتظار)\n" -b $AJ -X POST "$B/api/media/ali" -H "Content-Type: image/png" -H "Origin: $B" --data-binary @/tmp/md_test.png
curl -s -b $AJ -X POST "$B/api/media/ali" -H "Content-Type: text/html" -H "Origin: $B" -H "x-csrf-token: $AC" --data-binary @/tmp/md_test.png | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('error'), d; print('ok | html mime rejected (415):', d['error'][:44])"
curl -s -b $AJ -X POST "$B/api/media/ali" -H "Content-Type: image/png" -H "Origin: $B" -H "x-csrf-token: $AC" --data-binary @/tmp/md_test_fake.png | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('error'), d; print('ok | fake png body rejected (magic bytes):', d['error'][:44])"
curl -s -b $AJ -o /dev/null -w "upload-oversize [%{http_code}] (413 مورد انتظار)\n" -b $AJ -X POST "$B/api/media/ali" -H "Content-Type: image/png" -H "Origin: $B" -H "x-csrf-token: $AC" --data-binary @/tmp/md_test_big.png
curl -s -b $AJ -X POST "$B/api/media/hacker" -H "Content-Type: image/png" -H "Origin: $B" -H "x-csrf-token: $AC" --data-binary @/tmp/md_test.png | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('error'), d; print('ok | unknown key rejected:', d['error'][:44])"
curl -s -o /dev/null -w "public-unknown-key [%{http_code}] (404 مورد انتظار)\n" $B/api/media/hacker
curl -s -o /dev/null -w "public-unset-slot [%{http_code}] (404 مورد انتظار)\n" $B/api/media/sara
curl -s -b $AJ -o /dev/null -w "delete-unset [%{http_code}] (404 مورد انتظار)\n" -b $AJ -X DELETE "$B/api/media/sara" -H "Origin: $B" -H "x-csrf-token: $AC"

echo "===== 6) delete + audit ====="
curl -s -b $AJ -X DELETE "$B/api/media/ali" -H "Origin: $B" -H "x-csrf-token: $AC" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | deleted')"
curl -s -o /dev/null -w "public-after-delete [%{http_code}] (404 مورد انتظار)\n" $B/api/media/ali
curl -s -b $AJ "$B/api/audit?action=media_upload" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['total']>=1 and d['rows'][0]['action']=='media_upload', d
print('ok | media_upload logged in audit (total=%d)' % d['total'])"
curl -s -b $AJ "$B/api/audit?action=media_delete" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and d['total']>=1 and d['rows'][0]['action']=='media_delete', d
print('ok | media_delete logged in audit (total=%d)' % d['total'])"

echo "===== 7) final cleanup ====="
node -e "const {sql}=require('./lib/db.pg'); sql.unsafe('DELETE FROM media').then(()=>sql.end()).then(()=>{console.log('media cleaned');process.exit(0)}).catch((e)=>{console.log('cleanup skipped:',e.message);process.exit(0)})"
echo "PASS-full"
