#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-005 — تست مرورگر واقعی ماژول مالی (فاز ۳ گام ۳) روی هارنس محلی + دیتابیس واقعی.
سناریو: مدیر فاکتور صادر می‌کند ← ثبت پرداخت ← بازکردن ← فیلتر دوره ← مشتری فاکتور واقعی می‌بیند."""
import sys, time
from playwright.sync_api import sync_playwright

BASE = 'http://127.0.0.1:3202'
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

    # ---------- 1) ADMIN: real finance page, no demo banner ----------
    login(pg, 'admin_t', 'AdminT#2026x')
    pg.goto(BASE + '/#/a/finance')
    pg.wait_for_selector('#bcl option:nth-child(2)', state='attached', timeout=15000)  # مشتری‌ها در select آمده‌اند
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on aFin'
    assert 'فاکتوری در این بازه یافت نشد' in pg.locator('#dc').inner_text(), 'empty state expected'
    assert pg.locator('#bcl option').nth(1).inner_text().find('مشتری تست چرخه') >= 0, 'client option real'
    pg.screenshot(path='/tmp/e2eb_1_admin_empty.png')
    print('✅ admin: aFin real (stats + empty table + client select populated)')

    # ---------- 2) ADMIN: issue invoice via real form ----------
    cid = pg.eval_on_selector('#bcl', "s=>s.options[1].value")
    pg.select_option('#bcl', cid)
    pg.fill('#bam', '5000000')
    pg.click('button[data-billm]')
    pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    row = pg.locator('#dc table tbody tr').first.inner_text()
    assert 'مشتری تست چرخه' in row and 'در انتظار' in row and 'ثبت پرداخت' in row, row
    assert '۵٬۰۰۰٬۰۰۰' in row, 'amount in fa digits expected: ' + row
    pg.screenshot(path='/tmp/e2eb_2_invoice_created.png')
    print('✅ admin: manual invoice created → real row (client name + pending chip)')

    # ---------- 3) ADMIN: mark paid → revenue stat + reopen button ----------
    pg.click('button[data-bpay]')
    pg.wait_for_selector('.md [data-y]', timeout=10000)
    pg.click('.md [data-y]')
    pg.wait_for_selector('#dc .sc.s6', timeout=15000)  # chip «پرداخت‌شده»
    body = pg.locator('#dc').inner_text()
    assert 'پرداخت\u200cشده' in body and 'بازکردن' in body, body
    assert 'م.ت' in body, 'revenue stat must show millions: ' + body
    assert '۰' != pg.locator('.stt').first.locator('b').inner_text(), 'revenue must not be zero'
    pg.screenshot(path='/tmp/e2eb_3_paid.png')
    print('✅ admin: payment recorded → paid chip + revenue stat + reopen action')

    # ---------- 4) ADMIN: period filter re-render keeps row (this year) ----------
    pg.click('button[data-bpd="2"]')
    pg.wait_for_timeout(300)
    assert 'مشتری تست چرخه' in pg.locator('#dc').inner_text(), 'row must survive «امسال» filter'
    pg.click('button[data-bpd="0"]')
    pg.wait_for_timeout(300)
    print('✅ admin: period filter (این ماه/امسال) works on real data')

    # ---------- 5) ADMIN: reopen → back to pending ----------
    pg.click('button[data-bropen]')
    pg.wait_for_selector('.md [data-y]', timeout=10000)
    pg.click('.md [data-y]')
    pg.wait_for_selector('#dc .sc.s1', timeout=15000)  # chip «در انتظار»
    assert 'ثبت پرداخت' in pg.locator('#dc').inner_text()
    print('✅ admin: reopen → pending again')

    # ---------- 6) CLIENT: real invoice list + honest payment button ----------
    pg.click('[data-lo]'); wait_hash(pg, '#/login')
    login(pg, 'client_t', 'ClientT#2026')
    pg.goto(BASE + '/#/c/billing')
    pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on cBill'
    row = pg.locator('#dc table tbody tr').first.inner_text()
    assert 'در انتظار' in row and '۵٬۰۰۰٬۰۰۰' in row, row
    assert 'پرداخت آنلاین' in row and 'ثبت پرداخت' not in pg.locator('#dc').inner_text(), 'client must not see admin actions'
    pg.click('#dc button[data-ts]')  # دکمه «دانلود PDF» یا «پرداخت آنلاین» — توست صادقانه
    pg.wait_for_timeout(300)
    pg.screenshot(path='/tmp/e2eb_4_client_bill.png')
    print('✅ client: real own invoice + pending + demo-stay buttons honest (no admin ops)')

    b.close()

real_errors = [e for e in errors if 'favicon' not in e and '.jpg' not in e and '.png' not in e and 'Failed to load resource' not in e]
if real_errors:
    print('\n'.join(real_errors)); sys.exit(1)
print('ALL E2E BILLING BROWSER TESTS PASSED — no JS errors')
