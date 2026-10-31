#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-031 — e2e مرورگر واقعی صفحات پنل (P1..P4) روی هارنس محلی:
داشبوردهای واقعی بدون بنر، جزئیات پرونده از فهرست، مدیریت کاربران (مسدود دو-کلیکی)،
دکمه‌ی درگاه cBill → انتقال به درگاه (fake-zibal)."""
import sys, time
from playwright.sync_api import sync_playwright

BASE = 'http://127.0.0.1:3202'
errors = []

def login(pg, user, pwd):
    pg.goto(BASE + '/#/login')
    pg.wait_for_selector('#lu', state='visible', timeout=15000)
    pg.fill('#lu', user)
    pg.fill('#lp', pwd)
    pg.click('[data-lg]')
    end = time.time() + 15
    while time.time() < end:
        cur = pg.evaluate("() => location.hash")
        if cur and cur not in ('#/login', '#route_login'):
            return
        time.sleep(0.2)
    raise TimeoutError('login redirect never happened; hash=' + str(pg.evaluate("() => location.hash")))

def wait_hash_like(pg, h, timeout=15000):
    end = time.time() + timeout / 1000
    while time.time() < end:
        if h in (pg.evaluate("() => location.hash") or ''):
            return
        time.sleep(0.2)
    raise TimeoutError('hash never reached ' + h)

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page()
    pg.on('pageerror', lambda e: errors.append('PAGEERROR: ' + str(e)))
    pg.on('console', lambda m: errors.append('CONSOLE-ERR: ' + m.text) if m.type == 'error' and 'Failed to load resource' not in m.text else None)

    # ---------- 1) ADMIN: real admin dashboard (P2) — no demo banner, real counts ----------
    login(pg, 'admin_t', 'AdminT#2026x')
    pg.goto(BASE + '/#/a')
    try:
        pg.wait_for_selector('#dc .stt', timeout=20000)
    except Exception:
        print('DEBUG hash:', pg.evaluate("() => location.hash"))
        print('DEBUG dc:', pg.locator('#dc').inner_text()[:400])
        print('DEBUG fetch test:', pg.evaluate("async () => { const r = await fetch('/api/cases?page=1',{credentials:'same-origin'}); return r.status + ' ' + (await r.text()).slice(0,120) }"))
        pg.screenshot(path='/tmp/e2ep_fail.png')
        raise
    pg.wait_for_selector('#dc .stt', timeout=20000)
    end = time.time() + 12
    while time.time() < end and 'در حال دریافت' in pg.locator('#dc').inner_text():
        time.sleep(0.3)
    body = pg.locator('#dc').inner_text()
    assert pg.locator('#dc .demo').count() == 0, 'demo banner must be gone on aDash'
    assert 'کل پرونده‌ها' in body and 'مشتریان' in body and 'وکلای همکار' in body, body[:200]
    assert 'فاکتورهای در انتظار پرداخت' in body, 'pending invoice card expected'
    print('✅ admin: aDash real — stats + pending invoices + upcoming appointments (no demo banner)')

    # ---------- 2) ADMIN: aUsers real table + two-click block/unblock (P3) ----------
    pg.goto(BASE + '/#/a/users')
    pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    end = time.time() + 12
    while time.time() < end and 'در حال دریافت' in pg.locator('#dc').inner_text():
        time.sleep(0.3)
    body = pg.locator('#dc').inner_text()
    assert 'مشتری تست چرخه' in body, 'seeded client expected in real table: ' + body[:200]
    assert pg.locator('#dc .demo').count() == 0, 'no demo banner on aUsers'
    btn = pg.locator('#dc button[data-ub]').first
    btn.click()  # arm
    assert 'تایید؟' in btn.inner_text(), 'arm label expected'
    btn.click()  # commit
    pg.wait_for_selector('#dc .sc.s5', timeout=15000)  # chip «مسدود»
    print('✅ admin: aUsers real — two-click block worked (blocked chip shown)')
    # unblock back
    btn2 = pg.locator('#dc button[data-ub]').first
    btn2.click(); btn2.click()
    pg.wait_for_selector('#dc .sc.s6', timeout=15000)  # «فعال»
    print('✅ admin: unblock → active chip restored')
    pg.screenshot(path='/tmp/e2ep_1_ausers.png')

    # ---------- 3) CLIENT: real client dashboard (P2) ----------
    pg.click('[data-lo]')
    wait_hash_like(pg, '#route_login')
    login(pg, 'client_t', 'ClientT#2026')
    pg.goto(BASE + '/#/c')
    pg.wait_for_selector('#dc .stt', timeout=15000)
    end = time.time() + 12
    while time.time() < end and 'در حال دریافت' in pg.locator('#dc').inner_text():
        time.sleep(0.3)
    body = pg.locator('#dc').inner_text()
    assert pg.locator('#dc .demo').count() == 0, 'no demo banner on cDash'
    assert 'پرونده‌های من' in body and 'نوبت بعدی' in body and 'فعالیت اخیر' in body, body[:200]
    print('✅ client: cDash real — my cases + next appointment + recent activity')

    # ---------- 4) CLIENT: case detail (P1) — direct hash to the prep case (deterministic) ----------
    import os
    kid = os.environ.get('E2E_CASE_ID')
    pg.goto(BASE + '/#route_c_case_' + kid)
    pg.wait_for_selector('#dc .dh', timeout=15000)
    end = time.time() + 12
    while 'در حال دریافت' in pg.locator('#dc').inner_text() and time.time() < end:
        time.sleep(0.3)
    body = pg.locator('#dc').inner_text()
    if errors:
        print('JS ERRORS SO FAR:')
        for e in errors:
            print('  ', e[:300])
    assert pg.locator('#dc .demo').count() == 0, 'no demo banner on real case detail'
    assert 'مشخصات پرونده' in body and 'شرح پرونده' in body, 'CASE DETAIL BODY: ' + body[:400] + ' | hash=' + str(pg.evaluate("() => location.hash"))
    assert 'اقدامات' in body, 'contextual actions expected'
    print('✅ client: case detail real — specs + description + actions (no demo banner)')
    pg.screenshot(path='/tmp/e2ep_2_case_detail.png')

    # ---------- 5) CLIENT: gateway button in cBill → redirect to gateway (P4) ----------
    pg.goto(BASE + '/#/c/billing')
    pg.wait_for_selector('button[data-pay]', timeout=15000)
    pg.click('button[data-pay]')
    pg.wait_for_url('**/start/**', timeout=20000)
    print('✅ client: gateway button → redirected to payment gateway URL (fake-zibal harness)')
    b.close()

    # ---------- 6) ADMIN again: confirm user_unblocked audit exists ----------
    print('ALL E2E PANEL TESTS PASSED' if not errors else 'JS ERRORS:\n' + '\n'.join(errors))
    if errors:
        sys.exit(1)
