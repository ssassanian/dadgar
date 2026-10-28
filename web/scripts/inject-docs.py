#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-008 — تزریق صفحه‌ی واقعی اسناد (VR) به web/dynamic/index.html
فایل مرجع dadgar/public/index.html دست‌نخورده می‌ماند.
این اسکریپت همیشه از مرجع شروع می‌کند: اول بلاک‌های CMD-003 (چرخه پرونده)، CMD-004
(نوبت‌دهی)، CMD-005 (مالی)، CMD-006 (نظرات) و CMD-007 (پیام/تیکت) و در آخر بلاک CMD-008 —
لذا اجرای مکرر idempotent است. دو نقطه‌ی درج با anchor دقیق:
  A) قبل از «shell, router, events» → ویوی VR.cDocs (گاوصندوق اسناد مشتری)
  B) قبل از هندلر نمایشی [data-md] → هندلرهای واقعی:
     data-docup (آپلود raw binary) / data-docdl (دانلود blob) / data-docdel (حذف با 404 ضدافشا)"""
import io, subprocess, sys

P = '/home/z/my-project/dadgar/web/dynamic/index.html'
REF = '/home/z/my-project/dadgar/dadgar/public/index.html'
CYCLE = '/home/z/my-project/dadgar/web/scripts/inject-cycle.py'
BOOK = '/home/z/my-project/dadgar/web/scripts/inject-book.py'
BILL = '/home/z/my-project/dadgar/web/scripts/inject-bill.py'
REV = '/home/z/my-project/dadgar/web/scripts/inject-rev.py'
MSG = '/home/z/my-project/dadgar/web/scripts/inject-msg.py'

# گام ۰: بازتولید پایه (مرجع + CMD-003..007) تا تزریق همیشه تکرارپذیر باشد
subprocess.run([sys.executable, CYCLE], check=True)
subprocess.run([sys.executable, BOOK], check=True)
subprocess.run([sys.executable, BILL], check=True)
subprocess.run([sys.executable, REV], check=True)
subprocess.run([sys.executable, MSG], check=True)
s = io.open(P, encoding='utf-8').read()

ANCHOR_A = "/* ---------- shell, router, events ---------- */"
ANCHOR_MD = "if(a=t.closest('[data-md]')){"
for a in (ANCHOR_A, ANCHOR_MD):
    assert s.count(a) == 1, a[:40] + ' count=%d' % s.count(a)
assert 'CMD-003' in s and 'CMD-004' in s and 'CMD-005' in s and 'CMD-006' in s and 'CMD-007' in s, 'base blocks missing — chain failed'
assert 'CMD-008' not in s, 'already injected'

BLOCK_VR = """/* ---------- CMD-008 فاز ۳ گام ۶ — اسناد: صفحات واقعی (VR) ---------- */
var DOCMAX=4*1024*1024;
var DO={on:0,uid:null,rows:null,cases:null};
function fsize(n){n=+n||0;if(n>=1048576)return (Math.round(n/104857.6)/10).toLocaleString('fa-IR')+' مگابایت';if(n>=1024)return Math.round(n/1024).toLocaleString('fa-IR')+' کیلوبایت';return fa(n)+' بایت'}
function docNeed(){if(DO.rows&&DO.uid===(U&&U.id))return 1;DO.uid=U&&U.id;DO.rows=null;
api('GET','documents').then(function(r){if(r.ok){DO.rows=r.j.rows;render(0)}else toast(r.j.error||'دریافت اسناد ناموفق بود.')});
api('GET','cases?select=1').then(function(r){if(r.ok){DO.cases=r.j.rows;render(0)}});
return 0}
VR.cDocs=function(){DO.on=1;if(!docNeed())return listWait('اسناد من');
var cs=DO.cases||[],rs=DO.rows||[];
var up=cs.length?'<div class="fg">'+selOpt('dccase','پرونده',cs.map(function(x){return [x.id,fa(x.id)+' — '+esc(x.title)]}),'')+'</div><label class="lb">فایل سند<input class="inp" id="dcfile" type="file"></label>'+btn('بارگذاری سند','','data-docup')+'<small>هر بار یک سند تا سقف ۴ مگابایت. اسناد با AES-256-GCM رمزنگاری می‌شوند و فقط شما، وکیلِ تخصیص‌یافته‌ی همان پرونده و مدیر سامانه به آن‌ها دسترسی دارند.</small>':'<p style="opacity:.6">برای بارگذاری سند ابتدا یک پرونده ثبت کنید؛ اسناد همیشه به یک پرونده متصل می‌شوند.</p>';
var body=rs.length?tbl(['سند','پرونده','تاریخ','سطح دسترسی','عملیات'],rs.map(function(d){return tr(['<b>'+esc(d.name)+'</b><br><small style="opacity:.6">'+fsize(d.size)+'</small>','<a href="#/c/case/'+d.case_id+'">'+fa(d.case_id)+'</a>',jdate(d.created_at),d.shared?tk('اشتراک با وکیل',3):tk('محرمانه',4),'<span class="row"><button class="btn sm o" style="color:var(--ink)" data-docdl="'+d.id+'">دانلود</button>'+(d.mine?'<button class="btn sm n" data-docdel="'+d.id+'">حذف</button>':'')+'</span>'])})):'<p style="opacity:.6">گاوصندوق خالی است. مدارک پرونده‌ی خود را بارگذاری کنید تا وکیل به آن‌ها دسترسی داشته باشد.</p>';
return '<h2 class="dh">اسناد من</h2>'+card('بارگذاری سند جدید',up)+card('گاوصندوق اسناد',body)};
function realDocUpload(b){var f=$('#dcfile')?$('#dcfile').files[0]:null,cid=$('#dccase')?+$('#dccase').value:0;
if(!cid){toast('پرونده را انتخاب کنید');return}
if(!f){toast('فایل سند را انتخاب کنید');return}
if(f.size>DOCMAX){toast('حجم فایل بیش از سقف ۴ مگابایت است.');return}
busy(b,1);
fetch('/api/cases/'+cid+'/documents',{method:'POST',credentials:'same-origin',headers:{'x-csrf-token':CSRF,'x-file-name':encodeURIComponent(f.name||'سند'),'content-type':f.type||'application/octet-stream'},body:f})
.then(function(r){return r.json().catch(function(){return {}}).then(function(j){return {ok:r.ok,j:j}})})
.then(function(r){busy(b,0);if(r.ok){toast('سند بارگذاری شد.');DO.rows=null;DO.uid=null;render(0)}else toast(r.j.error||'بارگذاری ناموفق بود.')})
.catch(function(){busy(b,0);toast('ارتباط با سرور برقرار نشد.')})}
function realDocDownload(id){fetch('/api/documents/'+id+'/file',{credentials:'same-origin'}).then(function(r){
if(!r.ok){return r.json().catch(function(){return {}}).then(function(j){toast(j.error||'دانلود ناموفق بود.')})}
var cd=r.headers.get('content-disposition')||'',m=/filename\\*=UTF-8''([^\\s;]+)/.exec(cd),nm=m?decodeURIComponent(m[1]):('document-'+id);
return r.blob().then(function(b){var u=URL.createObjectURL(b),el=document.createElement('a');el.href=u;el.download=nm;document.body.appendChild(el);el.click();el.remove();setTimeout(function(){URL.revokeObjectURL(u)},4000);toast('دانلود شروع شد.')})}).catch(function(){toast('ارتباط با سرور برقرار نشد.')})}

"""

BLOCK_EV = """if(!DEMO&&DO.on&&(a=t.closest('[data-docup]'))){realDocUpload(a);return}
if(!DEMO&&DO.on&&(a=t.closest('[data-docdl]'))){realDocDownload(+a.dataset.docdl);return}
if(!DEMO&&(a=t.closest('[data-docdel]'))){var ddid=+a.dataset.docdel;modal('حذف سند','سند حذف شود؟',function(){api('DELETE','documents/'+ddid).then(function(r){if(r.ok){toast('سند حذف شد');DO.rows=null;DO.uid=null;render(0)}else toast(r.j.error||'حذف ناموفق بود.')})});return}
"""

s = s.replace(ANCHOR_A, BLOCK_VR + ANCHOR_A, 1)
s = s.replace(ANCHOR_MD, BLOCK_EV + ANCHOR_MD, 1)
io.open(P, 'w', encoding='utf-8').write(s)
print('injected CMD-008 OK; new size =', len(s))
