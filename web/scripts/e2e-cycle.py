#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-003 — تست مرورگر واقعی چرخه پرونده (فاز ۳ گام ۱) روی هارنس محلی + دیتابیس واقعی.
سناریو: مشتری ثبت پرونده (ویزارد) ← وکیل پیشنهاد ← مدیر تایید و تخصیص ← وضعیت برای مشتری."""
import sys, time
from playwright.sync_api import sync_playwright, expect

BASE = 'http://127.0.0.1:3202'
TITLE = 'قرارداد همکاری حقوقی برای بازبینی بند فسخ'
errors = []

def wait_hash(pg, h, timeout=15000):
    pg.wait_for_function("h=>location.hash===h", arg=h, timeout=timeout)

def login(pg, user, pwd):
    pg.goto(BASE + '/#/login')
    pg.fill('#lu', user)
    pg.fill('#lp', pwd)
    pg.click('[data-lg]')
    end = time.time() + 15
    while time.time() < end:
        cur = pg.evaluate("() => location.hash")
        if cur and cur != '#/login':
            return
        time.sleep(0.2)
    raise TimeoutError('login redirect never happened; hash=' + str(pg.evaluate("() => location.hash")))

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page()
    pg.on('pageerror', lambda e: errors.append('PAGEERROR: ' + str(e)))
    pg.on('console', lambda m: errors.append('CONSOLE-ERR: ' + m.text) if m.type == 'error' else None)

    # ---------- 1) CLIENT: wizard ----------
    login(pg, 'client_t', 'ClientT#2026')
    print('client logged in →', pg.evaluate("() => location.hash"))
    pg.goto(BASE + '/#/c/new'); pg.wait_for_timeout(600)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on cNew'
    pg.click('button[data-wc="قرارداد"]')
    pg.click('button[data-w="n"]')
    pg.fill('#wt', TITLE)
    pg.fill('#wds', 'قرارداد همکاری با بند فسخ مبهم؛ نیاز به بازبینی و اصلاح حقوقی دارد.')
    pg.click('button[data-w="n"]')
    pg.wait_for_timeout(300)
    pg.click('button[data-w="n"]')  # step3 (مدارک — نمایشی) → پیش‌نمایش
    pg.wait_for_timeout(300)
    assert 'بازبینی' in pg.locator('#dc').inner_text(), 'preview should show title'
    pg.click('button[data-w="s"]')  # ثبت نهایی واقعی
    wait_hash(pg, '#/c/cases')
    pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    row = pg.locator('#dc table tbody tr').first.inner_text()
    assert TITLE[:20] in row, 'new case must appear in client list: ' + row
    assert 'در انتظار بررسی' in row, 'status chip waiting'
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on cCases'
    pg.screenshot(path='/tmp/e2e_1_client_cases.png')
    print('✅ client: case created via wizard + list real + no demo banner')

    # ---------- 2) LAWYER: open cases + proposal ----------
    pg.click('[data-lo]'); wait_hash(pg, '#/login')
    login(pg, 'lawyer_t', 'LawyerT#2026')
    pg.goto(BASE + '/#/l/open'); pg.wait_for_timeout(900)
    card = pg.locator('.card2.fr', has_text='بازبینی بند فسخ').first
    card.locator('a.btn').click()  # ارسال پیشنهاد
    pg.wait_for_selector('#pa', timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on lProp'
    pg.fill('#pa', '7500000')
    pg.fill('#pd', '25')
    pg.fill('#pnt', 'یادداشت خصوصی تست برای مدیر.')
    pg.click('button[data-pr]')
    wait_hash(pg, '#/l/proposals')
    pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    prows = pg.locator('#dc table tbody tr').first.inner_text()
    assert 'در انتظار' in prows and '۷٬۵۰۰٬۰۰۰' in prows, 'proposal row: ' + prows
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on lProps'
    pg.screenshot(path='/tmp/e2e_2_lawyer_props.png')
    print('✅ lawyer: open list real + proposal submitted + list real')

    # ---------- 3) ADMIN: case list → detail → accept ----------
    pg.click('[data-lo]'); wait_hash(pg, '#/login')
    login(pg, 'admin_t', 'AdminT#2026x')
    pg.goto(BASE + '/#/a/cases'); pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on aCases'
    pg.locator('#dc table tbody tr').first.locator('a').click()
    pg.wait_for_selector('button[data-ok]', timeout=15000)
    assert 'مشتری تست چرخه' in pg.locator('#dc').inner_text(), 'admin sees client name'
    pg.screenshot(path='/tmp/e2e_3_admin_case.png')
    pg.click('button[data-ok]')
    pg.wait_for_selector('.md [data-y]', timeout=10000)
    pg.click('.md [data-y]')
    pg.wait_for_selector('#dc .sc.s3', timeout=15000)  # تخصیص‌یافته chip
    body = pg.locator('#dc').inner_text()
    assert 'تایید\u200cشده' in body and 'وکیل تست چرخه' in body, 'accepted proposal + lawyer name'
    pg.screenshot(path='/tmp/e2e_4_admin_assigned.png')
    print('✅ admin: list real + detail real + accept → assigned')

    # ---------- 4) CLIENT: sees assigned ----------
    pg.click('[data-lo]'); wait_hash(pg, '#/login')
    login(pg, 'client_t', 'ClientT#2026')
    pg.goto(BASE + '/#/c/cases'); pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    row = pg.locator('#dc table tbody tr', has_text='بازبینی بند فسخ').first.inner_text()
    assert 'تخصیص\u200cیافته' in row, 'client sees assigned status: ' + row
    pg.screenshot(path='/tmp/e2e_5_client_assigned.png')
    print('✅ client: status تخصیص‌یافته visible')

    b.close()

real_errors = [e for e in errors if 'favicon' not in e and '.jpg' not in e and '.png' not in e and 'Failed to load resource' not in e]
if real_errors:
    print('\n'.join(real_errors)); sys.exit(1)
print('ALL E2E BROWSER TESTS PASSED — no JS errors')
