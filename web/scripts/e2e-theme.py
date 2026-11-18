"""CMD-055 — آزمون عملی حالت شب/روز روی هارنس محلی (بدون نیاز به دیتابیس).
چرخه: بارگذاری → خواندن تم اولیه (سیستم) → کلیک سوییچ هدر → تغییر رنگ بدنه →
رفرش → پایداری انتخاب (localStorage) → پاک‌سازی → بازگشت به تم سیستم."""
import re
import subprocess
import sys
import time

from playwright.sync_api import sync_playwright

PORT = 3215
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
        initial = pg.evaluate("document.documentElement.dataset.theme")
        check('bootstrap تم اولیه (dark|light)', initial in ('dark', 'light'), initial)
        bg1 = pg.evaluate("getComputedStyle(document.body).backgroundColor")

        btn = pg.locator('button.rd.thm[data-thm]').first
        check('سوییچ هدر عمومی visible', btn.is_visible())
        btn.click()
        pg.wait_for_timeout(150)
        t2 = pg.evaluate("document.documentElement.dataset.theme")
        check('کلیک سوییچ → تم معکوس شد', t2 != initial, f'{initial} → {t2}')
        bg2 = pg.evaluate("getComputedStyle(document.body).backgroundColor")
        check('رنگ بدنه واقعا عوض شد', bg1 != bg2, f'{bg1} → {bg2}')
        ls = pg.evaluate("localStorage.getItem('dadgar-theme')")
        check('انتخاب در localStorage ذخیره شد', ls == t2, ls)
        # پوشش تاریک مؤلفه‌های عمومی در حالت dark
        if t2 == 'dark':
            ph = pg.evaluate("!!document.querySelector('.ph')")
            check('کارتهای وکلا (.ph) روی صفحه حاضرند', ph)
            if ph:
                ph_bg = pg.evaluate("getComputedStyle(document.querySelector('.ph')).backgroundColor")
                check('کارتهای وکلا (.ph) در حالت شب تیره', ph_bg not in ('rgb(255, 255, 255)',), ph_bg)
            fl = pg.evaluate("!!document.querySelector('.faq-lead')")
            check('faq-lead در صفحه اصلی نیست (فقط صفحه SPA /faq است — انتظار غلط آزمون را نگیر)', not fl)
            sk = pg.evaluate("!!document.querySelector('.skip')")
            if sk:
                skb = pg.evaluate("getComputedStyle(document.querySelector('.skip')).backgroundColor")
                check('skip در حالت شب تیره', skb != 'rgb(255, 255, 255)', skb)
        # صفحات SPA (body.pgm) — /faq و /pricing
        pg.evaluate("location.hash='#/faq'")
        pg.wait_for_timeout(400)
        fa = pg.evaluate("!!document.querySelector('.faq-lead')")
        check('صفحه SPA /faq رندر شد و faq-lead دارد', fa)
        if fa and t2 == 'dark':
            fa2 = pg.evaluate("getComputedStyle(document.querySelector('.faq-lead')).backgroundImage")
            check('faq-lead در SPA هم تیره', '18, 27, 70' in fa2, fa2[:80])
        pg.evaluate("location.hash='#/pricing'")
        pg.wait_for_timeout(400)
        pl = pg.evaluate("!!document.querySelector('.plan')")
        check('صفحه SPA /pricing رندر شد و .plan دارد', pl)
        if pl:
            plbg = pg.evaluate("getComputedStyle(document.querySelector('.plan')).backgroundColor")
            check('کارت تعرفه (.plan) در حالت انتخاب‌شده سفید خالص نیست', plbg != 'rgba(255, 255, 255, 0.72)', plbg)
        # رفرش → پایداری
        pg.reload(wait_until='networkidle')
        t3 = pg.evaluate("document.documentElement.dataset.theme")
        check('رفرش → تم پایدار ماند (بدون پرش)', t3 == t2, t3)
        # سوییچ پنل هم همان handler است — بررسی وجود آیکن‌های dual در دکمه هدر
        n_icons = pg.evaluate("document.querySelectorAll('button.rd.thm[data-thm] svg').length")
        check('دو آیکن (خورشید+ماه) در سوییچ هدر', n_icons == 2, n_icons)
        vis = pg.evaluate("""(() => {const b=document.querySelector('button.rd.thm');
            const s=[...b.querySelectorAll('svg')].map(x=>getComputedStyle(x).display);
            return s.join(',')})()""")
        check('فقط یک آیکن همزمان نمایان است', vis.count('block') == 1 or vis.count('grid') == 1 or vis.count('inline') == 1, vis)
        br.close()
finally:
    srv.terminate()

print('=== RESULT:', 'PASS' if not fails else f'FAIL({len(fails)}): {fails}')
sys.exit(0 if not fails else 1)
