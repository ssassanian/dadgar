"""CMD-056 — آزمون عملی تم سه‌حالته (سورمه‌ای برند/شب/روز) + نوار مشتریان روی هارنس محلی (بدون دیتابیس).
چرخه: بارگذاری → تم اولیه سورمه‌ای (برند) → کلیک سوییچ هدر → چرخش کامل سه حالت →
تغییر واقعی رنگ بدنه در هر حالت → ذخیره localStorage → پایداری رفرش →
پوشش تاریک مؤلفه‌ها → نوار مشتریان (clv/clb) حاضر و مارکی فعال → SPA → پاک‌سازی.
"""
import re
import subprocess
import sys
import time

from playwright.sync_api import sync_playwright

PORT = 3216
srv = subprocess.Popen(
    ['node', 'scripts/dev-server.js'],
    env={'PATH': '/usr/local/bin:/usr/bin:/bin', 'PORT': str(PORT),
         'NODE_ENV': 'development', 'APP_SECRET': 'x' * 60},
    cwd='/home/z/my-project/dadgar/web',
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(2)
B = f'http://127.0.0.1:{PORT}'
fails = []


def check(name, cond, extra=''):
    print(('ok | ' if cond else 'FAIL | ') + name + (' — ' + str(extra) if extra else ''))
    if not cond:
        fails.append(name)


try:
    with sync_playwright() as p:
        br = p.chromium.launch()
        pg = br.new_page()
        pg.goto(B + '/', wait_until='networkidle')
        # CMD-056: تم پیش‌فرض = سورمه‌ای برند (بدون انتخاب ذخیره‌شده)
        initial = pg.evaluate("document.documentElement.dataset.theme")
        check('تم اولیه (بدون انتخاب کاربر) = سورمه‌ای برند', initial == 'navy', initial)
        bg1 = pg.evaluate("getComputedStyle(document.body).backgroundColor")
        check('بدنه در سورمه‌ای واقعا تیره است', bg1 not in ('rgb(242, 246, 255)', 'rgb(255, 255, 255)'), bg1)

        btn = pg.locator('button.rd.thm[data-thm]').first
        check('سوییچ هدر عمومی visible', btn.is_visible())
        # چرخه کامل: navy → dark → light → navy
        seq = []
        for i in range(3):
            btn.click()
            pg.wait_for_timeout(120)
            seq.append(pg.evaluate("document.documentElement.dataset.theme"))
        check('چرخه کامل سوییچ (navy→dark→light)', seq == ['dark', 'light', 'navy'], seq)
        ls = pg.evaluate("localStorage.getItem('dadgar-theme')")
        check('انتخاب آخر در localStorage ذخیره شد', ls == 'navy', ls)

        # حالت dark: پوشش تاریک مؤلفه‌ها
        btn.click()
        pg.wait_for_timeout(120)
        t2 = pg.evaluate("document.documentElement.dataset.theme")
        check('بازگشت به dark', t2 == 'dark', t2)
        ph = pg.evaluate("!!document.querySelector('.ph')")
        check('کارتهای راهبران (.ph) روی صفحه حاضرند', ph)
        if ph:
            ph_bg = pg.evaluate("getComputedStyle(document.querySelector('.ph')).backgroundColor")
            check('کارتهای راهبران (.ph) در حالت شب تیره', ph_bg not in ('rgb(255, 255, 255)',), ph_bg)
        clb_bg = pg.evaluate("getComputedStyle(document.querySelector('.clb')).backgroundColor")
        check('کارت لوگوی مشتریان (.clb) در حالت شب تیره', clb_bg not in ('rgb(255, 255, 255)',), clb_bg)

        # CMD-056: نوار مشتریان — ۱۸ تصویر (۹ لوگو ×۲ کپی) + fallback نام‌ها
        n_clb = pg.evaluate("document.querySelectorAll('.clb').length")
        check('۱۸ کارت لوگو در نوار مشتریان (۹ × ۲ کپی)', n_clb == 18, n_clb)
        n_clt = pg.evaluate("document.querySelectorAll('.clb .clt').length")
        check('fallback نام شرکت‌ها حاضر است', n_clt == 18, n_clt)
        anim = pg.evaluate("getComputedStyle(document.querySelector('.cltr')).animationName")
        check('انیمیشن مارکی فعال است', anim == 'clm', anim)

        # راهبران واقعی
        leaders = pg.evaluate("""[...document.querySelectorAll('#about figcaption b')].map(x=>x.textContent)""")
        check('پنج راهبر واقعی روی صفحه', 'دکتر حسین لطفی' in leaders and 'علیرضا تلخابی' in leaders and len(leaders) == 5, leaders)

        # رفرش → پایداری تم dark
        pg.reload(wait_until='networkidle')
        t3 = pg.evaluate("document.documentElement.dataset.theme")
        check('رفرش → تم پایدار ماند (بدون پرش)', t3 == 'dark', t3)

        # سه آیکن (خورشید+ماه+قطره سورمه‌ای) در سوییچ هدر — فقط یکی نمایان
        n_icons = pg.evaluate("document.querySelectorAll('button.rd.thm[data-thm] svg').length")
        check('سه آیکن (خورشید+ماه+قطره) در سوییچ هدر', n_icons == 3, n_icons)
        vis = pg.evaluate("""(() => {const b=document.querySelector('button.rd.thm');
            const s=[...b.querySelectorAll('svg')].map(x=>getComputedStyle(x).display);
            return s.join(',')})()""")
        check('فقط یک آیکن همزمان نمایان است', vis.count('block') == 1 or vis.count('grid') == 1 or vis.count('inline') == 1, vis)

        # حالت سورمه‌ای: هدر و هیرو برند واقعا سورمه‌ای
        pg.evaluate("localStorage.setItem('dadgar-theme','navy')")
        pg.reload(wait_until='networkidle')
        topbg = pg.evaluate("getComputedStyle(document.querySelector('.top')).backgroundImage || getComputedStyle(document.querySelector('.top')).backgroundColor")
        herobg = pg.evaluate("getComputedStyle(document.querySelector('.hero')).backgroundImage")
        check('هیرو در سورمه‌ای از پالت برند است', 'rgba(82, 126, 255' in herobg or 'rgb(10, 20, 36)' in herobg, herobg[:120])
        tsk = pg.evaluate("getComputedStyle(document.querySelector('.top .tsn')).display")
        check('آیکن قطره در حالت سورمه‌ای نمایان است', tsk == 'block' or tsk == 'grid', tsk)

        # صفحات SPA (body.pgm) — /faq
        pg.evaluate("location.hash='#/faq'")
        pg.wait_for_timeout(400)
        fa = pg.evaluate("!!document.querySelector('.faq-lead')")
        check('صفحه SPA /faq رندر شد و faq-lead دارد', fa)
        if fa:
            fa2 = pg.evaluate("getComputedStyle(document.querySelector('.faq-lead')).backgroundImage")
            check('faq-lead در SPA با تم سورمه‌ای تیره', '18, 27, 70' in fa2, fa2[:80])
        br.close()
finally:
    srv.terminate()

print('=== RESULT:', 'PASS' if not fails else f'FAIL({len(fails)}): {fails}')
sys.exit(0 if not fails else 1)
