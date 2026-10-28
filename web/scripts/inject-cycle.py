#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-003 — تزریق صفحات واقعی چرخه پرونده (VR) به web/dynamic/index.html
فایل مرجع dadgar/public/index.html دست‌نخورده می‌ماند. دو نقطه‌ی درج با anchor دقیق."""
import io, sys

P = '/home/z/my-project/dadgar/web/dynamic/index.html'
REF = '/home/z/my-project/dadgar/dadgar/public/index.html'
# همیشه از فایل مرجعِ دست‌نخورده شروع می‌شود تا تزریق idempotent باشد
s = io.open(REF, encoding='utf-8').read()
io.open(P, 'w', encoding='utf-8').write(s)

ANCHOR_A = "/* ---------- shell, router, events ---------- */"
ANCHOR_B = "if(a=t.closest('[data-w]')){"

assert s.count(ANCHOR_A) == 1, 'anchor A count=%d' % s.count(ANCHOR_A)
assert s.count(ANCHOR_B) == 1, 'anchor B count=%d' % s.count(ANCHOR_B)
assert 'CMD-003' not in s, 'already injected'

BLOCK_VR = """/* ---------- CMD-003 فاز ۳ گام ۱ — چرخه پرونده: صفحات واقعی (VR) ---------- */
function jdate(t){try{return new Intl.DateTimeFormat('fa-IR',{year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(t*1000))}catch(e){return '—'}}
function jmoney(n){try{return Number(n||0).toLocaleString('fa-IR')+' تومان'}catch(e){return fa(n)+' تومان'}}
function endig(v){return String(v==null?'':v).replace(/[\\u06F0-\\u06F9\\u0660-\\u0669]/g,function(d){var i='\\u06F0\\u06F1\\u06F2\\u06F3\\u06F4\\u06F5\\u06F6\\u06F7\\u06F8\\u06F9'.indexOf(d);if(i<0)i='\\u0660\\u0661\\u0662\\u0663\\u0664\\u0665\\u0666\\u0667\\u0668\\u0669'.indexOf(d);return i})}
var CL={};
function clin(){for(var k in CL)delete CL[k]}
function stK(s){return {waiting:'w',proposing:'p',assigned:'a',running:'r',done:'d'}[s]||s}
function caseRowR(c,link){return tr(['<a href="#/'+link+'/case/'+c.id+'">'+fa(c.id)+'</a>',esc(c.title),esc(c.category),sc(stK(c.status)),jdate(c.created_at)],'data-t="'+esc(c.title)+' '+c.id+'" data-c="'+esc(c.category)+'" data-s="'+stK(c.status)+'"')}
function pagerR(pg,pages){var h='<div class="pgn">';for(var i=1;i<=pages;i++)h+='<button class="'+(i==pg?'on':'')+'" data-pg="'+i+'">'+fa(i)+'</button>';return h+'</div>'}
function listWait(t){return '<h2 class="dh">'+t+'</h2>'+card('','<p style="opacity:.6">در حال دریافت…</p>')}
var LISTT={c:'پرونده‌های من',a:'مدیریت پرونده‌ها',lm:'پرونده‌های تخصیص‌یافته به من'};
function caseListHTML(d,kind){return '<h2 class="dh">'+LISTT[kind]+'</h2>'+card('','<div class="fl">'+fbar(['در انتظار بررسی','در حال پیشنهاد','تخصیص‌یافته','در حال انجام','بسته‌شده'],kind=='a'?'جستجو…':'جستجوی پرونده…')+'<div style="margin-top:16px">'+tbl(['شماره','عنوان','دسته','وضعیت','تاریخ'],d.rows.map(function(c){return caseRowR(c,kind=='a'?'a':kind=='lm'?'l':'c')}))+'</div></div>')+pagerR(d.page,d.pages)}
function fetchList(kind,pg){var q='?page='+pg+(kind=='lm'?'&scope=mine':kind=='lo'?'&scope=open':'');api('GET','cases'+q).then(function(r){if(r.ok){CL[kind+':'+pg]=r.j;render(0)}else toast(r.j.error||'دریافت فهرست ناموفق بود.')})}
function listV(kind){var key=kind+':'+S.pg;if(CL[key])return caseListHTML(CL[key],kind);fetchList(kind,S.pg);return listWait(LISTT[kind])}
VR.cCases=function(){return listV('c')};
VR.aCases=function(){return listV('a')};
VR.lCases=function(){return listV('lm')};
VR.cNew=V.cNew; /* همان ویزارد چهارمرحله‌ای نمایشی؛ فقط دکمه‌ی تایید نهایی به سرور وصل می‌شود */
VR.lOpen=function(){if(CL['lo:1'])return lOpenHTML(CL['lo:1']);fetchList('lo',1);return '<h2 class="dh">پرونده‌های باز</h2><div class="fl">'+fbar(CATS,'جستجو…')+'<div class="gr" style="margin-top:20px"><p style="opacity:.6">در حال دریافت…</p></div></div>'};
function lOpenHTML(d){return '<h2 class="dh">پرونده‌های باز</h2><div class="fl">'+fbar(CATS,'جستجو…')+'<div class="gr" style="margin-top:20px">'+(d.rows.length?d.rows.map(function(c){return '<div class="card2 fr" data-t="'+esc(c.title)+' '+c.id+'" data-c="'+esc(c.category)+'"><span class="sc s2">'+esc(c.category)+'</span><h3 style="margin-top:10px">'+esc(c.title)+'</h3><p>ثبت '+jdate(c.created_at)+'</p><p>'+esc(c.excerpt||'خلاصه‌ای ثبت نشده است.')+'</p><a class="btn sm" href="#/l/propose/'+c.id+'">ارسال پیشنهاد<span class="ar">←</span></a></div>'}).join(''):'<p style="opacity:.6">فعلاً پرونده‌ی بازی برای پیشنهاد نیست.</p>')+'</div></div>'}
function propSt(s){return s=='pending'?tk('در انتظار',1):s=='accepted'?tk('تایید\u200cشده',6):tk('رد\u200cشده',5)}
VR.lProps=function(){if(CL.pp)return propsHTML(CL.pp);api('GET','proposals').then(function(r){if(r.ok){CL.pp=r.j;render(0)}else toast(r.j.error||'دریافت پیشنهادها ناموفق بود.')});return listWait('پیشنهادهای من')};
function propsHTML(d){return '<h2 class="dh">پیشنهادهای من</h2>'+card('',d.rows.length?tbl(['پرونده','مبلغ','مدت','وضعیت','عملیات'],d.rows.map(function(p){var ops=p.status=='pending'?'<span class="row"><a class="btn sm o" style="color:var(--ink)" href="#/l/propose/'+p.case_id+'">ویرایش</a><button class="btn sm n" data-dp="'+p.id+'">حذف</button></span>':'—';return tr(['<a href="#/l/case/'+p.case_id+'">'+fa(p.case_id)+'</a>',jmoney(p.amount),fa(p.days)+' روز',propSt(p.status),ops])})):'<p style="opacity:.6">هنوز پیشنهادی ثبت نکرده\u200cاید.</p>')}
VR.lProp=function(id){id=+id;if(CL.pr&&CL.pr.id===id)return propHTML(CL.pr);delete CL.pr;api('GET','cases/'+id).then(function(r){if(r.ok){CL.pr=r.j;render(0)}else{toast(r.j.error||'پرونده یافت نشد.');location.hash='#/l/open'}});return listWait('ارسال پیشنهاد')};
function propHTML(c){var m=c.my_proposal;return '<h2 class="dh">ارسال پیشنهاد برای پرونده\u200cی '+fa(c.id)+'</h2><p style="margin-top:-6px">'+esc(c.title)+'</p><p style="opacity:.75">'+esc(c.excerpt||'')+'</p>'+card('','<div class="wb"><div class="fg">'+inp('pa','مبلغ پیشنهادی (تومان)','text','dir="ltr" inputmode="numeric" value="'+(m?m.amount:'')+'"')+inp('pd','مدت زمان تخمینی (روز)','text','dir="ltr" inputmode="numeric" value="'+(m?m.days:'')+'"')+'</div><label class="lb">یادداشت خصوصی<textarea class="inp" id="pnt" rows="4">'+esc(m&&m.note?m.note:'')+'</textarea></label><p style="color:#a35a00">این یادداشت فقط برای شما و مدیر سامانه قابل مشاهده است و مشتری آن را نمی\u200cبیند.</p><div class="row">'+btn(m?'ذخیره تغییرات':'ارسال پیشنهاد','','data-pr="'+c.id+'"')+'</div></div>')}
VR.aCase=function(id){id=+id;if(CL.cd&&CL.cd.id===id)return aCaseHTML(CL.cd);delete CL.cd;api('GET','cases/'+id).then(function(r){if(r.ok){CL.cd=r.j;render(0)}else toast(r.j.error||'پرونده یافت نشد.')});return listWait('پرونده '+fa(id))};
function aCaseHTML(c){var head='<div class="row"><h2 class="dh">پرونده '+fa(c.id)+'</h2>'+sc(stK(c.status))+'</div><p>'+esc(c.title)+'</p>';
var info=card('اطلاعات کامل پرونده و مشتری','<div class="pb"><span>عنوان</span><b>'+esc(c.title)+'</b></div><div class="pb"><span>دسته</span><b>'+esc(c.category)+'</b></div><div class="pb"><span>مشتری</span><b>'+esc(c.client_name||'—')+(c.client_phone?' · <span dir="ltr">'+esc(c.client_phone)+'</span>':'')+'</b></div><div class="pb"><span>ثبت</span><b>'+jdate(c.created_at)+'</b></div><div class="pb"><span>توضیحات</span></div><p>'+esc(c.description||'—')+'</p>');
var fp=card('قیمت نهایی','<div class="wb">'+inp('fpr','مبلغ نهایی (تومان)','text','dir="ltr" inputmode="numeric" value="'+(c.final_price||'')+'"')+btn('ثبت قیمت','','data-fp="'+c.id+'"')+'</div>');
var props=card('پیشنهادهای وکلا',(c.proposals&&c.proposals.length)?'<p style="margin-bottom:10px">یادداشت خصوصی وکلا فقط برای مدیر قابل مشاهده است. با تایید یک پیشنهاد، بقیه خودکار رد می\u200cشوند.</p>'+tbl(['وکیل','مبلغ','مدت','یادداشت خصوصی (فقط ادمین)','وضعیت','عملیات'],c.proposals.map(function(p){var op=p.status=='pending'?'<button class="btn sm" data-ok="'+p.id+'" data-nm="'+esc(p.lawyer_name)+'">تایید</button>':'—';return tr([esc(p.lawyer_name),jmoney(p.amount),fa(p.days)+' روز',esc(p.note||'—'),propSt(p.status),op])})):'<p style="opacity:.6">هنوز پیشنهادی ثبت نشده است.</p>');
return head+'<div class="g2">'+info+fp+'</div>'+props}
function realCaseSubmit(b){busy(b,1);api('POST','cases',{category:S.wd.cat,title:S.wd.t,description:S.wd.d}).then(function(r){busy(b,0);if(r.ok){toast('پرونده\u200cی شما ثبت شد');S.w=1;S.wd={cat:'',t:'',d:'',f:0};clin();location.hash='#/c/cases'}else toast(r.j.error||'ثبت پرونده ناموفق بود.')})}
function realProposalSubmit(b){var cid=+b.dataset.pr,amt=endig($('#pa')?$('#pa').value:''),dy=endig($('#pd')?$('#pd').value:''),nt=$('#pnt')?$('#pnt').value:'';
if(!amt||!dy){toast('مبلغ و مدت زمان را وارد کنید');return}
if(!/^\\d+$/.test(amt)||!/^\\d+$/.test(dy)){toast('مبلغ و مدت باید عدد باشند');return}
var m=CL.pr&&CL.pr.my_proposal;busy(b,1);
api(m?'PATCH':'POST',m?'proposals/'+m.id:'cases/'+cid+'/proposals',{amount:+amt,days:+dy,note:nt}).then(function(r){busy(b,0);if(r.ok){toast(m?'پیشنهاد شما ویرایش شد':'پیشنهاد شما ارسال شد');clin();location.hash='#/l/proposals'}else toast(r.j.error||'ثبت پیشنهاد ناموفق بود.')})}
function realFinalPrice(b){var cid=+b.dataset.fp,v=endig($('#fpr')?$('#fpr').value:'');
if(v===''){toast('مبلغ نهایی را وارد کنید');return}
if(!/^\\d+$/.test(v)){toast('مبلغ باید عدد باشد');return}
busy(b,1);api('PATCH','cases/'+cid,{final_price:+v}).then(function(r){busy(b,0);if(r.ok){toast('قیمت نهایی ثبت شد');if(CL.cd&&CL.cd.id===cid)CL.cd.final_price=+v}else toast(r.j.error||'ثبت ناموفق بود.')})}

"""
BLOCK_EV = """if(!DEMO&&(a=t.closest('button[data-w="s"]'))){realCaseSubmit(a);return}
if(!DEMO&&(a=t.closest('[data-pr]'))){realProposalSubmit(a);return}
if(!DEMO&&(a=t.closest('[data-dp]'))){var dpid=+a.dataset.dp;modal('حذف پیشنهاد','پیشنهاد حذف شود؟',function(){api('DELETE','proposals/'+dpid).then(function(r){if(r.ok){toast('پیشنهاد حذف شد');clin()}else toast(r.j.error||'حذف ناموفق بود.');render(0)})});return}
if(!DEMO&&(a=t.closest('[data-fp]'))){realFinalPrice(a);return}
if(!DEMO&&(a=t.closest('[data-ok]'))){var okid=+a.dataset.ok,oknm=a.dataset.nm||'';modal('تایید پیشنهاد','پیشنهاد '+oknm+' تایید و بقیه\u200cی پیشنهادها رد شوند؟',function(){api('POST','proposals/'+okid+'/accept').then(function(r){if(r.ok){toast('پیشنهاد تایید شد؛ وکیل به پرونده تخصیص یافت.');clin();delete CL.cd}else toast(r.j.error||'تایید ناموفق بود.');render(0)})});return}
"""

s = s.replace(ANCHOR_A, BLOCK_VR + ANCHOR_A, 1)
s = s.replace(ANCHOR_B, BLOCK_EV + ANCHOR_B, 1)
io.open(P, 'w', encoding='utf-8').write(s)
print('injected OK; new size =', len(s))
