#!/usr/bin/env python3
# CMD-031 P1..P4 — inject real panel pages (cCase/lCase/dashboards/aUsers) + gateway UI into dynamic/index.html
# Idempotent: skips if CMD-031 block already present. Read+write only this file.
import re, sys

F = '/home/z/my-project/dadgar/web/dynamic/index.html'
html = open(F, encoding='utf-8').read()

if '/* ---------- CMD-031' in html:
    print('ALREADY-INJECTED — nothing to do'); sys.exit(0)

# ---------- P4: wire the gateway button inside VR.cBill (exact string, unique) ----------
old_btn = '<button class="btn sm" data-ts="درگاه پرداخت هنوز متصل نشده است؛ پس از تصمیم مدیر فعال می‌شود.">پرداخت آنلاین</button>'
new_btn = '<button class="btn sm" data-pay="\'+r.id+\'">پرداخت آنلاین</button>'
if old_btn not in html:
    print('GATEWAY BUTTON NOT FOUND — aborting (structure changed)'); sys.exit(1)
html = html.replace(old_btn, new_btn, 1)

# ---------- P1..P3: panel pages block ----------
BLOCK = r"""/* ---------- CMD-031 — پنل واقعی: جزئیات پرونده (P1)، داشبوردها (P2)، کاربران (P3)، درگاه UI (P4) ---------- */
var PC={}; /* panel cache — کلیدها: cd<id> جزئیات پرونده، dash نقش‌ها، u کاربران */
function pman(v){return fa(String(Math.round(+v)).replace(/\B(?=(\d{3})+(?!\d))/g,'\u066c'))}
function pwait(t){return '<h2 class="dh">'+t+'</h2>'+card('','<p style="opacity:.6">در حال دریافت…</p>')}
function pfut(ap){var n=(ap&&ap.now)||Math.floor(Date.now()/1000);return (ap&&ap.rows||[]).filter(function(x){return x.starts_at>n&&x.status!=='canceled'})}
function pinv(k){delete PC[k]}
function pline(icn,label,href){return '<div class="pb" style="padding:9px 4px;border-bottom:1px solid #eef1f4"><span class="row" style="gap:8px"><span class="sic">'+ic(icn)+'</span><a href="'+rh(href)+'" style="color:var(--ink)">'+label+'</a></span><span class="ar">←</span></div>'}
function pstk(rows){var c={w:0,p:0,a:0,r:0,d:0};(rows||[]).forEach(function(x){var k=stK(x.status);if(c[k]!==undefined)c[k]++});return c}
function pstatChart(cnt){var L=[['در انتظار',cnt.w],['پیشنهاد',cnt.p],['تخصیص',cnt.a],['در حال انجام',cnt.r],['بسته',cnt.d]];var v=L.map(function(x){return x[1]});return bars(v.length?v:[0,0,0,0,0],L.map(function(x){return x[0]}))}
function pmiss(name){return function(r){toast((r&&r.j&&r.j.error)||('دریافت '+name+' ناموفق بود.'))}}

/* ----- P1: جزئیات پرونده — مشتری و وکیل (مدیر از aCase واقعی خودش استفاده می‌کند) ----- */
function caseDetail(id,role){
  var k='cd'+id;
  if(PC[k])return caseFull(PC[k],role,k);
  api('GET','cases/'+id).then(function(r){if(r.ok){PC[k]=r.j;render(0)}else pmiss('پرونده')(r)}).catch(function(){toast('ارتباط برقرار نشد.')});
  return pwait('پرونده‌ی '+fa(id));
}
function caseFull(c,role,k){
  var head='<div class="row"><h2 class="dh">پرونده‌ی '+fa(c.id)+'</h2>'+sc(stK(c.status))+'<span class="sc s2" style="margin-inline-start:8px">'+esc(c.category)+'</span></div><p style="color:var(--mu)">'+esc(c.title)+'</p>';
  var rs=[['تاریخ ثبت',jdate(c.created_at)],['آخرین به‌روزرسانی',jdate(c.updated_at)]];
  if(c.lawyer_name)rs.push(['وکیل تخصیص‌یافته',esc(c.lawyer_name)]);
  if(role==='a'&&c.client_name)rs.push(['مشتری',esc(c.client_name)+(c.client_phone?' <small style="color:var(--mu)">'+esc(c.client_phone)+'</small>':'')]);
  var info=card('مشخصات پرونده',rs.map(function(x){return '<div class="pb" style="padding:8px 4px;border-bottom:1px solid #eef1f4"><span>'+x[0]+'</span><b>'+x[1]+'</b></div>'}).join('')+(c.final_price?'<div class="pb" style="padding:10px 4px"><span>قیمت نهایی</span><b style="color:var(--b1);font-size:17px">'+pman(c.final_price)+' تومان</b></div>':''));
  var desc=card('شرح پرونده','<p style="white-space:pre-wrap;line-height:2.1">'+esc(c.description||c.excerpt||'—')+'</p>');
  var extra='';
  if(role==='a'&&c.proposals){
    extra=card('پیشنهادهای وکلا',(c.proposals.length?tbl(['وکیل','مبلغ (تومان)','مدت','وضعیت','عملیات'],c.proposals.map(function(p){return tr([esc(p.lawyer_name||'—'),pman(p.amount),fa(p.days)+' روز',propSt(p.status),p.status=='pending'?'<button class="btn sm n" data-pac="'+p.id+'" data-cid="'+c.id+'">تایید پیشنهاد</button>':'<small style="color:var(--mu)">—</small>'])})):'<p style="opacity:.6">پیشنهادی ثبت نشده است.</p>'))+'<div style="margin-top:12px">'+card('قیمت نهایی (تومان)','<div class="wb">'+inp('fpr','مبلغ نهایی','text','dir="ltr" inputmode="numeric" value="'+(c.final_price||'')+'"')+btn('ثبت قیمت','','data-fp="'+c.id+'"')+'</div>');
  }
  if(role==='l'){
    var mp=c.my_proposal;
    var own=card('پیشنهاد من',(mp?'<div class="pb"><span>وضعیت</span><b>'+propSt(mp.status)+'</b></div><div class="pb"><span>مبلغ</span><b>'+pman(mp.amount)+' تومان</b></div><div class="pb"><span>مدت</span><b>'+fa(mp.days)+' روز</b></div>'+(mp.note?'<div class="pb"><span>یادداشت</span><b>'+esc(mp.note)+'</b></div>':''):'<p style="opacity:.6">هنوز پیشنهادی ثبت نکرده‌اید.</p>')+((c.status=='waiting'||c.status=='proposing')?'<div style="margin-top:10px">'+btn(mp?'ویرایش پیشنهاد':'ثبت پیشنهاد','','data-go="/l/propose/'+c.id+'"')+'</div>':''));
    var acts=card('اقدامات',[['chat','گفتگوی پرونده','/l/chat'],['clip','اسناد پرونده','/l/cases'],['ticket','تیکت‌ها','/l/tickets']].map(function(x){return pline(x[0],x[1],x[2])}).join(''));
    extra='<div class="g2">'+own+acts+'</div>';
  }
  if(role==='c'){
    var acts=[['chat','گفتگو با وکیل','/c/chat'],['ticket','تیکت پشتیبانی','/c/ticket/new'],['clip','اسناد من','/c/documents']];
    if(c.status=='done')acts.push(['file','ثبت نظر درباره‌ی همکاری','/c/review']);
    extra=card('اقدامات',[['folder','پرونده‌های من','/c/cases']].concat(acts).map(function(x){return pline(x[0],x[1],x[2])}).join(''));
  }
  return head+'<div class="g2">'+info+desc+'</div>'+extra;
}
VR.cCase=function(i){return caseDetail(i,'c')};
VR.lCase=function(i){return caseDetail(i,'l')};

/* ----- P2: داشبوردها با داده‌ی واقعی ----- */
function statRow(list){return '<div class="gr" style="--m:220px">'+list.map(function(x){return stat(x[0],x[1],x[2],x[3]||'')}).join('')+'</div>'}
function recentCases(cs,base){return card('آخرین پرونده‌ها',(cs.rows&&cs.rows.length?tbl(['شماره','عنوان','وضعیت','تاریخ'],cs.rows.slice(0,4).map(function(c){return tr(['<a href="'+rh(base+'/case/'+c.id)+'">'+fa(c.id)+'</a>',esc(c.title),sc(stK(c.status)),jdate(c.created_at)])})):'<p style="opacity:.6">پرونده‌ای ثبت نشده است.</p>'))}
function nextAppt(ap){var f=pfut(ap)[0];return card('نوبت بعدی',(f?'<div class="row"><b>'+jdate(f.starts_at)+' — '+esc(f.slot||'')+'</b>'+(f.kind?'<small style="color:var(--mu)">'+esc(f.kind)+'</small>':'')+'<a class="btn sm o" style="color:var(--ink);margin-inline-start:auto" href="'+rh('/c/book')+'">مدیریت نوبت‌ها<span class="ar">←</span></a></div>':'<p style="opacity:.6">نوبت فعالی ندارید. <a href="'+rh('/c/book')+'" style="color:var(--b1)">رزرو نوبت</a></p>'))}
function activityFeed(iv,tkv){var it=(iv.rows||[]).slice(0,2).map(function(x){return [jdate(x.created_at),'فاکتور '+fa(x.id)+' — '+pman(x.amount)+' تومان',x.status=='paid'?tk('پرداخت‌شده',6):tk('در انتظار',1)]}).concat((tkv.rows||[]).slice(0,2).map(function(x){return [jdate(x.created_at||x.created_at),'تیکت '+fa(x.id)+(x.subject?' — '+esc(x.subject):''),tk(TKST[x.status]?TKST[x.status][0]:x.status,TKST[x.status]?TKST[x.status][1]:1)]}));return card('فعالیت اخیر',(it.length?'<div class="pb">'+it.map(function(x){return '<div class="pb" style="padding:8px 4px;border-bottom:1px solid #eef1f4"><span>'+x[1]+'</span><span class="row" style="gap:8px">'+x[2]+'<small style="color:var(--mu)">'+x[0]+'</small></span></div>'}).join('')+'</div>':'<p style="opacity:.6">فعالیتی ثبت نشده است.</p>'))}
function panelGet(keys,cb){var n=keys.length,d=0,o={};keys.forEach(function(x){api('GET',x[0]).then(function(r){o[x[1]]=r;next()}).catch(function(){o[x[1]]=null;next()})});function next(){if(++d===n)cb(o)}}
function dashWaitLoad(keys,ck){panelGet(keys,function(o){PC[ck]={o:o,t:Date.now()};render(0)});return pwait('داشبورد')}
function dashFresh(ck){return PC[ck]&&Date.now()-PC[ck].t<20000}
function jget(o,k){return (o&&o[k]&&o[k].ok&&o[k].j)||null}

VR.cDash=function(){
  if(dashFresh('dc'))return cDashHTML(PC['dc'].o);
  return dashWaitLoad([['cases?page=1','cs'],['appointments','ap'],['invoices','iv'],['tickets','tk']],'dc');
};
function cDashHTML(o){
  var cs=jget(o,'cs'),ap=jget(o,'ap'),iv=jget(o,'iv'),tkv=jget(o,'tk');
  if(!cs)return pwait('داشبورد');
  var cnt=pstk(cs.rows);
  return '<h2 class="dh">داشبورد</h2>'
   +statRow([['پرونده‌های من',fa(cs.total),'folder'],['فاکتور در انتظار',fa((iv.rows||[]).filter(function(x){return x.status=='pending'}).length),'card'],['نوبت‌های آینده',fa(pfut(ap).length),'cal'],['تیکت باز',fa((tkv.rows||[]).filter(function(x){return x.status=='open'}).length),'chat']])
   +'<div class="g2">'+nextAppt(ap)+activityFeed(iv,tkv)+'</div>'
   +recentCases(cs,'/c');
}
VR.lDash=function(){
  if(dashFresh('dl'))return lDashHTML(PC['dl'].o);
  return dashWaitLoad([['cases?page=1&scope=mine','cm'],['cases?page=1&scope=open','co'],['proposals','pr'],['appointments','ap'],['tickets','tk']],'dl');
};
function lDashHTML(o){
  var cm=jget(o,'cm'),co=jget(o,'co'),pr=jget(o,'pr'),ap=jget(o,'ap'),tkv=jget(o,'tk');
  if(!cm)return pwait('داشبورد');
  var prp=(pr.rows||[]);
  return '<h2 class="dh">داشبورد وکیل</h2>'
   +statRow([['پرونده‌های من',fa(cm.total),'folder'],['پرونده‌های باز',fa(co.total?co.total:(co.rows||[]).length),'file'],['پیشنهادهای من',fa(prp.length),'chart'],['نوبت‌های آینده',fa(pfut(ap).length),'cal']])
   +'<div class="g2">'
   +card('پرونده‌های باز — آماده‌ی پیشنهاد',(co.rows&&co.rows.length?tbl(['شماره','عنوان','دسته','اقدام'],co.rows.slice(0,4).map(function(c){return tr(['<a href="'+rh('/l/case/'+c.id)+'">'+fa(c.id)+'</a>',esc(c.title),esc(c.category),'<button class="btn sm" data-go="/l/propose/'+c.id+'">پیشنهاد<span class="ar">←</span></button>'])})):'<p style="opacity:.6">پرونده‌ی بازی موجود نیست.</p>'))
   +card('آخرین پیشنهادهای من',(prp.length?tbl(['پرونده','مبلغ (تومان)','وضعیت','تاریخ'],prp.slice(0,4).map(function(p){return tr(['<a href="'+rh('/l/case/'+p.case_id)+'">'+fa(p.case_id)+'</a>',pman(p.amount),propSt(p.status),jdate(p.created_at)])})):'<p style="opacity:.6">پیشنهادی ثبت نکرده‌اید.</p>'))
   +'</div>'
   +'<div class="g2">'+card('وضعیت پرونده‌های من',pstatChart(pstk(cm.rows)))+recentCases(cm,'/l')+'</div>';
}
VR.aDash=function(){
  if(dashFresh('da'))return aDashHTML(PC['da'].o);
  return dashWaitLoad([['cases?page=1','cs'],['users?role=client','uc'],['users?role=lawyer','ul'],['invoices','iv'],['appointments','ap']],'da');
};
function aDashHTML(o){
  var cs=jget(o,'cs'),uc=jget(o,'uc'),ul=jget(o,'ul'),iv=jget(o,'iv'),ap=jget(o,'ap');
  if(!cs)return pwait('داشبورد');
  var ucN=uc?(uc.total||uc.rows.length):0,ucL=uc&&uc.cap&&uc.total>=uc.cap;
  var pendingIv=(iv.rows||[]).filter(function(x){return x.status=='pending'});
  var sumP=(iv.rows||[]).filter(function(x){return x.status=='paid'}).reduce(function(a,x){return a+(+x.amount||0)},0);
  return '<h2 class="dh">داشبورد مدیریتی</h2>'
   +statRow([['کل پرونده‌ها',fa(cs.total),'folder'],['مشتریان',fa(ucN)+(ucL?'+':''),'user'],['وکلای همکار',fa(ul?(ul.total||ul.rows.length):0),'users'],['درآمد پرداخت‌شده (آخرین '+fa((iv.rows||[]).length)+' فاکتور)',pman(sumP)+' ت','card']])
   +'<div class="g2">'
   +card('فاکتورهای در انتظار پرداخت',(pendingIv.length?tbl(['فاکتور','مشتری','مبلغ (تومان)','تاریخ'],pendingIv.slice(0,4).map(function(x){return tr(['<b>'+fa(x.id)+'</b>',esc(x.client_name||'—'),pman(x.amount),jdate(x.created_at)])}))+'<div style="margin-top:10px">'+btn('مدیریت مالی','','data-go="/a/finance"')+'</div>':'<p style="opacity:.6">فاکتور در انتظاری وجود ندارد. '+btn('صدور فاکتور','','data-go="/a/finance"')+'</p>'))
   +card('نوبت‌های پیش‌رو',(pfut(ap).length?tbl(['روز','ساعت','مشتری','وکیل'],pfut(ap).slice(0,4).map(function(x){return tr([jdate(x.starts_at),esc(x.slot||'—'),esc(x.client_name||'—'),esc(x.lawyer_name||'—')])}))+'<div style="margin-top:10px">'+btn('مدیریت نوبت‌ها','','data-go="/a/appointments"')+'</div>':'<p style="opacity:.6">نوبت فعالی وجود ندارد.</p>'))
   +'</div>'
   +'<div class="g2">'+card('توزیع وضعیت پرونده‌ها',pstatChart(pstk(cs.rows)))+recentCases(cs,'/a')+'</div>';
}

/* ----- P3: مدیریت کاربران (admin) ----- */
function uSt(s){return s=='active'?tk('فعال',6):s=='pending'?tk('در انتظار تایید',1):tk('مسدود',5)}
function userRow(u,role){
  var op=u.id===U.id?'<small style="color:var(--mu)">حساب شما</small>'
   :u.status=='pending'?'<button class="btn sm" data-ub="'+u.id+':active:1">تایید حساب</button>'
   :'<button class="btn sm '+(u.status=='blocked'?'o" style="color:var(--ink)':'n')+'" data-ub="'+u.id+':'+(u.status=='blocked'?'active':'blocked')+':0">'+(u.status=='blocked'?'آزادسازی':'مسدودسازی')+'</button>';
  return tr([esc(u.name),'<span dir="ltr">۰•••••'+fa(u.phone_last4||'')+'</span>',uSt(u.status),jdate(u.created_at),op],' data-nm="'+esc(u.name)+'"');
}
function usersHTML(){
  var d=PC.u;
  function tb(rows){return tbl(['نام','تلفن','وضعیت','عضویت','عملیات'],rows.map(function(u){return userRow(u)}))}
  var q='<label class="lb" style="max-width:280px">جستجوی نام<input class="inp" data-fu placeholder="بخشی از نام…"></label>';
  return '<h2 class="dh">مدیریت کاربران</h2>'
   +q+card('',tabs('usr',[
     ['مشتریان ('+fa((d.client.rows||[]).length)+')',tb(d.client.rows)],
     ['وکلا ('+fa((d.lawyer.rows||[]).length)+')',tb(d.lawyer.rows)],
     ['افزودن وکیل','<div class="wb"><p>ثبت‌نام وکیل با شماره‌ی موبایل انجام می‌شود: وکیل از صفحه‌ی ورود ثبت‌نام می‌کند و حساب او با وضعیت «در انتظار تایید» ساخته می‌شود؛ سپس همین‌جا با دکمه‌ی «تایید حساب» فعال می‌شود.</p><p style="color:var(--mu)">این فرآیند بدون فرم دستی، امنیت حساب‌ها را نگه می‌دارد.</p></div>']
   ]));
}
VR.aUsers=function(){
  if(PC.u)return usersHTML();
  panelGet([['users?role=client','client'],['users?role=lawyer','lawyer']],function(o){
    if(o.client&&o.client.ok&&o.lawyer&&o.lawyer.ok){PC.u={client:o.client.j,lawyer:o.lawyer.j};render(0)}
    else{PC.u={client:(o.client&&o.client.j)||{rows:[]},lawyer:(o.lawyer&&o.lawyer.j)||{rows:[]}};render(0)}
  });
  return pwait('مدیریت کاربران');
};

/* ----- هندلرهای اکشن (delegation مستقل — بدون دست‌زدن به هندلرهای موجود) ----- */
(function(){
  if(window.__d31)return;window.__d31=1;
  document.addEventListener('click',function(e){
    var a;
    /* P4 — درگاه پرداخت واقعی از UI وب */
    if(a=e.target.closest('[data-pay]')){
      e.preventDefault();var b=a;busy(b,1);
      api('POST','payments/request',{invoice_id:a.dataset.pay}).then(function(r){
        busy(b,0);
        if(r.ok&&r.j&&r.j.pay_url){toast('در حال انتقال به درگاه پرداخت…');window.location.href=r.j.pay_url}
        else toast((r.j&&r.j.error)||'ساخت درخواست پرداخت ناموفق بود.');
      }).catch(function(){busy(b,0);toast('ارتباط با سرور برقرار نشد.')});
      return;
    }
    /* P3 — مسدود/آزادسازی دو-کلیکی + تایید حساب وکیل */
    if(a=e.target.closest('[data-ub]')){
      e.preventDefault();
      if(!a.dataset.arm){a.dataset.arm='1';a.dataset.txt=a.textContent;a.textContent='تایید؟';return}
      var p=a.dataset.ub.split(':'),id=p[0],st=p[1],ap=p[2]==='1';busy(a,1);
      api('PATCH','users/'+id,{status:st}).then(function(r){
        busy(a,0);
        if(r.ok){toast(ap?'حساب وکیل تایید شد':(st=='blocked'?'کاربر مسدود شد':'کاربر آزاد شد'));pinv('u');delete PC.u;render(0)}
        else{a.textContent=a.dataset.txt;delete a.dataset.arm;toast((r.j&&r.j.error)||'انجام نشد.')}
      }).catch(function(){busy(a,0);toast('ارتباط برقرار نشد.')});
      return;
    }
    /* P1(admin) — تایید پیشنهاد از صفحه‌ی جزئیات */
    if(a=e.target.closest('[data-pac]')){
      e.preventDefault();var b=a;busy(b,1);
      api('POST','proposals/'+a.dataset.pac+'/accept',{}).then(function(r){
        busy(b,0);
        if(r.ok){toast('پیشنهاد تایید شد؛ پرونده تخصیص یافت.');pinv('cd'+a.dataset.cid);render(0)}
        else toast((r.j&&r.j.error)||'تایید ناموفق بود.');
      }).catch(function(){busy(b,0);toast('ارتباط برقرار نشد.')});
      return;
    }
  });
  document.addEventListener('input',function(e){
    if(e.target.closest&&e.target.dataset&&e.target.dataset.fu!==undefined){
      var q=e.target.value.trim(),box=e.target.closest('.card2,div');
      if(box){$$('tr[data-nm]',box).forEach(function(r){r.style.display=(!q||r.dataset.nm.indexOf(q)>=0)?'':'none'})}
    }
  });
})();
"""
# inject the block at TOP-LEVEL (same IIFE scope as api/card/VR) — NOT inside render()!
# (anchor is a top-level function definition; injecting before render-body broke caching)
ANCHOR = "function applyF(box){"
if ANCHOR not in html:
    print('ANCHOR NOT FOUND — aborting'); sys.exit(1)
html = html.replace(ANCHOR, BLOCK + '\n' + ANCHOR, 1)

open(F, 'w', encoding='utf-8').write(html)
print('INJECTED OK — panel block + gateway button wired')
