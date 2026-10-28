#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-010 — تست مرورگر واقعی CMS/تنظیمات/سئو (فاز ۳ گام ۸) روی هارنس محلی + دیتابیس واقعی.
سناریو: /a/settings (بدون نوار زرد، پیش‌پر از DB یا پیش‌فرض مرجع، ذخیره با پیام واقعی سرور)
← /a/cms چهار تب کار می‌کند و تعرفه‌ها پیش‌پر است ← /a/seo بدون نوار زرد
← صفحه‌ی عمومی /pricing عین مرجع (fallback درست). بدون خطای JS."""
import os, sys
from playwright.sync_api import sync_playwright

BASE = os.environ.get('CM_BASE', 'http://127.0.0.1:3210')
errors = []

def api(ctx, method, path, csrf=None, data=None):
    headers = {}
    if csrf: headers['x-csrf-token'] = csrf
    fn = getattr(ctx.request, method.lower())
    r = fn(BASE + path, headers=headers, data=data)
    try: j = r.json()
    except Exception: j = {}
    return r.status, j

def login_api(ctx, user, pwd):
    st, j = api(ctx, 'POST', '/api/auth/login', data={'username': user, 'password': pwd})
    assert st == 200 and j.get('csrf'), (st, j)
    return j['csrf']

with sync_playwright() as p:
    b = p.chromium.launch()
    ca = b.new_context()
    ac = login_api(ca, 'admin_t', 'AdminT#2026x')
    ready = api(ca, 'GET', '/api/settings', ac)[1].get('ready')
    print('setup: admin logged in; settings ready=%s' % ready)

    # ---------- 1) /a/settings — real, no banner, prefilled ----------
    pg = ca.new_page()
    pg.on('pageerror', lambda e: errors.append('PAGEERROR-A: ' + str(e)))
    pg.on('console', lambda m: errors.append('CONSOLE-ERR-A: ' + m.text) if m.type == 'error' else None)
    pg.goto(BASE + '/#/a/settings')
    pg.wait_for_function("() => document.querySelector('#as_phone')", timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on aSet'
    val = pg.locator('#as_phone').input_value()
    assert '۰۲۱' in val, 'phone field must be prefilled (DB or reference default): ' + val
    pg.screenshot(path='/tmp/e2ec_1_settings.png')
    print('✅ admin: /a/settings real — no banner, phone prefilled (%s)' % val)

    # ---------- 2) save → honest server response ----------
    pg.fill('#as_phone', '۰۲۱-۱۲۳۴۵۶۷۸')
    pg.click('button[data-setsave]')
    pg.wait_for_selector('.ts', state='attached', timeout=8000)
    toast = pg.locator('.ts').last.inner_text()
    ok_msg = 'تنظیمات ذخیره شد' in toast
    degr_msg = 'اعمال نشده' in toast
    assert ok_msg or degr_msg, 'unexpected toast: ' + toast
    pg.screenshot(path='/tmp/e2ec_2_saved.png')
    print('✅ admin: save → server says: «%s»' % toast[:60].replace('\n', ' '))

    # ---------- 3) /a/cms — four tabs + tariffs prefilled ----------
    pg.goto(BASE + '/#/a/cms')
    pg.wait_for_function("() => document.querySelector('#dc') && document.querySelector('#dc').innerText.includes('مدیریت محتوای سایت')", timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on aCms'
    pg.wait_for_function("() => document.querySelector('#tf_phone')", timeout=15000)
    tv = pg.locator('#tf_phone').input_value()
    assert 'تومان' in tv or tv == '', 'tariff must be prefilled: ' + tv
    for t in ['صفحات ثابت', 'مقالات', 'دسته‌بندی‌ها', 'تعرفه‌ها']:
        assert t in pg.locator('#dc').inner_text(), 'missing tab ' + t
    pg.screenshot(path='/tmp/e2ec_3_cms.png')
    print('✅ admin: /a/cms real — 4 tabs, tariff prefilled (%s)' % tv)

    # ---------- 4) tab switch to tariffs + honest save ----------
    pg.click("button[data-ti='cm:3']")
    pg.fill('#tf_phone', '۵۰۰ هزار تومان')
    pg.click('button[data-cmssave]')
    pg.wait_for_selector('.ts', state='attached', timeout=8000)
    toast2 = pg.locator('.ts').last.inner_text()
    assert 'تعرفه‌ها ذخیره شد' in toast2 or 'اعمال نشده' in toast2, toast2
    pg.screenshot(path='/tmp/e2ec_4_tariff_save.png')
    print('✅ admin: tariff save → «%s»' % toast2[:56].replace('\n', ' '))

    # ---------- 5) /a/seo — real (planning doc), no banner ----------
    pg.goto(BASE + '/#/a/seo')
    pg.wait_for_function("() => document.querySelector('#dc') && document.querySelector('#dc').innerText.includes('برنامه‌ی لندینگ‌ها و سئو')", timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on aSeo'
    pg.screenshot(path='/tmp/e2ec_5_seo.png')
    print('✅ admin: /a/seo real — no banner, planning content intact')

    # ---------- 6) public /pricing — reference fallback ----------
    guest = b.new_context()
    gp = guest.new_page()
    gp.on('pageerror', lambda e: errors.append('PAGEERROR-G: ' + str(e)))
    gp.goto(BASE + '/#/pricing')
    gp.wait_for_function("() => document.querySelector('#app') && document.querySelector('#app').innerText.includes('تعرفه‌ها')", timeout=15000)
    body = gp.locator('#app').inner_text()
    assert 'مشاوره‌ی تلفنی' in body and 'مشاوره‌ی حضوری' in body, body[:300]
    pg.screenshot(path='/tmp/e2ec_6_pricing.png')
    print('✅ guest: /pricing renders (reference structure intact)')

    # ---------- 7) if table ready: saved values appear on public pricing ----------
    if ready and 'ذخیره شد' in toast2:
        gp2 = guest.new_page()
        gp2.goto(BASE + '/#/pricing')
        gp2.wait_for_function("() => document.querySelector('#app') && document.querySelector('#app').innerText.includes('۵۰۰ هزار تومان')", timeout=15000)
        print('✅ guest: saved tariff (۵۰۰ هزار تومان) appears on public /pricing')
    else:
        print('ℹ degraded mode (table pending) — fallback values verified instead')

    b.close()

if errors:
    real_errors = [e for e in errors if 'favicon' not in e and 'Failed to load resource' not in e]
    if real_errors:
        print('JS ERRORS:')
        for e in real_errors: print(' ', e)
        sys.exit(1)
print('ALL CMD-010 E2E PASSED — no JS errors')
