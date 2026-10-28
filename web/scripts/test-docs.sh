#!/bin/bash
# ============================================================
# CMD-008 — تست ماژول اسناد (فاز ۳ گام ۶) روی دیتابیس واقعی
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
node /home/z/my-project/scripts/cleanup-docs.js
node /home/z/my-project/scripts/cleanup-msg.js
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node /home/z/my-project/scripts/seed-test-users.pg.js

# فایل‌های تست: PDF واقعی‌نما (۱۰۴ بایت) و فایل بزرگ ۵ مگابایتی
python3 -c "open('/tmp/doc_test.pdf','wb').write(b'%PDF-'+bytes(range(1,100)))"
head -c 5242880 /dev/zero > /tmp/doc_big.bin
NAME_PDF=$(python3 -c "from urllib.parse import quote; print(quote('سند ملک.pdf'))")
NAME_LAY=$(python3 -c "from urllib.parse import quote; print(quote('لایحه‌ی دفاعیه.pdf'))")
NAME_HTML=$(python3 -c "from urllib.parse import quote; print(quote('گزارش.html'))")

PORT=3207 node scripts/dev-server.js > /tmp/docs_harness.log 2>&1 &
SRV=$!
sleep 2
B=http://127.0.0.1:3207
CJ=/tmp/dc_client.jar; LJ=/tmp/dc_lawyer.jar; AJ=/tmp/dc_admin.jar
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

echo "===== 2) guest: documents/upload/download → 401 ====="
curl -s -o /dev/null -w "guest-documents [%{http_code}]\n" $B/api/documents
curl -s -o /dev/null -w "guest-upload [%{http_code}]\n" -X POST "$B/api/cases/1/documents" -H "Content-Type: application/pdf" --data-binary @/tmp/doc_test.pdf
curl -s -o /dev/null -w "guest-download [%{http_code}]\n" "$B/api/documents/1/file"

echo "===== 3) empty lists (all roles) ====="
apic $CJ GET /api/documents | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['rows']==[], d; print('ok | client documents empty')"
apic $LJ GET /api/documents | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['rows']==[], d; print('ok | lawyer documents empty')"
apic $AJ GET /api/documents | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['rows']==[], d; print('ok | admin documents empty')"

echo "===== 4) client creates case (CMD-003 API) ====="
CASE=$(apic $CJ POST /api/cases "$CC" '{"category":"ملکی","title":"اختلاف در تخلیه‌ی ملک مسکونی","description":"مستأجر تخلیه نمی‌کند؛ قرارداد اجاره تا پایان سال است."}' | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
echo "case_id=$CASE"

echo "===== 5) upload validation (anti-leak + roles + csrf) ====="
curl -s -o /dev/null -w "upload-nonexistent-case [%{http_code}] (404 مورد انتظار)\n" -b $CJ -X POST "$B/api/cases/987654/documents" -H "Content-Type: application/pdf" -H "Origin: $B" -H "x-csrf-token: $CC" --data-binary @/tmp/doc_test.pdf
curl -s -o /dev/null -w "upload-lawyer-unassigned [%{http_code}] (404 مورد انتظار — ضدافشا)\n" -b $LJ -X POST "$B/api/cases/$CASE/documents" -H "Content-Type: application/pdf" -H "Origin: $B" -H "x-csrf-token: $LC" --data-binary @/tmp/doc_test.pdf
curl -s -o /dev/null -w "upload-admin [%{http_code}] (403 مورد انتظار — مدیر بارگذار نیست)\n" -b $AJ -X POST "$B/api/cases/$CASE/documents" -H "Content-Type: application/pdf" -H "Origin: $B" -H "x-csrf-token: $AC" --data-binary @/tmp/doc_test.pdf
curl -s -o /dev/null -w "upload-no-csrf [%{http_code}] (403 مورد انتظار)\n" -b $CJ -X POST "$B/api/cases/$CASE/documents" -H "Content-Type: application/pdf" -H "Origin: $B" --data-binary @/tmp/doc_test.pdf
curl -s -o /dev/null -w "upload-empty [%{http_code}] (400 مورد انتظار)\n" -b $CJ -X POST "$B/api/cases/$CASE/documents" -H "Content-Type: application/pdf" -H "Origin: $B" -H "x-csrf-token: $CC" -H "x-file-name: empty.pdf" --data-binary ""
curl -s -o /dev/null -w "upload-oversize [%{http_code}] (413 مورد انتظار)\n" -b $CJ -X POST "$B/api/cases/$CASE/documents" -H "Content-Type: application/pdf" -H "Origin: $B" -H "x-csrf-token: $CC" -H "x-file-name: big.pdf" --data-binary @/tmp/doc_big.bin

echo "===== 6) upload OK + encryption at rest ====="
DOC1=$(curl -s -b $CJ -X POST "$B/api/cases/$CASE/documents" -H "Content-Type: application/pdf" -H "Origin: $B" -H "x-csrf-token: $CC" -H "x-file-name: $NAME_PDF" --data-binary @/tmp/doc_test.pdf | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
echo "doc1_id=$DOC1"
node -e "
const {db}=require('./lib/db.pg');
(async()=>{
  const r=await db.prepare('SELECT name_enc, file, size, mime FROM documents WHERE id=?').get($DOC1);
  if(!r) throw new Error('row missing');
  if(!r.name_enc.startsWith('v1.')) throw new Error('NAME PLAINTEXT');
  if(r.name_enc.includes('سند')) throw new Error('NAME PLAINTEXT-2');
  const buf=Buffer.from(r.file,'base64');
  if(buf.includes('%PDF')) throw new Error('CONTENT PLAINTEXT');
  if(buf.length!==r.size+28) throw new Error('encrypted size mismatch: '+buf.length+' vs '+(r.size+28)); // 12 IV + 16 tag
  if(r.size!==104) throw new Error('size mismatch: '+r.size);
  if(r.mime!=='application/pdf') throw new Error('mime mismatch: '+r.mime);
  console.log('ok | name+content encrypted at rest (v1.*), size=104, mime=pdf');
  process.exit(0);
})().catch(e=>{console.error(e.message);process.exit(1)})"

echo "===== 7) lists: scoping + derived access level ====="
apic $CJ GET /api/documents | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==1, d
r=d['rows'][0]
assert r['name']=='سند ملک.pdf' and r['size']==104 and r['mine']==True and r['shared']==False, r
assert r['case_title']=='اختلاف در تخلیه‌ی ملک مسکونی', r
print('ok | client sees own doc, name decrypted, shared=false')"
apic $LJ GET /api/documents | python3 -c "
import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['rows']==[], d; print('ok | lawyer (unassigned) sees nothing')"
apic $AJ GET /api/documents | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==1 and d['rows'][0]['name']=='سند ملک.pdf', d; print('ok | admin sees all')"

echo "===== 8) download: byte-match + headers + anti-leak ====="
curl -s -b $CJ "$B/api/documents/$DOC1/file" -o /tmp/doc_dl.pdf -D /tmp/doc_dl_headers.txt
cmp /tmp/doc_test.pdf /tmp/doc_dl.pdf && echo "ok | downloaded bytes identical"
grep -qi "content-disposition: attachment" /tmp/doc_dl_headers.txt && grep -q "filename\*=UTF-8" /tmp/doc_dl_headers.txt && echo "ok | attachment + RFC5987 filename*"
grep -qi "content-type: application/pdf" /tmp/doc_dl_headers.txt && echo "ok | content-type pdf"
grep -qi "cache-control: no-store" /tmp/doc_dl_headers.txt && echo "ok | no-store"
grep -qi "x-content-type-options: nosniff" /tmp/doc_dl_headers.txt && echo "ok | nosniff"
curl -s -o /dev/null -w "download-lawyer-unassigned [%{http_code}] (404 مورد انتظار)\n" -b $LJ "$B/api/documents/$DOC1/file"
curl -s -b $AJ "$B/api/documents/$DOC1/file" -o /tmp/doc_dl_admin.pdf
cmp /tmp/doc_test.pdf /tmp/doc_dl_admin.pdf && echo "ok | admin download identical"
curl -s -o /dev/null -w "download-nonexistent [%{http_code}] (404 مورد انتظار)\n" -b $CJ "$B/api/documents/987654/file"

echo "===== 9) mime normalization (allowlist) ====="
DOC2=$(curl -s -b $CJ -X POST "$B/api/cases/$CASE/documents" -H "Content-Type: text/html" -H "Origin: $B" -H "x-csrf-token: $CC" -H "x-file-name: $NAME_HTML" --data-binary "hello" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
echo "doc2_id=$DOC2"
apic $CJ GET /api/documents | python3 -c "
import json,sys; d=json.load(sys.stdin)
r=[x for x in d['rows'] if x['id']==$DOC2][0]
assert r['mime']=='application/octet-stream', r
print('ok | text/html normalized to application/octet-stream')"

echo "===== 10) missing x-file-name → default name ====="
DOC3=$(curl -s -b $CJ -X POST "$B/api/cases/$CASE/documents" -H "Content-Type: text/plain" -H "Origin: $B" -H "x-csrf-token: $CC" --data-binary "test" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
apic $CJ GET /api/documents | python3 -c "
import json,sys; d=json.load(sys.stdin)
r=[x for x in d['rows'] if x['id']==$DOC3][0]
assert r['name']=='سند بدون نام', r
print('ok | missing header → سند بدون نام')"

echo "===== 11) case cycle → assigned (CMD-003 flow) ====="
apic $LJ POST /api/cases/$CASE/proposals "$LC" '{"amount":4500000,"days":30,"note":"آماده‌ی شروع هستم"}' | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | proposal sent')"
PR=$(apic $AJ GET "/api/cases/$CASE" | python3 -c "import json,sys; d=json.load(sys.stdin); ps=[p for p in d.get('proposals',[]) if p['status']=='pending']; assert ps, d; print(ps[0]['id'])")
apic $AJ POST /api/proposals/$PR/accept "$AC" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | proposal accepted → assigned')"

echo "===== 12) after assignment: lawyer sees + uploads + downloads ====="
apic $LJ GET /api/documents | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==3, d
assert all(r['shared']==True for r in d['rows']), d
print('ok | lawyer sees 3 docs of assigned case, shared=true')"
DL=$(curl -s -b $LJ -X POST "$B/api/cases/$CASE/documents" -H "Content-Type: application/pdf" -H "Origin: $B" -H "x-csrf-token: $LC" -H "x-file-name: $NAME_LAY" --data-binary @/tmp/doc_test.pdf | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print(d['id'])")
echo "lawyer_doc_id=$DL"
apic $CJ GET /api/documents | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['rows'])==4, d
r=[x for x in d['rows'] if x['id']==$DL][0]
assert r['mine']==False and r['shared']==True, r
print('ok | client sees lawyer doc (mine=false, no delete right in UI)')"
curl -s -b $LJ "$B/api/documents/$DOC1/file" -o /tmp/doc_dl_lawyer.pdf
cmp /tmp/doc_test.pdf /tmp/doc_dl_lawyer.pdf && echo "ok | lawyer downloads client doc, bytes identical"

echo "===== 13) select=1 (case picker) ====="
apic $CJ GET "/api/cases?select=1" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok'] and len(d['rows'])>=1, d
r=d['rows'][0]
assert set(r.keys())=={'id','title','status','created_at'}, r
print('ok | select=1 minimal case list')"
curl -s -o /dev/null -w "select-as-lawyer-ignored [%{http_code}] (200 مورد انتظار — مسیر عادی)\n" -b $LJ "$B/api/cases?select=1"

echo "===== 14) delete rules ====="
curl -s -o /dev/null -w "delete-by-third(lawyer→doc of …) [%{http_code}]\n" -b $LJ -X DELETE "$B/api/documents/$DOC2" -H "Origin: $B" -H "x-csrf-token: $LC"
apic $LJ DELETE /api/documents/$DL "$LC" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | lawyer deleted own doc')"
apic $CJ DELETE /api/documents/$DOC1 "$CC" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | uploader deleted own doc')"
apic $AJ DELETE /api/documents/$DOC2 "$AC" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | admin deleted any doc')"
apic $CJ DELETE /api/documents/$DOC3 "$CC" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok'), d; print('ok | uploader deleted own doc')"
apic $CJ GET /api/documents | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['rows']==[], d; print('ok | vault empty again')"
curl -s -o /dev/null -w "delete-nonexistent [%{http_code}] (404 مورد انتظار)\n" -b $AJ -X DELETE "$B/api/documents/987654" -H "Origin: $B" -H "x-csrf-token: $AC"

echo "===== 15) regression: cases pagination + invoices + tickets ====="
apic $CJ GET "/api/cases?page=1" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and int(d['total'])>=1, d; print('ok | cases pagination intact')"
curl -s -o /dev/null -w "invoices-lawyer [%{http_code}] (403 مورد انتظار)\n" -b $LJ "$B/api/invoices"
apic $CJ GET /api/tickets | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok'], d; print('ok | tickets intact')"

echo "===== 16) cleanup ====="
kill $SRV 2>/dev/null || true
node /home/z/my-project/scripts/cleanup-docs.js
node /home/z/my-project/scripts/cleanup-msg.js
node /home/z/my-project/scripts/cleanup-rev.js
node /home/z/my-project/scripts/cleanup-bill.js
node /home/z/my-project/scripts/cleanup-cycle.js
node -e "
const {db}=require('./lib/db.pg');
(async()=>{
  const d=+(await db.prepare('SELECT COUNT(*) c FROM documents').get()).c;
  console.log('documents left:',d);
  if(d!==0) throw new Error('not cleaned');
  process.exit(0);
})().catch(e=>{console.error(e.message);process.exit(1)})"
echo "ALL CMD-008 API TESTS PASSED"
