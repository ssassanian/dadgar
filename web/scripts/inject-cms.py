#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-010 — تزریق صفحات واقعی CMS/تنظیمات/سئو (VR) به web/dynamic/index.html
فایل مرجع dadgar/public/index.html دست‌نخورده می‌ماند.
این اسکریپت همیشه از مرجع شروع می‌کند: اول زنجیره‌ی CMD-003..009 و در آخر بلاک CMD-010 —
لذا اجرای مکرر idempotent است. دو نقطه‌ی درج با anchor دقیق:
  A) قبل از «shell, router, events» → VR.aSet (تنظیمات واقعی) / VR.aCms (تعرفه‌های واقعی) /
     VR.aSeo=V.aSeo (صفحه‌ی برنامه‌ریزی — فقط بدون نوار زرد) / override صفحه‌ی عمومی تعرفه‌ها
  B) قبل از هندلر نمایشی [data-md] → هندلرهای واقعی data-setsave / data-cmssave
نکته: جدول settings ممکن است هنوز اعمال نشده باشد (42P01) — در این حالت سرور ready:false/503
می‌دهد و UI با مقادیر پیش‌فرض مرجع و پیام صادقانه کار می‌کند (کد از قبل آماده‌ی فعال‌سازی است)."""
import io, subprocess, sys

P = '/home/z/my-project/dadgar/web/dynamic/index.html'
REF = '/home/z/my-project/dadgar/dadgar/public/index.html'
CHAIN = ['inject-cycle.py', 'inject-book.py', 'inject-bill.py', 'inject-rev.py', 'inject-msg.py', 'inject-docs.py', 'inject-log.py']

for c in CHAIN:
    subprocess.run([sys.executable, '/home/z/my-project/dadgar/web/scripts/' + c], check=True)
s = io.open(P, encoding='utf-8').read()

ANCHOR_A = "/* ---------- shell, router, events ---------- */"
ANCHOR_MD = "if(a=t.closest('[data-md]')){"
for a in (ANCHOR_A, ANCHOR_MD):
    assert s.count(a) == 1, a[:40] + ' count=%d' % s.count(a)
assert 'CMD-003' in s and 'CMD-009' in s, 'base blocks missing — chain failed'
assert 'CMD-010' not in s, 'already injected'

BLOCK_VR = """/* ---------- CMD-010 فاز ۳ گام ۸ — CMS/تنظیمات/سئو: صفحات واقعی (VR) ---------- */
var STG={on:0,uid:null,ready:true,map:null};
var CM={on:0,uid:null,ready:true,map:null};
var PRUB={pub:null};
function stgNeed(){if(STG.map&&STG.uid===(U&&U.id))return 1;STG.uid=U&&U.id;STG.map=null;
api('GET','settings').then(function(r){if(r.ok){STG.ready=r.j.ready!==false;STG.map=r.j.map||{};render(0)}else toast(r.j.error||'دریافت تنظیمات ناموفق بود.')})
return 0}
function cmNeed(){if(CM.map&&CM.uid===(U&&U.id))return 1;CM.uid=U&&U.id;CM.map=null;
api('GET','settings').then(function(r){if(r.ok){CM.ready=r.j.ready!==false;CM.map=r.j.map||{};render(0)}else toast(r.j.error||'دریافت تنظیمات ناموفق بود.')})
return 0}
function stgInp(id,label,ph,key){return '<label class="lb">'+label+'<input class="inp" id="'+id+'" value="'+esc((STG.map&&STG.map[key])||ph)+'"></label>'}
function pendNote(ready){return ready?'':'<p style="color:#a35a00">ذخیره‌سازی هنوز فعال نشده است (جدول settings روی دیتابیس اعمال نشده — طبق CMD-010). مقادیر پیش‌فرض نمایش داده می‌شود و پس از اعمال DDL، بدون تغییر نرم‌افزاری فعال می‌شود.</p>'}
VR.aSet=function(){STG.on=1;if(!stgNeed())return listWait('تنظیمات عمومی');
var site='<div class="wb"><b>لوگو</b>'+drop()+'<small style="opacity:.65">آپلود لوگو نیازمند انبار شیء است (تصمیم باز گام اسناد).</small><div class="fg">'+stgInp('as_phone','تلفن','۰۲۱-۰۰۰۰۰۰۰۰','site_phone')+stgInp('as_email','ایمیل','info@dadgar.example','site_email')+'</div>'+stgInp('as_addr','نشانی','تهران، خیابان نمونه، پلاک ۱۰','site_address')+'<div class="fg">'+stgInp('as_insta','اینستاگرام','@dadgar.legal','site_instagram')+stgInp('as_tg','تلگرام','@dadgar_legal','site_telegram')+'</div>'+pendNote(STG.ready)+btn('ذخیره','','data-setsave')+'</div>';
var P=['مشاهده‌ی پرونده‌ها','مدیریت کاربران','مدیریت مالی','مدیریت محتوا'],R=['مدیر','وکیل','پشتیبان'];
var perm='<p style="opacity:.7">ماتریس دسترسی پویا نیازمند لایه‌ی مجوز سرور روی همه‌ی مسیرهاست و پس از تصمیم مدیر فعال می‌شود. نمایش زیر مطابق وضعیت فعلی است و ذخیره ندارد.</p>'+tbl(['دسترسی'].concat(R),P.map(function(p,i){return tr([p].concat(R.map(function(r,j){return '<label class="sw"><input type="checkbox"'+(j==0||(j==1&&i==0)||(j==2&&i==1)?' checked':'')+' disabled><span></span></label>'})))}))+'<div style="margin-top:14px">'+btn('ذخیره','','data-ts="دسترسی نقش‌های پویا پس از تصمیم مدیر فعال می‌شود."')+'</div>';
return '<h2 class="dh">تنظیمات عمومی</h2>'+card('',tabs('st',[['تنظیمات سایت',site],['دسترسی نقش‌ها',perm]]))};
function realSettingsSave(b){var v={};[['as_phone','site_phone'],['as_email','site_email'],['as_addr','site_address'],['as_insta','site_instagram'],['as_tg','site_telegram']].forEach(function(p){v[p[1]]=$('#'+p[0])?$('#'+p[0]).value.trim():''});
busy(b,1);api('PUT','settings',v).then(function(r){busy(b,0);if(r.ok){toast('تنظیمات ذخیره شد.');STG.map=null}else toast(r.j.error||'ذخیره ناموفق بود.')})}
function cmsTariffs(){return tbl(['خدمت','مبلغ نمایشی'],[['مشاوره‌ی تلفنی','tf_phone','tariff_phone','۳۰۰ هزار تومان'],['مشاوره‌ی حضوری','tf_meeting','tariff_meeting','۷۰۰ هزار تومان'],['تنظیم قرارداد','tf_contract','tariff_contract','از ۲ میلیون تومان']].map(function(x){return tr([x[0],'<input class="inp" id="'+x[1]+'" value="'+esc((CM.map&&CM.map[x[2]])||x[3])+'">'])}))+'<p style="opacity:.7;margin-top:10px">این مبالغ در صفحه‌ی عمومی «تعرفه‌ها» نمایش داده می‌شوند (سه ردیف اول).</p>'+pendNote(CM.ready)+'<div style="margin-top:14px">'+btn('ذخیره','','data-cmssave')+'</div>'}
VR.aCms=function(){CM.on=1;if(!cmNeed())return listWait('مدیریت محتوای سایت');
var pages=tbl(['صفحه','آخرین ویرایش','عملیات'],['درباره ما','تماس با ما','سوالات متداول'].map(function(x){return tr([x,'—','<button class="btn sm o" style="color:var(--ink)" data-ts="ویرایشگر صفحات ثابت پس از تصمیم مدیر فعال می‌شود.">ویرایش</button>'])}));
var arts=tbl(['عنوان','دسته','عملیات'],AR.slice(0,4).map(function(x){return tr([esc(x[1]),esc(x[2]),'<button class="btn sm o" style="color:var(--ink)" data-ts="مدیریت مقالات پس از تصمیم مدیر (جدول محتوا) فعال می‌شود.">ویرایش</button>'])}))+'<div style="margin-top:14px">'+btn('افزودن مقاله','','data-ts="مدیریت مقالات پس از تصمیم مدیر (جدول محتوا) فعال می‌شود."')+'</div>';
var cats='<div class="fc" style="margin-bottom:14px">'+CATS.map(function(c){return '<button class="on">'+c+'</button>'}).join('')+'</div><p style="opacity:.7">دسته‌ها به اعتبارسنجی سمت سرور ثبت پرونده متصل‌اند؛ پویاسازی آن‌ها نیازمند همگام‌سازی بک‌اند است و پس از تصمیم مدیر انجام می‌شود.</p>';
return '<h2 class="dh">مدیریت محتوای سایت</h2>'+card('',tabs('cm',[['صفحات ثابت',pages],['مقالات',arts],['دسته‌بندی‌ها',cats],['تعرفه‌ها',cmsTariffs()]]))};
function realCmsSave(b){var v={};[['tf_phone','tariff_phone'],['tf_meeting','tariff_meeting'],['tf_contract','tariff_contract']].forEach(function(p){v[p[1]]=$('#'+p[0])?$('#'+p[0]).value.trim():''});
busy(b,1);api('PUT','settings',v).then(function(r){busy(b,0);if(r.ok){toast('تعرفه‌ها ذخیره شد و در صفحه‌ی تعرفه‌ها اعمال می‌شود.');PRUB.pub=null;CM.map=null}else toast(r.j.error||'ذخیره ناموفق بود.')})}
/* صفحه‌ی عمومی «تعرفه‌ها» با override کنترل‌شده (الگوی CMD-006): ساختار مرجع عیناً حفظ می‌شود؛
 * فقط سه مبلغِ ذخیره‌شده جایگزین می‌شود. بدون داده (یا ready:false) عین مرجع است. */
VR.pricing=function(){
  if(PRUB.pub){var tf=PRUB.pub.tariffs||{},h=pricingRef();
    if(tf.phone)h=h.replace('۳۰۰ هزار تومان',esc(tf.phone));
    if(tf.meeting)h=h.replace('۷۰۰ هزار تومان',esc(tf.meeting));
    if(tf.contract)h=h.replace('از ۲ میلیون تومان',esc(tf.contract));
    return h}
  api('GET','settings/public').then(function(r){if(r.ok&&r.j.ready!==false){PRUB.pub=r.j;render(0)}});
  return pricingRef()};
var pricingRef=null;
if(!DEMO){pricingRef=V.pricing;V.pricing=VR.pricing;}
VR.aSeo=V.aSeo; /* صفحه‌ی «برنامه‌ی لندینگ‌ها و سئو» سند برنامه‌ریزی است؛ فقط نوار زرد برداشته می‌شود */

"""

BLOCK_EV = """if(!DEMO&&(a=t.closest('[data-setsave]'))){realSettingsSave(a);return}
if(!DEMO&&(a=t.closest('[data-cmssave]'))){realCmsSave(a);return}
"""

s = s.replace(ANCHOR_A, BLOCK_VR + ANCHOR_A, 1)
s = s.replace(ANCHOR_MD, BLOCK_EV + ANCHOR_MD, 1)
io.open(P, 'w', encoding='utf-8').write(s)
print('injected CMD-010 OK; new size =', len(s))
