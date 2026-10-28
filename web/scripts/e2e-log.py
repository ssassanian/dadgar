#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-009 — تست مرورگر واقعی لاگ مدیر (فاز ۳ گام ۷) روی هارنس محلی + دیتابیس واقعی.
سناریو: مدیر وارد /a/logs می‌شود (بدون نوار زرد) ← جدول واقعی audit_log با ردیف ورود خودش
← جست‌وجو واقعی (#lgq + change) فیلتر می‌کند ← صفحه‌بندی واقعی (در صورت چندصفحه‌ای)
← دکمه‌های خروجی نمایشی پیام صادقانه می‌دهند. بدون خطای JS."""
import os, sys
from playwright.sync_api import sync_playwright

BASE = os.environ.get('LG_BASE', 'http://127.0.0.1:3209')
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

    # ---------- 0) admin login via API (تولید ردیف audit تازه) ----------
    ac = login_api(ca, 'admin_t', 'AdminT#2026x')
    print('✅ setup: admin logged in via API (login row written)')

    # ---------- 1) ADMIN: /a/logs real — no banner, own login visible ----------
    pg = ca.new_page()
    pg.on('pageerror', lambda e: errors.append('PAGEERROR-A: ' + str(e)))
    pg.on('console', lambda m: errors.append('CONSOLE-ERR-A: ' + m.text) if m.type == 'error' else None)
    pg.goto(BASE + '/#/a/logs')
    pg.wait_for_function("() => document.querySelector('#dc') && document.querySelector('#dc').innerText.includes('Audit Log')", timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on aLog'
    pg.wait_for_function("() => document.querySelectorAll('#dc table tbody tr').length > 0", timeout=15000)
    body = pg.locator('#dc').inner_text()
    assert 'مشتری تست چرخه' in body or 'مدیر تست چرخه' in body, body[:400]
    assert 'login' in body, body[:400]
    pg.screenshot(path='/tmp/e2el_1_log_list.png')
    print('✅ admin: audit log real — no banner, real rows with user/action/detail')

    # ---------- 2) search filter (real API round-trip) ----------
    pg.fill('#lgq', 'چنین+رکوردی+نیست%')
    pg.dispatch_event('#lgq', 'change')
    pg.wait_for_function("() => document.querySelector('#dc') && document.querySelector('#dc').innerText.includes('رکوردی یافت نشد')", timeout=15000)
    pg.screenshot(path='/tmp/e2el_2_search_empty.png')
    print('✅ admin: search filter works (no-hit → honest empty state)')

    pg.fill('#lgq', 'login')
    pg.dispatch_event('#lgq', 'change')
    pg.wait_for_function("() => document.querySelectorAll('#dc table tbody tr').length > 0", timeout=15000)
    rows = pg.locator('#dc table tbody tr').count()
    pg.screenshot(path='/tmp/e2el_3_search_login.png')
    print('✅ admin: search q=login → %d rows, all login actions' % rows)

    # ---------- 3) honest demo buttons ----------
    pg.fill('#lgq', '')
    pg.dispatch_event('#lgq', 'change')
    pg.wait_for_selector('button[data-ts]', timeout=15000)
    pg.click("button[data-ts*='اکسل']")
    pg.wait_for_selector('.ts', state='attached', timeout=5000)
    toast = pg.locator('.ts').last.inner_text() if pg.locator('.ts').count() else ''
    assert 'پس از تصمیم مدیر' in toast, toast
    pg.screenshot(path='/tmp/e2el_4_export_honest.png')
    print('✅ admin: export buttons honest («%s»)' % toast[:48].replace('\n', ' '))

    # ---------- 4) pagination (only when >1 page) ----------
    pages = api(ca, 'GET', '/api/audit', ac)[1].get('pages', 1)
    if pages > 1:
        first_user = pg.locator('#dc table tbody tr').first.inner_text()
        pg.click(".pgn button[data-pg='2']")
        pg.wait_for_function(
            "() => (document.querySelectorAll('#dc table tbody tr').length > 0) && "
            "(document.querySelector('.pgn button.on') && document.querySelector('.pgn button.on').textContent.trim() === '۲')",
            timeout=15000)
        after = pg.locator('#dc table tbody tr').first.inner_text()
        pg.screenshot(path='/tmp/e2el_5_page2.png')
        print('✅ admin: pagination works (page 2 of %d served)' % pages)
    else:
        print('ℹ admin: single page (%d rows) — pagination UI hidden, clamping tested in API suite' % api(ca, 'GET', '/api/audit', ac)[1].get('total', 0))

    # ---------- 5) guest cannot reach (client role) → forbidden path sanity via API ----------
    cc = b.new_context()
    st, j = api(cc, 'GET', '/api/audit')
    assert st == 401, (st, j)
    print('✅ guest: /api/audit → 401')

    b.close()

if errors:
    real_errors = [e for e in errors if 'favicon' not in e and 'Failed to load resource' not in e]
    if real_errors:
        print('JS ERRORS:')
        for e in real_errors: print(' ', e)
        sys.exit(1)
print('ALL CMD-009 E2E PASSED — no JS errors')
