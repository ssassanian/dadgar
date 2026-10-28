#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-006 — تزریق صفحات واقعی نظرات (VR) به web/dynamic/index.html
فایل مرجع dadgar/public/index.html دست‌نخورده می‌ماند.
این اسکریپت همیشه از مرجع شروع می‌کند: اول بلاک CMD-003 (چرخه پرونده)، سپس CMD-004
(نوبت‌دهی) و CMD-005 (مالی) و در آخر بلاک CMD-006 (نظرات) — لذا اجرای مکرر idempotent است.
دو نقطه‌ی درج با anchor دقیق:
  A) قبل از «shell, router, events» → توابع و ویوهای VR نظرات
     (VR.cRev مشتری / VR.lRev وکیل / VR.reviews صفحه‌ی عمومی)
  B) قبل از هندلر نمایشی [data-md] → هندلر واقعی ثبت نظر (data-revsave)
     — با پیش‌دستی !DEMO؛ انتخاب ستاره (data-rt) همان هندلر عمومی مرجع است و کار می‌کند."""
import io, subprocess, sys

P = '/home/z/my-project/dadgar/web/dynamic/index.html'
REF = '/home/z/my-project/dadgar/dadgar/public/index.html'
CYCLE = '/home/z/my-project/dadgar/web/scripts/inject-cycle.py'
BOOK = '/home/z/my-project/dadgar/web/scripts/inject-book.py'
BILL = '/home/z/my-project/dadgar/web/scripts/inject-bill.py'

# گام ۰: بازتولید پایه (مرجع + CMD-003 + CMD-004 + CMD-005) تا تزریق همیشه تکرارپذیر باشد
subprocess.run([sys.executable, CYCLE], check=True)
subprocess.run([sys.executable, BOOK], check=True)
subprocess.run([sys.executable, BILL], check=True)
s = io.open(P, encoding='utf-8').read()

ANCHOR_A = "/* ---------- shell, router, events ---------- */"
ANCHOR_MD = "if(a=t.closest('[data-md]')){"
for a in (ANCHOR_A, ANCHOR_MD):
    assert s.count(a) == 1, a[:40] + ' count=%d' % s.count(a)
assert 'CMD-003' in s and 'CMD-004' in s and 'CMD-005' in s, 'base blocks missing — chain failed'
assert 'CMD-006' not in s, 'already injected'

BLOCK_VR = """/* ---------- CMD-006 فاز ۳ گام ۴ — نظرات: صفحات واقعی (VR) ---------- */
var RV={on:0,uid:null,rows:null,cases:null,avg:0,count:0,pub:null};
function rvSt(r){return r.approved?tk('منتشر\u200cشده',6):r.consent?tk('در انتظار تایید مدیر',1):tk('بدون رضایت انتشار',5)}
function rvNeed(){if(RV.rows&&RV.uid===(U&&U.id))return 1;RV.uid=U&&U.id;rvFetch();return 0}
function rvFetch(){api('GET','reviews').then(function(r){if(r.ok){RV.rows=r.j.rows;RV.cases=r.j.cases||null;RV.avg=r.j.avg||0;RV.count=r.j.count||0;render(0)}else toast(r.j.error||'دریافت نظرات ناموفق بود.')})}
function rvAvgTxt(a,c){return c?(Math.round(a*10)/10).toLocaleString('fa-IR'):'۰'}
function cRevHTML(){var cs=RV.cases||[],mine=RV.rows||[];
var form=cs.length?card('نظر شما درباره‌ی وکیل پرونده','<div class="wb"><label class="lb">پرونده‌ی بسته‌شده<select class="inp" id="rvcs">'+cs.map(function(x){return '<option value="'+x.id+'">پرونده '+fa(x.id)+' — '+esc(x.title)+'</option>'}).join('')+'</select></label><h3 style="margin:12px 0 6px">امتیاز شما</h3><div class="sr">'+[1,2,3,4,5].map(function(n){return '<button data-rt="'+n+'" class="'+(n<=S.rate?'on':'')+'">★</button>'}).join('')+'</div><label class="lb" style="margin-top:10px">نظر شما<textarea class="inp" id="rvtx" rows="5"></textarea></label><label style="display:flex;gap:8px;align-items:flex-start;margin:10px 0 14px"><input type="checkbox" id="rvok" style="width:auto;margin-top:4px"><span style="opacity:.8">با انتشار عمومی نظرم (بدون ذکر نام کامل و جزئیات پرونده) موافقم.</span></label>'+btn('ثبت نظر','','data-revsave')+'</div>'):'';
var list=mine.length?card('نظرات ثبت‌شده‌ی من',tbl(['پرونده','امتیاز','وضعیت','تاریخ'],mine.map(function(r){return tr([esc(r.case_title||('پرونده '+fa(r.case_id))),stars(r.rating),rvSt(r),jdate(r.created_at)])}))):'';
return '<h2 class="dh">ثبت نظر و امتیاز</h2>'+(form||card('','<p style="opacity:.6">هنوز پرونده‌ی بسته‌شده‌ای برای نظر دادن ندارید. پس از بسته‌شدن پرونده (تایید مدیر) می‌توانید از همین صفحه نظر و امتیاز ثبت کنید.</p>'))+list}
VR.cRev=function(){RV.on=1;if(!rvNeed())return listWait('ثبت نظر و امتیاز');return cRevHTML()};
VR.lRev=function(){RV.on=1;if(!rvNeed())return listWait('امتیاز و نظرات');var rs=RV.rows||[];
var list=rs.length?rs.map(function(r){return '<div class="pb"><span><b>'+esc(r.client_initial)+'</b> '+stars(r.rating)+' '+rvSt(r)+'</span><p style="margin:6px 0">'+esc(r.body||'')+'</p><small>'+esc(r.case_title||'')+(r.category?' · '+esc(r.category):'')+' · '+jdate(r.created_at)+'</small></div>'}).join(''):'<p style="opacity:.6">هنوز نظری برای پرونده‌های شما ثبت نشده است.</p>';
return '<h2 class="dh">امتیاز و نظرات</h2><div class="g2">'+card('میانگین امتیاز','<b style="font:400 56px Lalezar">'+rvAvgTxt(RV.avg,RV.count)+'</b>'+stars(RV.count?RV.avg:0)+'<p>از '+fa(RV.count)+' نظر ثبت‌شده</p>')+card('نظرات اخیر',list)+'</div>'};
VR.reviews=function(){if(!RV.pub){api('GET','reviews/public').then(function(r){RV.pub=r.ok?r.j:{rows:[],avg:0,count:0};render(0)});return ph('نظرات موکلان','فقط نظرات معتبر و تاییدشده، با رضایت صاحب نظر')+W('<p style="opacity:.6">در حال دریافت…</p>')}
var p=RV.pub,rs=p.rows||[];
var grid=rs.length?rs.map(function(r){return '<div class="card2 fr" data-c="'+esc(r.category||'')+'" data-t="'+esc(r.body||'')+'"><div class="row"><b>'+esc(r.client_initial)+'</b><span class="sc s6">تاییدشده · با رضایت موکل</span></div><div>'+stars(r.rating)+'</div><p>'+esc(r.body||'')+'</p><small>'+esc(r.category||'')+' · '+jdate(r.created_at)+'</small></div>'}).join(''):'<p style="opacity:.6">هنوز نظری منتشر نشده است. نظرات پس از تایید مدیر و با رضایت موکل اینجا نمایش داده می‌شوند.</p>';
return ph('نظرات موکلان','فقط نظرات معتبر و تاییدشده، با رضایت صاحب نظر')+W('<div class="g2">'+card('میانگین رضایت','<b style="font:400 56px Lalezar">'+rvAvgTxt(p.avg,p.count)+'</b>'+stars(p.count?p.avg:0)+'<p>بر اساس نظرات تاییدشده‌ی موکلان</p>')+card('سیاست انتشار نظرات','<ul class="ck"><li>فقط موکلان پرونده‌ی بسته‌شده نظر ثبت می‌کنند.</li><li>انتشار با رضایت صاحب نظر و تایید مدیر سامانه انجام می‌شود.</li><li>نام کامل و جزئیات پرونده منتشر نمی‌شود.</li></ul>')+'</div><div class="fl">'+fbar(['ملکی','خانواده','شرکت‌ها','ارث و وصیت'],'جستجو…')+'<div class="gr" style="margin-top:20px">'+grid+'</div></div>'+card('ثبت نظر','<p>پس از بسته‌شدن پرونده می‌توانید از پنل خود نظر ثبت کنید.</p><a class="btn sm n" href="#/c/review">ثبت نظر در پنل<span class="ar">←</span></a>'))};
function realReview(b){if(!$('#rvcs')){toast('پرونده‌ی بسته‌شده‌ای برای نظر دادن ندارید');return}var csi=$('#rvcs').value,txt=$('#rvtx')?$('#rvtx').value.trim():'';
if(S.rate<1){toast('امتیاز را انتخاب کنید');return}
if(txt.length<3){toast('متن نظر را وارد کنید');return}
busy(b,1);api('POST','reviews',{case_id:+csi,rating:S.rate,body:txt,consent:!!($('#rvok')&&$('#rvok').checked)}).then(function(r){busy(b,0);if(r.ok){toast('نظر شما ثبت شد. سپاس!');S.rate=0;RV.rows=null;rvFetch()}else toast(r.j.error||'ثبت نظر ناموفق بود.')})}
/* کشف معماری CMD-006: شاخه‌ی مهمان در render() صفحات عمومی را مستقیم از V[fn] در #app رندر
 * می‌کند (بدون VR و بدون DEMOBN). پس صفحه‌ی عمومی نظرات با override کنترل‌شده وصل می‌شود: */
if(!DEMO&&VR.reviews)V.reviews=VR.reviews;

"""

BLOCK_EV = """if(!DEMO&&RV.on&&(a=t.closest('[data-revsave]'))){realReview(a);return}
"""

s = s.replace(ANCHOR_A, BLOCK_VR + ANCHOR_A, 1)
s = s.replace(ANCHOR_MD, BLOCK_EV + ANCHOR_MD, 1)
io.open(P, 'w', encoding='utf-8').write(s)
print('injected CMD-006 OK; new size =', len(s))
