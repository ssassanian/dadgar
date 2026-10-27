#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-005 — تزریق صفحات واقعی مالی (VR) به web/dynamic/index.html
فایل مرجع dadgar/public/index.html دست‌نخورده می‌ماند.
این اسکریپت همیشه از مرجع شروع می‌کند: اول بلاک CMD-003 (چرخه پرونده)، سپس CMD-004
(نوبت‌دهی) و در آخر بلاک CMD-005 (مالی) — لذا اجرای مکرر idempotent است.
دو نقطه‌ی درج با anchor دقیق:
  A) قبل از «shell, router, events» → توابع و ویوهای VR مالی (VR.cBill / VR.aFin)
  B) قبل از هندلر نمایشی [data-md] → هندلرهای واقعی مالی (data-bpd / data-bpay /
     data-bropen / data-billm) — همه با پیش‌دستی !DEMO و return"""
import io, subprocess, sys

P = '/home/z/my-project/dadgar/web/dynamic/index.html'
REF = '/home/z/my-project/dadgar/dadgar/public/index.html'
CYCLE = '/home/z/my-project/dadgar/web/scripts/inject-cycle.py'
BOOK = '/home/z/my-project/dadgar/web/scripts/inject-book.py'

# گام ۰: بازتولید پایه (مرجع + CMD-003 + CMD-004) تا تزریق همیشه تکرارپذیر باشد
subprocess.run([sys.executable, CYCLE], check=True)
subprocess.run([sys.executable, BOOK], check=True)
s = io.open(P, encoding='utf-8').read()

ANCHOR_A = "/* ---------- shell, router, events ---------- */"
ANCHOR_MD = "if(a=t.closest('[data-md]')){"
for a in (ANCHOR_A, ANCHOR_MD):
    assert s.count(a) == 1, a[:40] + ' count=%d' % s.count(a)
assert 'CMD-003' in s and 'CMD-004' in s, 'base blocks missing — chain failed'
assert 'CMD-005' not in s, 'already injected'

BLOCK_VR = """/* ---------- CMD-005 فاز ۳ گام ۳ — مالی: صفحات واقعی (VR) ---------- */
var FY1405=Date.UTC(2026,2,20,20,30,0)/1000; /* ۱۴۰۵/۰۱/۰۱ ۰۰:۰۰ تهران (UTC+3:30 ثابت) — هماهنگ با web.js */
var BIST={pending:['در انتظار',1],paid:['پرداخت\u200cشده',6]};
var BI={on:0,uid:null,rows:null,now:0,today:1,pd:0,lw:'',users:null};
function biSt(s){var b=BIST[s]||BIST.pending;return tk(b[0],b[1])}
function biNeed(){if(BI.rows&&BI.uid===(U&&U.id))return 1;BI.uid=U&&U.id;biFetch();return 0}
function biFetch(){api('GET','invoices').then(function(r){if(r.ok){BI.rows=r.j.rows;BI.now=r.j.now;BI.today=r.j.today_d;render(0)}else toast(r.j.error||'دریافت فاکتورها ناموفق بود.')})}
function biUsers(){if(BI.users)return;api('GET','users?role=client').then(function(r){if(r.ok){BI.users=r.j.rows;render(0)}else toast(r.j.error||'دریافت فهرست مشتریان ناموفق بود.')})}
function biMonthSum(){var rs=BI.rows||[],m0=BKAB1,d0=BKAB1+((BI.today||1)-1)*86400,sum=0,pend=0,tod=0;
for(var i=0;i<rs.length;i++){var r=rs[i];if(r.status=='pending')pend++;if(r.status=='paid'){if(r.paid_at>=m0)sum+=r.amount;if(r.paid_at>=d0)tod++}}
return {sum:sum,pend:pend,tod:tod}}
function biRangeStart(){return BI.pd==0?BKAB1:BI.pd==1?BKAB1-30*86400:FY1405} /* این ماه/سه ماه/امسال ۱۴۰۵ */
function selOpt(id,l,pairs,cur){return '<label class="lb">'+l+'<select class="inp" id="'+id+'">'+pairs.map(function(p){return '<option value="'+esc(p[0])+'"'+(String(cur)==String(p[0])?' selected':'')+'>'+p[1]+'</option>'}).join('')+'</select></label>'}
function aFinTbl(){var rs=(BI.rows||[]).filter(function(r){return r.created_at>=biRangeStart()}).filter(function(r){return !BI.lw||r.lawyer_name==BI.lw});
if(!rs.length)return '<p style="opacity:.6">فاکتوری در این بازه یافت نشد.</p>';
return tbl(['فاکتور','مشتری','وکیل','مبلغ','وضعیت','عملیات'],rs.map(function(r){var op=r.status=='pending'?'<button class="btn sm" data-bpay="'+r.id+'">ثبت پرداخت</button>':'<button class="btn sm o" style="color:var(--ink)" data-bropen="'+r.id+'">بازکردن</button>';
return tr([fa(r.id),esc(r.client_name||'—'),esc(r.lawyer_name||'—'),jmoney(r.amount),biSt(r.status),op])}))}
function aFinHTML(){var st=biMonthSum(),mst=(Math.round(st.sum/100000)/10).toLocaleString('fa-IR'),lw=[];(BI.rows||[]).forEach(function(r){if(r.lawyer_name&&lw.indexOf(r.lawyer_name)<0)lw.push(r.lawyer_name)});
return '<h2 class="dh">مدیریت مالی</h2><div class="gr" style="--m:220px">'+stat('درآمد این ماه',mst+' م.ت','card')+stat('فاکتور در انتظار',fa(st.pend),'file')+stat('پرداخت‌های امروز',fa(st.tod),'chart')+'</div>'
+card('گزارش درآمد','<div class="row" style="margin-bottom:14px"><div class="fc">'+['این ماه','سه ماه','امسال'].map(function(x,i){return '<button data-bpd="'+i+'" class="'+(BI.pd==i?'on':'')+'">'+x+'</button>'}).join('')+'</div>'+selOpt('blw','وکیل',[['','همه']].concat(lw.map(function(n){return [n,n]})),BI.lw)+'<button class="btn sm o" style="color:var(--ink)" data-ts="خروجی اکسل پس از تصمیم مدیر فعال می‌شود.">اکسل</button><button class="btn sm o" style="color:var(--ink)" data-ts="خروجی PDF پس از تصمیم مدیر فعال می‌شود.">PDF</button></div>'+aFinTbl())
+card('صدور فاکتور دستی','<div class="wb"><div class="fg">'+selOpt('bcl','مشتری',[['','انتخاب مشتری\u200c…']].concat((BI.users||[]).map(function(u){return [u.id,esc(u.name)+' (#'+fa(u.id)+')']})),'')+'</div>'+inp('bam','مبلغ (تومان)','text','dir="ltr" inputmode="numeric"')+'<p style="opacity:.65">شرح فاکتور نیازمند ستون جدید در جدول invoices است (تصمیم مدیر). اتصال فاکتور به پرونده با API ممکن است و UI آن پس از تصمیم اضافه می‌شود.</p>'+btn('صدور فاکتور','','data-billm')+'</div>')}
VR.cBill=function(){BI.on=1;if(!biNeed())return listWait('صورتحساب‌ها و پرداخت');
var rs=BI.rows||[];
return '<h2 class="dh">صورتحساب‌ها و پرداخت</h2>'+card('',rs.length?tbl(['فاکتور','تاریخ','مبلغ','وضعیت','عملیات'],rs.map(function(r){var ops='<span class="row"><button class="btn sm o" style="color:var(--ink)" data-ts="خروجی PDF پس از تصمیم مدیر فعال می‌شود.">دانلود PDF</button>'+(r.status=='pending'?'<button class="btn sm" data-ts="درگاه پرداخت هنوز متصل نشده است؛ پس از تصمیم مدیر فعال می‌شود.">پرداخت آنلاین</button>':'')+'</span>';
return tr([fa(r.id),jdate(r.created_at),jmoney(r.amount),biSt(r.status),ops])})):'<p style="opacity:.6">هنوز فاکتوری برای شما صادر نشده است.</p>')};
VR.aFin=function(){BI.on=1;if(!biNeed())return listWait('مدیریت مالی');biUsers();return aFinHTML()};
function realInvoice(b){var cv=$('#bcl')?$('#bcl').value:'',amt=endig($('#bam')?$('#bam').value:'');
if(!cv){toast('مشتری را انتخاب کنید');return}
if(!/^\\d+$/.test(amt)||+amt<1000){toast('مبلغ معتبر (حداقل ۱۰۰۰ تومان) وارد کنید');return}
busy(b,1);api('POST','invoices',{client_id:+cv,amount:+amt}).then(function(r){busy(b,0);if(r.ok){toast('فاکتور صادر شد');BI.rows=null;biFetch()}else toast(r.j.error||'صدور فاکتور ناموفق بود.')})}

"""

BLOCK_EV = """if(!DEMO&&BI.on&&(a=t.closest('[data-bpd]'))){BI.pd=+a.dataset.bpd;render(0);return}
if(!DEMO&&(a=t.closest('[data-bpay]'))){var bpid=+a.dataset.bpay;modal('ثبت پرداخت','پرداخت این فاکتور ثبت شود؟',function(){api('PATCH','invoices/'+bpid,{status:'paid'}).then(function(r){if(r.ok){toast('پرداخت ثبت شد');BI.rows=null;biFetch()}else toast(r.j.error||'ثبت پرداخت ناموفق بود.')})});return}
if(!DEMO&&(a=t.closest('[data-bropen]'))){var brid=+a.dataset.bropen;modal('بازکردن فاکتور','وضعیت فاکتور به «در انتظار» برگردد؟',function(){api('PATCH','invoices/'+brid,{status:'pending'}).then(function(r){if(r.ok){toast('فاکتور باز شد');BI.rows=null;biFetch()}else toast(r.j.error||'بازکردن ناموفق بود.')})});return}
if(!DEMO&&(a=t.closest('[data-billm]'))){realInvoice(a);return}
"""

s = s.replace(ANCHOR_A, BLOCK_VR + ANCHOR_A, 1)
s = s.replace(ANCHOR_MD, BLOCK_EV + ANCHOR_MD, 1)
io.open(P, 'w', encoding='utf-8').write(s)
print('injected CMD-005 OK; new size =', len(s))
