#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-007 — تزریق صفحات واقعی پیام/تیکت (VR) به web/dynamic/index.html
فایل مرجع dadgar/public/index.html دست‌نخورده می‌ماند.
این اسکریپت همیشه از مرجع شروع می‌کند: اول بلاک‌های CMD-003 (چرخه پرونده)، CMD-004
(نوبت‌دهی)، CMD-005 (مالی) و CMD-006 (نظرات) و در آخر بلاک CMD-007 — لذا اجرای
مکرر idempotent است. دو نقطه‌ی درج با anchor دقیق:
  A) قبل از «shell, router, events» → ویوهای VR پیام/تیکت
     (VR.tk / VR.tkNew / VR.tkDet مشترک سه نقش + VR.chat برای مشتری و وکیل)
  B) قبل از هندلر نمایشی [data-md] → هندلرهای واقعی:
     data-tkcreate / data-tkreply / data-tkapply / data-th / data-msgsend
     + شنونده‌ی change برای فیلترهای تیکت مدیر و اصلاح فیلتر «وکیل» مالی (CMD-005)."""
import io, subprocess, sys

P = '/home/z/my-project/dadgar/web/dynamic/index.html'
REF = '/home/z/my-project/dadgar/dadgar/public/index.html'
CYCLE = '/home/z/my-project/dadgar/web/scripts/inject-cycle.py'
BOOK = '/home/z/my-project/dadgar/web/scripts/inject-book.py'
BILL = '/home/z/my-project/dadgar/web/scripts/inject-bill.py'
REV = '/home/z/my-project/dadgar/web/scripts/inject-rev.py'

# گام ۰: بازتولید پایه (مرجع + CMD-003..006) تا تزریق همیشه تکرارپذیر باشد
subprocess.run([sys.executable, CYCLE], check=True)
subprocess.run([sys.executable, BOOK], check=True)
subprocess.run([sys.executable, BILL], check=True)
subprocess.run([sys.executable, REV], check=True)
s = io.open(P, encoding='utf-8').read()

ANCHOR_A = "/* ---------- shell, router, events ---------- */"
ANCHOR_MD = "if(a=t.closest('[data-md]')){"
for a in (ANCHOR_A, ANCHOR_MD):
    assert s.count(a) == 1, a[:40] + ' count=%d' % s.count(a)
assert 'CMD-003' in s and 'CMD-004' in s and 'CMD-005' in s and 'CMD-006' in s, 'base blocks missing — chain failed'
assert 'CMD-007' not in s, 'already injected'

BLOCK_VR = """/* ---------- CMD-007 فاز ۳ گام ۵ — پیام/تیکت: صفحات واقعی (VR) ---------- */
var TKST={open:['باز',1],review:['در حال بررسی',4],answered:['پاسخ داده\u200cشده',3],closed:['بسته',5]};
var TKDEPTS=['فنی','مالی','شکایات','عمومی','حقوقی'],TKPRIS=['کم','متوسط','بالا'];
var TK={on:0,uid:null,rows:null,det:null,tid:0,f:{st:'',dp:'',pr:''}};
var MG={on:0,uid:null,threads:null,cur:0,rows:null};
function tktSt(s){var b=TKST[s]||TKST.open;return tk(b[0],b[1])}
function tkQ(){var q=[];if(TK.f.st)q.push('status='+TK.f.st);if(TK.f.dp)q.push('dept='+encodeURIComponent(TK.f.dp));if(TK.f.pr)q.push('priority='+encodeURIComponent(TK.f.pr));return q.length?'?'+q.join('&'):''}
function tkFetch(){api('GET','tickets'+tkQ()).then(function(r){if(r.ok){TK.rows=r.j.rows;render(0)}else toast(r.j.error||'دریافت تیکت\u200cها ناموفق بود.')})}
function tkNeed(){if(TK.rows&&TK.uid===(U&&U.id))return 1;TK.uid=U&&U.id;TK.rows=null;tkFetch();return 0}
VR.tk=function(){TK.on=1;if(!tkNeed())return listWait(U.role=='admin'?'مدیریت تیکت\u200cها':'پشتیبانی و تیکت\u200cها');
var isA=U.role=='admin',rs=TK.rows||[];
var head='<div class="row"><h2 class="dh">'+(isA?'مدیریت تیکت\u200cها':'پشتیبانی و تیکت\u200cها')+'</h2>'+(isA?'':'<a class="btn sm" href="#/'+RL[U.role]+'/ticket/new" style="margin-inline-start:auto">ارسال تیکت جدید<span class="ar">←</span></a>')+'</div>';
var body=rs.length?tbl(['شماره','موضوع','بخش','اولویت','وضعیت','پیام\u200cها','به\u200cروزرسانی'],rs.map(function(t){return tr([(isA?'<b>'+esc(t.user_name)+'</b> · ':'')+'<a href="#/'+RL[U.role]+'/ticket/'+t.id+'">'+fa(t.id)+'</a>',esc(t.subject),esc(t.dept||'—'),esc(t.priority||'—'),tktSt(t.status),fa(t.msg_count||0),jdate(t.updated_at)])})):'<p style="opacity:.6">'+(isA?'تیکتی ثبت نشده است.':'هنوز تیکتی ندارید. برای پشتیبانی تیکت جدید باز کنید.')+'</p>';
return head+(isA?'<div class="row" style="margin-bottom:14px">'+selOpt('tkfd','بخش',[['','همه']].concat(TKDEPTS.map(function(d){return [d,d]})),TK.f.dp)+selOpt('tkfs','وضعیت',[['','همه']].concat(Object.keys(TKST).map(function(k){return [k,TKST[k][0]]})),TK.f.st)+selOpt('tkfp','اولویت',[['','همه']].concat(TKPRIS.map(function(p){return [p,p]})),TK.f.pr)+'</div>':'')+card('',body)};
VR.tkNew=function(){TK.on=1;
return '<h2 class="dh">ارسال تیکت جدید</h2>'+card('','<div class="wb"><div class="fg">'+selOpt('tkd','بخش',TKDEPTS.map(function(d){return [d,d]}),'فنی')+selOpt('tkp','اولویت',TKPRIS.map(function(p){return [p,p]}),'متوسط')+'</div>'+inp('tks','موضوع')+'<label class="lb">توضیحات<textarea class="inp" id="tkb" rows="6"></textarea></label>'+btn('ارسال تیکت','','data-tkcreate')+'</div>')};
VR.tkDet=function(id){id=+id;TK.on=1;if(TK.det&&TK.tid===id)return tkDetHTML(TK.det);TK.tid=id;TK.det=null;
api('GET','tickets/'+id).then(function(r){if(r.ok){TK.det=r.j;render(0)}else{toast(r.j.error||'تیکت یافت نشد.');location.hash='#/'+RL[U.role]+'/tickets'}});
return listWait('تیکت '+fa(id))};
function tkDetHTML(d){var t=d.ticket,ms=d.rows||[],isA=U.role=='admin',closed=t.status=='closed';
var conv=ms.length?ms.map(function(m){return '<div class="m'+(m.mine?' me':'')+'">'+esc(m.body)+(isA?'<small>'+esc(m.name||'')+(m.mine?' (شما)':'')+'</small>':'')+'<small>'+jdate(m.created_at)+'</small></div>'}).join(''):'<p style="opacity:.6">پیامی ردوبدل نشده است.</p>';
var rep=(closed&&!isA)?'<p style="opacity:.6;margin-top:12px">این تیکت بسته شده است؛ برای موضوع جدید تیکت جدیدی باز کنید.</p>':'<div class="cin" style="padding:14px 0 0"><input class="inp" id="tkrep" placeholder="پاسخ شما\u2026">'+btn('ارسال','','data-tkreply')+'</div>';
var info='<div class="pb"><span>وضعیت</span>'+tktSt(t.status)+'</div><div class="pb"><span>بخش</span><b>'+esc(t.dept||'—')+'</b></div><div class="pb"><span>اولویت</span><b>'+esc(t.priority||'—')+'</b></div><div class="pb"><span>تاریخ ایجاد</span><b>'+jdate(t.created_at)+'</b></div><div class="pb"><span>به\u200cروزرسانی</span><b>'+jdate(t.updated_at)+'</b></div>'+(isA?'<div class="pb"><span>ارسال\u200cکننده</span><b>'+esc(t.user_name||'—')+'</b></div>'+selOpt('tkst','تغییر وضعیت',Object.keys(TKST).map(function(k){return [k,TKST[k][0]]}),t.status)+selOpt('tkdp','ارجاع به بخش',[['','—']].concat(TKDEPTS.map(function(d){return [d,d]})),'')+btn('اعمال','','data-tkapply'):'');
return '<div class="row"><h2 class="dh">تیکت '+fa(t.id)+'</h2>'+tktSt(t.status)+'</div><p style="margin-top:-6px">'+esc(t.subject)+'</p><div class="g2">'+card('مکالمه','<div class="msgs" style="padding:0">'+conv+'</div>'+rep)+card('اطلاعات تیکت',info)+'</div>'}
function mgNeed(){if(MG.threads&&MG.uid===(U&&U.id))return 1;MG.uid=U&&U.id;MG.threads=null;
api('GET','threads').then(function(r){if(r.ok){MG.threads=r.j.rows;render(0)}else toast(r.j.error||'دریافت گفتگوها ناموفق بود.')});return 0}
function mgLoad(cid){MG.cur=cid;MG.rows=null;api('GET','messages?case_id='+cid).then(function(r){if(r.ok){MG.rows=r.j;render(0)}else toast(r.j.error||'دریافت پیام\u200cها ناموفق بود.')})}
VR.chat=function(){MG.on=1;if(!mgNeed())return listWait('پیام\u200cها');
var th=MG.threads||[];
if(!th.length)return '<h2 class="dh">پیام\u200cها</h2>'+card('','<p style="opacity:.6">هنوز گفتگوی فعالی ندارید. گفتگوی پیام هر پرونده پس از تخصیص وکیل و در جریان بودن کار باز می\u200cشود.</p>');
if(!MG.cur)MG.cur=th[0].case_id;
if(!MG.rows){mgLoad(MG.cur);return listWait('پیام\u200cها')}
var cur=null;th.forEach(function(x){if(x.case_id==MG.cur)cur=x});
var list=th.map(function(x){return '<button class="'+(x.case_id==MG.cur?'on':'')+'" data-th="'+x.case_id+'">'+esc(x.title)+'<small>'+(x.last_excerpt?esc(x.last_excerpt):'بدون پیام')+'</small></button>'}).join('');
var ms=(MG.rows.rows||[]).map(function(m){return '<div class="m'+(m.mine?' me':'')+'">'+esc(m.body)+'<small>'+jdate(m.created_at)+'</small></div>'}).join('')||'<p style="opacity:.6;padding:14px">اولین پیام را بنویسید.</p>';
return '<h2 class="dh">پیام\u200cها</h2>'+(cur?'<p style="margin-top:-6px;opacity:.75">گفتگوی پرونده\u200cی <a href="#/'+RL[U.role]+'/case/'+cur.case_id+'">'+fa(cur.case_id)+'</a> — '+esc(cur.title)+'</p>':'')+'<div class="card2 chx"><div class="cl">'+list+'</div><div class="cm"><div class="msgs">'+ms+'</div><div class="cin"><input class="inp" id="mgtx" placeholder="پیام خود را بنویسید"><button class="btn sm" data-msgsend>ارسال<span class="ar">←</span></button></div></div></div>'};
function realTicketCreate(b){var d=$('#tkd')?$('#tkd').value:'',p=$('#tkp')?$('#tkp').value:'',s=$('#tks')?$('#tks').value.trim():'',x=$('#tkb')?$('#tkb').value.trim():'';
if(s.length<3){toast('موضوع را وارد کنید (حداقل ۳ حرف)');return}
if(x.length<3){toast('متن تیکت را وارد کنید');return}
busy(b,1);api('POST','tickets',{subject:s,dept:d,priority:p,body:x}).then(function(r){busy(b,0);if(r.ok){toast('تیکت ارسال شد');TK.rows=null;TK.uid=null;location.hash='#/'+RL[U.role]+'/tickets'}else toast(r.j.error||'ارسال تیکت ناموفق بود.')})}
function realTicketReply(b){var i=$('#tkrep'),v=i?i.value.trim():'';
if(!v){toast('متن پاسخ را وارد کنید');return}
busy(b,1);api('POST','tickets/'+TK.tid+'/replies',{body:v}).then(function(r){busy(b,0);if(i)i.value='';if(r.ok){toast('پاسخ شما ثبت شد');TK.det=null;TK.rows=null;api('GET','tickets/'+TK.tid).then(function(x){if(x.ok){TK.det=x.j;render(0)}})}else toast(r.j.error||'ارسال پاسخ ناموفق بود.')})}
function realTicketApply(b){var st=$('#tkst')?$('#tkst').value:null,dp=$('#tkdp')?$('#tkdp').value:null;
busy(b,1);api('PATCH','tickets/'+TK.tid,{status:st,dept:dp||null,priority:null}).then(function(r){busy(b,0);if(r.ok){toast('تغییرات ثبت شد');TK.det=null;TK.rows=null;api('GET','tickets/'+TK.tid).then(function(x){if(x.ok){TK.det=x.j;render(0)}})}else toast(r.j.error||'ثبت تغییرات ناموفق بود.')})}
function realMsgSend(b){var i=$('#mgtx'),v=i?i.value.trim():'';
if(!v){toast('متن پیام را وارد کنید');return}
busy(b,1);api('POST','messages',{case_id:MG.cur,body:v}).then(function(r){busy(b,0);if(i)i.value='';if(r.ok){MG.threads=null;MG.uid=null;mgLoad(MG.cur)}else toast(r.j.error||'ارسال پیام ناموفق بود.')})}
/* شنونده‌ی change: فیلترهای تیکت مدیر + اصلاح ایراد پنهان CMD-005 (فیلتر «وکیل» مالی به change وصل نبود) */
document.addEventListener('change',function(e){if(DEMO)return;var i=e.target&&e.target.id;
if(TK.on&&i=='tkfs'){TK.f.st=e.target.value;TK.rows=null;tkFetch()}
else if(TK.on&&i=='tkfd'){TK.f.dp=e.target.value;TK.rows=null;tkFetch()}
else if(TK.on&&i=='tkfp'){TK.f.pr=e.target.value;TK.rows=null;tkFetch()}
else if(i=='blw'&&typeof BI!=='undefined'&&BI.on){BI.lw=e.target.value;render(0)}});

"""

BLOCK_EV = """if(!DEMO&&TK.on&&(a=t.closest('[data-tkcreate]'))){realTicketCreate(a);return}
if(!DEMO&&TK.on&&(a=t.closest('[data-tkreply]'))){realTicketReply(a);return}
if(!DEMO&&TK.on&&(a=t.closest('[data-tkapply]'))){realTicketApply(a);return}
if(!DEMO&&MG.on&&(a=t.closest('[data-th]'))){mgLoad(+a.dataset.th);return}
if(!DEMO&&MG.on&&(a=t.closest('[data-msgsend]'))){realMsgSend(a);return}
"""

s = s.replace(ANCHOR_A, BLOCK_VR + ANCHOR_A, 1)
s = s.replace(ANCHOR_MD, BLOCK_EV + ANCHOR_MD, 1)
io.open(P, 'w', encoding='utf-8').write(s)
print('injected CMD-007 OK; new size =', len(s))
