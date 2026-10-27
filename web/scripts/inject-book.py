#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-004 — تزریق صفحات واقعی نوبت‌دهی (VR) به web/dynamic/index.html
فایل مرجع dadgar/public/index.html دست‌نخورده می‌ماند.
این اسکریپت همیشه از مرجع شروع می‌کند: اول بلاک CMD-003 (چرخه پرونده) اعمال می‌شود،
سپس بلاک CMD-004 (نوبت‌دهی) — لذا اجرای مکرر idempotent است.
چهار نقطه‌ی درج با anchor دقیق:
  A) قبل از «shell, router, events» → توابع و ویوهای VR نوبت‌دهی
  B) قبل از هندلر [data-day] → پیش‌دستی برای رندر واقعی بازه‌ها (#sl[data-bk])
  C) قبل از هندلر [data-book] نمایشی → ثبت واقعی نوبت
  D) قبل از هندلر [data-w] → تایید/لغو/رد نوبت (data-bkok / data-bkx)"""
import io, subprocess, sys

P = '/home/z/my-project/dadgar/web/dynamic/index.html'
REF = '/home/z/my-project/dadgar/dadgar/public/index.html'
CYCLE = '/home/z/my-project/dadgar/web/scripts/inject-cycle.py'

# گام ۰: بازتولید پایه (مرجع + CMD-003) تا تزریق همیشه تکرارپذیر باشد
subprocess.run([sys.executable, CYCLE], check=True)
s = io.open(P, encoding='utf-8').read()

ANCHOR_A = "/* ---------- shell, router, events ---------- */"
ANCHOR_DAY = "if(a=t.closest('[data-day]')){"
ANCHOR_BOOK = "if(a=t.closest('[data-book]')){"
ANCHOR_B = "if(a=t.closest('[data-w]')){"
for a in (ANCHOR_A, ANCHOR_DAY, ANCHOR_BOOK, ANCHOR_B):
    assert s.count(a) == 1, a[:40] + ' count=%d' % s.count(a)
assert 'CMD-003' in s, 'CMD-003 block missing — inject-cycle failed'
assert 'CMD-004' not in s, 'already injected'

BLOCK_VR = """/* ---------- CMD-004 فاز ۳ گام ۲ — نوبت‌دهی: صفحات واقعی (VR) ---------- */
var BKAB1=Date.UTC(2026,9,22,20,30,0)/1000; /* ۱۴۰۵/۰۸/۰۱ ۰۰:۰۰ تهران (UTC+3:30 ثابت) — هماهنگ با web.js */
var BKSLOTS=[['۰۹:۰۰',540],['۱۰:۳۰',630],['۱۲:۰۰',720],['۱۶:۰۰',960],['۱۷:۳۰',1050]];
var BKST={booked:['رزرو\u200cشده',1],confirmed:['تایید\u200cشده',6],canceled:['لغو\u200cشده',5]};
var AP={on:0,uid:null,rows:null,taken:null,now:0,today:1};
function bkSt(s){var b=BKST[s]||BKST.booked;return tk(b[0],b[1])}
function bkWhen(r){return (r.day>=1&&r.day<=30)?fa(r.day)+' آبان، ساعت '+r.slot:jdate(r.starts_at)}
function apNeed(){if(AP.rows&&AP.uid===(U&&U.id))return 1;AP.uid=U&&U.id;apFetch();return 0}
function apFetch(){api('GET','appointments').then(function(r){if(r.ok){AP.rows=r.j.rows;AP.taken=r.j.taken||[];AP.now=r.j.now;AP.today=r.j.today_d;render(0)}else toast(r.j.error||'دریافت نوبت‌ها ناموفق بود.')})}
function apBusyDays(){var t={};for(var i=0;i<AP.taken.length;i++)t[AP.taken[i].d]=1;return t}
function calR(mode){var bd=apBusyDays(),h='<div class="cal"><div class="chh">آبان ۱۴۰۵</div><div class="cgd">'+['ش','ی','د','س','چ','پ','ج'].map(function(d){return '<i>'+d+'</i>'}).join('')+'<i></i><i></i><i></i><i></i><i></i><i></i>';
for(var n=1;n<=30;n++){var dis=(mode=='c')&&(((n+5)%7==6)||(AP.today&&n<AP.today));h+='<button class="dy'+(S.day==n?' on':'')+(bd[n]?' bz':'')+'" data-day="'+n+'"'+(dis?' disabled':'')+'>'+fa(n)+'</button>'}
return h+'</div></div>'}
function apSlotsHTML(){var tkd={};for(var i=0;i<AP.taken.length;i++)tkd[AP.taken[i].d+'|'+AP.taken[i].j]=1;
return '<div class="sl">'+BKSLOTS.map(function(s){var past=S.day>0&&S.day<AP.today,past2=S.day>0&&S.day==AP.today&&(BKAB1+(S.day-1)*86400+s[1]*60)<=AP.now,dis=tkd[S.day+'|'+s[0]]||past||past2;
return '<button data-slot="'+s[0]+'" class="'+(S.slot==s[0]?'on':'')+'"'+(dis?' disabled':'')+'>'+s[0]+'</button>'}).join('')+'</div>'}
function bookedList(){var rs=(AP.rows||[]).filter(function(r){return r.status!='canceled'});
return card('نوبت‌های رزرو‌شده',rs.length?rs.map(function(r){var can=r.starts_at>AP.now;
return '<div class="pb"><span>'+bkWhen(r)+' · '+esc(r.kind)+' '+bkSt(r.status)+'</span><span class="row">'+(can?'<button class="btn sm n" data-bkx="'+r.id+'">لغو</button>':'')+'</span></div>'}).join(''):'<p style="opacity:.6">هنوز نوبتی رزرو نکرده\u200cاید.</p>')}
VR.cBook=function(){AP.on=1;if(!apNeed())return listWait('رزرو نوبت');
return '<h2 class="dh">رزرو نوبت</h2><div class="g2"><div class="card2"><div class="row" style="align-items:flex-start">'+calR('c')+'<div style="flex:1;min-width:230px"><h3>زمان‌های خالی</h3><div id="sl" data-bk="1">'+apSlotsHTML()+'</div><h3 style="margin-top:18px">نوع ملاقات</h3><div class="fc" data-ty>'+['حضوری','آنلاین','تلفنی'].map(function(x){return '<button data-ty="'+x+'" class="'+(S.ty==x?'on':'')+'">'+x+'</button>'}).join('')+'</div><div style="margin-top:18px">'+btn('تایید نوبت','','data-book')+'</div></div></div></div>'+bookedList()};
function realBook(){if(!S.day||!S.slot){toast('روز و ساعت را انتخاب کنید');return}
modal('تایید نوبت','نوبت '+S.ty+' در '+fa(S.day)+' آبان ساعت '+S.slot+' ثبت شود؟',function(){api('POST','appointments',{day:S.day,slot:S.slot,kind:S.ty}).then(function(r){if(r.ok){toast('نوبت شما ثبت شد');AP.rows=null;apFetch()}else toast(r.j.error||'ثبت نوبت ناموفق بود.')})})}
function lawyerList(){var rs=(AP.rows||[]).filter(function(r){return r.status!='canceled'});
return rs.length?rs.map(function(r){return '<div class="pb"><b>'+bkWhen(r)+'</b><span>مراجعه‌کننده #'+fa(r.client_id)+' · '+esc(r.kind)+' '+bkSt(r.status)+'</span></div>'}).join(''):'<p style="opacity:.6">فعلاً نوبتی ثبت نشده است.</p>'}
VR.lCal=function(){AP.on=1;if(!apNeed())return listWait('تقویم من');
return '<h2 class="dh">تقویم من</h2><div class="g2"><div class="card2"><h3>بازه‌های روز انتخابی</h3><div class="row" style="align-items:flex-start">'+calR('v')+'<div style="flex:1;min-width:230px"><b>'+(S.day?fa(S.day)+' آبان':'برای دیدن بازه‌ها یک روز را انتخاب کنید')+'</b><div style="margin:12px 0">'+apSlotsHTML()+'</div><small style="opacity:.65">بازه‌های اشغال‌شده بر اساس نوبت‌های ثبت‌شده غیرفعال‌اند؛ تعیین بازه‌های دلخواه وکیل نیازمند جدول «در دسترس» و تصمیم مدیر است.</small></div></div></div>'+card('نوبت‌های رزرو‌شده',lawyerList())+'</div>'};
function aAppTbl(){var rs=AP.rows||[];if(!rs.length)return '<p style="opacity:.6">هنوز نوبتی ثبت نشده است.</p>';
return '<p style="margin-bottom:10px">نام مشتری/وکیل فقط برای مدیر نمایش داده می‌شود. «جابجایی» نوبت پس از تصمیم طراحی (تقویم ویرایشی) اضافه می‌شود.</p>'+tbl(['زمان','مشتری','وکیل','وضعیت','عملیات'],rs.map(function(r){
var ops=r.status=='canceled'?'—':'<span class="row">'+(r.status=='booked'?'<button class="btn sm" data-bkok="'+r.id+'">تایید</button>':'')+'<button class="btn sm n" data-bkx="'+r.id+'">رد</button></span>';
return tr([bkWhen(r),esc(r.client_name||'—'),esc(r.lawyer_name||'—'),bkSt(r.status),ops])}))}
VR.aApp=function(){AP.on=1;if(!apNeed())return listWait('مدیریت نوبت‌دهی');
return '<h2 class="dh">مدیریت نوبت‌دهی</h2><div class="g2"><div class="card2"><h3>تقویم کلی دفتر</h3>'+calR('v')+'</div>'+card('نوبت‌ها',aAppTbl())+'</div>'};

"""

BLOCK_DAY = """if(!DEMO&&AP.on&&(a=t.closest('[data-day]'))){var sl=$('#sl');if(!sl||sl.dataset.bk){S.day=+a.dataset.day;S.slot='';var g=a.closest('.cal');$$('.dy',g).forEach(function(b){b.classList.toggle('on',b==a)});if(sl)sl.innerHTML=apSlotsHTML();return}}
"""

BLOCK_BOOK = """if(!DEMO&&(a=t.closest('[data-book]'))){realBook();return}
"""

BLOCK_EV = """if(!DEMO&&(a=t.closest('[data-bkok]'))){var bko=+a.dataset.bkok;modal('تایید نوبت','این نوبت تایید شود؟',function(){api('PATCH','appointments/'+bko,{status:'confirmed'}).then(function(r){if(r.ok){toast('نوبت تایید شد');AP.rows=null;apFetch()}else toast(r.j.error||'تایید ناموفق بود.')})});return}
if(!DEMO&&(a=t.closest('[data-bkx]'))){var bkx=+a.dataset.bkx;modal('لغو نوبت','آیا از لغو این نوبت مطمئن هستید؟',function(){api('PATCH','appointments/'+bkx,{status:'canceled'}).then(function(r){if(r.ok){toast('نوبت لغو شد');AP.rows=null;apFetch()}else toast(r.j.error||'لغو ناموفق بود.')})});return}
"""

s = s.replace(ANCHOR_A, BLOCK_VR + ANCHOR_A, 1)
s = s.replace(ANCHOR_DAY, BLOCK_DAY + ANCHOR_DAY, 1)
s = s.replace(ANCHOR_BOOK, BLOCK_BOOK + ANCHOR_BOOK, 1)
s = s.replace(ANCHOR_B, BLOCK_EV + ANCHOR_B, 1)
io.open(P, 'w', encoding='utf-8').write(s)
print('injected CMD-004 OK; new size =', len(s))
