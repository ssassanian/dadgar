#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-009 — تزریق صفحه‌ی واقعی لاگ مدیر (VR.aLog) به web/dynamic/index.html
فایل مرجع dadgar/public/index.html دست‌نخورده می‌ماند.
این اسکریپت همیشه از مرجع شروع می‌کند: اول زنجیره‌ی CMD-003..008 و در آخر بلاک CMD-009 —
لذا اجرای مکرر idempotent است. دو نقطه‌ی درج با anchor دقیق:
  A) قبل از «shell, router, events» → ویوی VR.aLog (گزارش و Log واقعی از audit_log)
  B) قبل از هندلر نمایشی [data-md] → اتصال شنونده‌ی change جست‌وجوی لاگ (#lgq)
نکته‌ی معماری: هندلر عمومی [data-pg] (S.pg را عوض می‌کند و render(0) می‌زند) «قبل از» نقطه‌ی
درج B است؛ پس VR.aLog وضعیت صفحه را مستقیم از S.pg می‌خواند (الگوی خود مرجع) — بدون هندلر جدا."""
import io, subprocess, sys

P = '/home/z/my-project/dadgar/web/dynamic/index.html'
REF = '/home/z/my-project/dadgar/dadgar/public/index.html'
CHAIN = ['inject-cycle.py', 'inject-book.py', 'inject-bill.py', 'inject-rev.py', 'inject-msg.py', 'inject-docs.py']

# گام ۰: بازتولید پایه (مرجع + CMD-003..008) تا تزریق همیشه تکرارپذیر باشد
for c in CHAIN:
    subprocess.run([sys.executable, '/home/z/my-project/dadgar/web/scripts/' + c], check=True)
s = io.open(P, encoding='utf-8').read()

ANCHOR_A = "/* ---------- shell, router, events ---------- */"
ANCHOR_MD = "if(a=t.closest('[data-md]')){"
for a in (ANCHOR_A, ANCHOR_MD):
    assert s.count(a) == 1, a[:40] + ' count=%d' % s.count(a)
assert 'CMD-003' in s and 'CMD-008' in s, 'base blocks missing — chain failed'
assert 'CMD-009' not in s, 'already injected'

BLOCK_VR = """/* ---------- CMD-009 فاز ۳ گام ۷ — لاگ مدیر: صفحه‌ی واقعی (VR) ---------- */
var LG={rows:null,pg:0,pages:1,total:0,q:'',on:0,uid:null};
function lgFetch(){var q='?page='+LG.pg+(LG.q?'&q='+encodeURIComponent(LG.q):'');
api('GET','audit'+q).then(function(r){if(r.ok){LG.rows=r.j.rows;LG.pages=r.j.pages;LG.total=r.j.total;render(0)}else toast(r.j.error||'دریافت لاگ ناموفق بود.')})}
function lgNeed(){var pg=S.pg||1;
if(LG.rows&&LG.uid===(U&&U.id)&&LG.pg===pg)return 1;
LG.uid=U&&U.id;LG.pg=pg;LG.rows=null;lgFetch();return 0}
function lgRows(){return (LG.rows||[]).map(function(r){return tr(['<b>'+esc(r.user_name||'سیستم')+'</b>'+(r.user_role?' <small style="opacity:.55">'+({client:'مشتری',lawyer:'وکیل',admin:'مدیر'}[r.user_role]||'')+'</small>':''),'<span dir="ltr" style="font-size:12px">'+esc(String(r.action||''))+'</span>','<span style="opacity:.75">'+esc(r.detail||'—')+'</span>'+(r.ip?'<small dir="ltr" style="opacity:.5;display:block">'+esc(r.ip)+'</small>':''),jdate(r.at)])})}
function lgBind(){var lgq=$('#lgq');if(lgq&&!lgq.dataset.lg){lgq.dataset.lg='1';lgq.addEventListener('change',function(){LG.q=lgq.value.trim();S.pg=1;LG.rows=null;render(0)})}}
VR.aLog=function(){LG.on=1;S.after=lgBind;if(!lgNeed())return listWait('گزارش‌گیری و Log');
var pg=S.pg||1;
return '<div class="row"><h2 class="dh">گزارش‌گیری و Log</h2><span class="row" style="margin-inline-start:auto"><button class="btn sm o" style="color:var(--ink)" data-ts="خروجی اکسل پس از تصمیم مدیر فعال می‌شود.">خروجی اکسل</button><button class="btn sm o" style="color:var(--ink)" data-ts="خروجی PDF پس از تصمیم مدیر فعال می‌شود.">خروجی PDF</button></span></div>'
+card('Audit Log','<div class="row" style="margin-bottom:12px"><input class="inp" id="lgq" placeholder="جستجو در عملیات، جزئیات و نام کاربر…" value="'+esc(LG.q)+'" style="max-width:340px"><small style="opacity:.6">مجموع رکوردها: '+fa(LG.total)+'</small></div>'
+((LG.rows&&LG.rows.length)?tbl(['کاربر','عملیات','جزئیات','زمان'],lgRows()):'<p style="opacity:.6">رکوردی یافت نشد.</p>')
+(LG.pages>1?(function(){var h='<div class="pgn">';for(var i=1;i<=LG.pages;i++)h+='<button class="'+(i==pg?'on':'')+'" data-pg="'+i+'">'+fa(i)+'</button>';return h+'</div>'})():''))};

"""

BLOCK_EV = """if(!DEMO&&LG.on){var lgq=$('#lgq');if(lgq&&!lgq.dataset.lg){lgq.dataset.lg='1';lgq.addEventListener('change',function(){LG.q=lgq.value.trim();S.pg=1;LG.rows=null;render(0)})}}

"""

s = s.replace(ANCHOR_A, BLOCK_VR + ANCHOR_A, 1)
s = s.replace(ANCHOR_MD, BLOCK_EV + ANCHOR_MD, 1)
io.open(P, 'w', encoding='utf-8').write(s)
print('injected CMD-009 OK; new size =', len(s))
