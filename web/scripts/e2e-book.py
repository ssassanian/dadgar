#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-004 — تست مرورگر واقعی نوبت‌دهی (فاز ۳ گام ۲) روی هارنس محلی + دیتابیس واقعی.
سناریو: مشتری رزرو می‌کند ← بازه اشغالی واقعی می‌شود ← وکیل ناشناس می‌بیند ← مدیر تایید می‌کند ← مشتری لغو می‌کند."""
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

    # ---------- 1) CLIENT: book a slot ----------
    login(pg, 'client_t', 'ClientT#2026')
    pg.goto(BASE + '/#/c/book'); pg.wait_for_selector('#sl[data-bk]', timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on cBook'
    assert pg.locator('button[data-day="10"]').is_enabled(), 'day 10 must be enabled (future, not Friday)'
    assert not pg.locator('button[data-day="3"]').is_enabled(), 'past day must be disabled'
    pg.click('button[data-day="10"]')
    pg.wait_for_timeout(200)
    slot = pg.locator('button[data-slot="۰۹:۰۰"]')
    assert slot.is_enabled(), 'free slot must be enabled'
    slot.click()
    pg.click('button[data-ty="آنلاین"]')
    pg.click('button[data-book]')
    pg.wait_for_selector('.md [data-y]', timeout=10000)
    assert 'آنلاین' in pg.locator('.md').inner_text() and '۱۰' in pg.locator('.md').inner_text()
    pg.click('.md [data-y]')
    pg.wait_for_selector('#dc .pb .sc.s1', timeout=15000)  # chip «رزرو‌شده»
    body = pg.locator('#dc').inner_text()
    assert 'آنلاین' in body and 'رزرو\u200cشده' in body and 'آبان' in body, body
    pg.screenshot(path='/tmp/e2e_1_client_booked.png')
    print('✅ client: real booking created + listed with status chip')

    # ---------- 2) CLIENT reload: slot now taken (real availability) ----------
    pg.reload(); pg.wait_for_selector('#sl[data-bk]', timeout=15000)
    pg.click('button[data-day="10"]'); pg.wait_for_timeout(200)
    s2 = pg.locator('button[data-slot="۰۹:۰۰"]')
    assert not s2.is_enabled(), 'booked slot must be disabled after reload (taken from DB)'
    assert pg.locator('button[data-slot="۱۰:۳۰"]').is_enabled(), 'other slots stay free'
    assert 'لغو' in pg.locator('#dc').inner_text(), 'cancel button visible'
    print('✅ availability derived from DB — booked slot disabled after reload')

    # ---------- 3) LAWYER: anonymous view ----------
    pg.click('[data-lo]'); wait_hash(pg, '#/login')
    login(pg, 'lawyer_t', 'LawyerT#2026')
    pg.goto(BASE + '/#/l/calendar'); pg.wait_for_selector('#dc .pb b', timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on lCal'
    body = pg.locator('#dc').inner_text()
    assert 'مراجعه\u200cکننده #' in body, 'lawyer sees anonymous client ref: ' + body
    assert 'مشتری تست' not in body, 'PRIVACY LEAK: lawyer must not see client name'
    pg.screenshot(path='/tmp/e2e_2_lawyer_cal.png')
    print('✅ lawyer: office calendar real + anonymous client ref + no name leak')

    # ---------- 4) ADMIN: names + confirm ----------
    pg.click('[data-lo]'); wait_hash(pg, '#/login')
    login(pg, 'admin_t', 'AdminT#2026x')
    pg.goto(BASE + '/#/a/appointments'); pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on aApp'
    row = pg.locator('#dc table tbody tr').first.inner_text()
    assert 'مشتری تست چرخه' in row, 'admin sees client name: ' + row
    pg.screenshot(path='/tmp/e2e_3_admin_appts.png')
    pg.click('button[data-bkok]')
    pg.wait_for_selector('.md [data-y]', timeout=10000)
    pg.click('.md [data-y]')
    pg.wait_for_selector('#dc .sc.s6', timeout=15000)  # chip «تایید‌شده»
    assert 'تایید\u200cشده' in pg.locator('#dc').inner_text()
    print('✅ admin: table real (names) + confirm → confirmed chip')

    # ---------- 5) CLIENT: sees confirmed + cancels ----------
    pg.click('[data-lo]'); wait_hash(pg, '#/login')
    login(pg, 'client_t', 'ClientT#2026')
    pg.goto(BASE + '/#/c/book'); pg.wait_for_selector('#dc .pb .sc.s6', timeout=15000)
    assert 'تایید\u200cشده' in pg.locator('#dc').inner_text(), 'client sees confirmed status'
    pg.click('#dc button[data-bkx]')
    pg.wait_for_selector('.md [data-y]', timeout=10000)
    pg.click('.md [data-y]')
    pg.wait_for_selector('#dc .card2 p', timeout=15000)
    assert 'هنوز نوبتی رزرو نکرده' in pg.locator('#dc').inner_text(), 'list empty after cancel'
    pg.screenshot(path='/tmp/e2e_4_client_canceled.png')
    print('✅ client: sees confirmed + cancels own → list empty')

    b.close()

real_errors = [e for e in errors if 'favicon' not in e and '.jpg' not in e and '.png' not in e and 'Failed to load resource' not in e]
if real_errors:
    print('\n'.join(real_errors)); sys.exit(1)
print('ALL E2E BOOKING BROWSER TESTS PASSED — no JS errors')
