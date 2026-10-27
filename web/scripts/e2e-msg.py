#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-007 — تست مرورگر واقعی ماژول پیام/تیکت (فاز ۳ گام ۵) روی هارنس محلی + دیتابیس واقعی.
سناریو: آماده‌سازی پرونده با API (ثبت ← پیشنهاد ← تایید مدیر = assigned برای فعال‌شدن چت)
← مشتری تیکت می‌سازد و پاسخ می‌دهد ← مشتری در چت پرونده پیام می‌فرستد ← وکیل پاسخ می‌دهد
← مدیر تیکت را پاسخ می‌دهد و می‌بندد (+فیلتر وضعیت) ← مشتری پاسخ مدیر را می‌بیند و فرم پاسخ بسته است."""
import os, sys
from playwright.sync_api import sync_playwright

BASE = os.environ.get('MS_BASE', 'http://127.0.0.1:3206')
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

# ورود فقط با API؛ کوکی در کانتکست مرورگر هست و UI مستقیم به صفحه‌ی هدف می‌رود.

with sync_playwright() as p:
    b = p.chromium.launch()
    cc = b.new_context(); cl = b.new_context(); ca = b.new_context()

    # ---------- 0) setup via API: case → proposal → accept (assigned) ----------
    cc_c = login_api(cc, 'client_t', 'ClientT#2026')
    st, j = api(cc, 'POST', '/api/cases', cc_c, {'category': 'قرارداد', 'title': 'تست مرورگر پیام — قرارداد', 'description': 'e2e CMD-007'})
    assert st == 200 and j.get('ok'), (st, j)
    case_id = int(j['id'])
    lc = login_api(cl, 'lawyer_t', 'LawyerT#2026')
    st, j = api(cl, 'POST', f'/api/cases/{case_id}/proposals', lc, {'amount': 6500000, 'days': 15, 'note': 'e2e'})
    assert st == 200 and j.get('ok'), (st, j)
    prop_id = int(j['id'])
    ac = login_api(ca, 'admin_t', 'AdminT#2026x')
    st, j = api(ca, 'POST', f'/api/proposals/{prop_id}/accept', ac)
    assert st == 200 and j.get('ok'), (st, j)
    print('✅ setup: case', case_id, 'assigned (chat open)')

    # ---------- 1) CLIENT: tickets list real + empty state ----------
    pg = cc.new_page()
    pg.on('pageerror', lambda e: errors.append('PAGEERROR-C: ' + str(e)))
    pg.on('console', lambda m: errors.append('CONSOLE-ERR-C: ' + m.text) if m.type == 'error' else None)
    pg.goto(BASE + '/#/c/tickets')
    pg.wait_for_function("() => document.querySelector('#dc') && document.querySelector('#dc').innerText.includes('هنوز تیکتی ندارید')", timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on tk'
    pg.screenshot(path='/tmp/e2em_1_client_tickets_empty.png')
    print('✅ client: tickets page real (no banner, honest empty state)')

    # ---------- 2) CLIENT: create ticket via real form ----------
    pg.click('a[href="#/c/ticket/new"]')
    pg.wait_for_selector('#tks', state='visible', timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on tkNew'
    pg.select_option('#tkd', 'فنی')
    pg.select_option('#tkp', 'بالا')
    pg.fill('#tks', 'خطا در بارگذاری فایل پرونده')
    pg.fill('#tkb', 'سلام، فایل پرونده بارگذاری نمی\u200cشود. لطفاً بررسی کنید.')
    pg.screenshot(path='/tmp/e2em_2_new_ticket_form.png')
    pg.click('button[data-tkcreate]')
    pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    row = pg.locator('#dc table tbody tr').first.inner_text()
    assert 'خطا در بارگذاری فایل' in row and 'باز' in row, row
    href = pg.locator('#dc table tbody tr').first.locator('a').first.get_attribute('href')
    tid = int(href.rsplit('/', 1)[1])
    pg.screenshot(path='/tmp/e2em_3_ticket_created.png')
    print('✅ client: ticket created via UI → listed with «باز» chip, id =', tid)

    # ---------- 3) CLIENT: ticket detail + reply ----------
    pg.click(f'a[href="#/c/ticket/{tid}"]')
    pg.wait_for_selector('#tkrep', state='visible', timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on tkDet'
    assert pg.locator('#dc .msgs .m').count() == 1
    pg.fill('#tkrep', 'تکمیل: با فایل ZIP هم امتحان کردم، نشد.')
    pg.click('button[data-tkreply]')
    pg.wait_for_function("() => document.querySelectorAll('#dc .msgs .m').length >= 2", timeout=15000)
    print('✅ client: reply posted → conversation now', pg.locator('#dc .msgs .m').count(), 'messages')

    # ---------- 4) CLIENT: case chat — thread list + send message ----------
    pg.goto(BASE + '/#/c/chat')
    pg.wait_for_selector('[data-th]', state='visible', timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on chat'
    th = pg.locator('[data-th]').first
    th.click()
    pg.wait_for_selector('#mgtx', state='visible', timeout=15000)
    body = pg.locator('#dc').inner_text()
    assert 'تست مرورگر پیام' in body, body[:300]
    pg.fill('#mgtx', 'سلام، مدارک را ایمیل کنم؟')
    pg.click('button[data-msgsend]')
    pg.wait_for_function("() => document.querySelectorAll('#dc .msgs .m').length >= 1", timeout=15000)
    assert 'ایمیل کنم' in pg.locator('#dc .msgs').inner_text()
    pg.screenshot(path='/tmp/e2em_4_client_chat.png')
    print('✅ client: case chat real — message sent and rendered')

    # ---------- 5) LAWYER: sees thread, reads client msg, replies ----------
    pg2 = cl.new_page()
    pg2.on('pageerror', lambda e: errors.append('PAGEERROR-L: ' + str(e)))
    pg2.on('console', lambda m: errors.append('CONSOLE-ERR-L: ' + m.text) if m.type == 'error' else None)
    pg2.goto(BASE + '/#/l/chat')
    pg2.wait_for_selector('[data-th]', state='visible', timeout=15000)
    assert pg2.locator('.demo').count() == 0, 'demo banner must be gone on lawyer chat'
    excerpt = pg2.locator('[data-th] small').first.inner_text()
    assert 'ایمیل کنم' in excerpt, 'thread excerpt should show last message: ' + excerpt
    pg2.click('[data-th]')
    pg2.wait_for_selector('#mgtx', state='visible', timeout=15000)
    assert 'ایمیل کنم' in pg2.locator('#dc .msgs').inner_text()
    pg2.fill('#mgtx', 'سلام، بله؛ شنبه تا چهارشنبه پاسخ می\u200cدهم.')
    pg2.click('button[data-msgsend]')
    pg2.wait_for_function("() => document.querySelectorAll('#dc .msgs .m').length >= 2", timeout=15000)
    pg2.screenshot(path='/tmp/e2em_5_lawyer_chat.png')
    print('✅ lawyer: read client message + replied (conversation =', pg2.locator('#dc .msgs .m').count(), ')')

    # ---------- 6) LAWYER: tickets list shows own empty (client ticket hidden) ----------
    pg2.goto(BASE + '/#/l/tickets')
    pg2.wait_for_function("() => document.querySelector('#dc') && document.querySelector('#dc').innerText.includes('هنوز تیکتی ندارید')", timeout=15000)
    print('✅ lawyer: cannot see client ticket in own list')

    # ---------- 7) ADMIN: list with real name + filters ----------
    pg3 = ca.new_page()
    pg3.on('pageerror', lambda e: errors.append('PAGEERROR-A: ' + str(e)))
    pg3.on('console', lambda m: errors.append('CONSOLE-ERR-A: ' + m.text) if m.type == 'error' else None)
    pg3.goto(BASE + '/#/a/tickets')
    pg3.wait_for_selector('#dc table tbody tr', state='visible', timeout=15000)
    assert pg3.locator('.demo').count() == 0, 'demo banner must be gone on admin tk'
    body = pg3.locator('#dc').inner_text()
    assert 'مشتری تست چرخه' in body, 'admin must see sender name: ' + body[:300]
    assert str(tid) in body or 'باز' in body
    pg3.screenshot(path='/tmp/e2em_6_admin_list.png')
    print('✅ admin: sees ticket with sender name + filters')

    # ---------- 8) ADMIN: ticket detail → reply (→answered) → close via apply ----------
    pg3.click(f'a[href="#/a/ticket/{tid}"]')
    pg3.wait_for_selector('#tkrep', state='visible', timeout=15000)
    assert 'مشتری تست چرخه' in pg3.locator('#dc').inner_text()
    pg3.fill('#tkrep', 'سلام، مشکل از فرمت فایل بود؛ لطفاً PDF کمتر از ۱۰ مگابایت ارسال کنید.')
    pg3.click('button[data-tkreply]')
    pg3.wait_for_function("() => document.querySelectorAll('#dc .msgs .m').length >= 3", timeout=15000)
    assert 'پاسخ داده\u200cشده' in pg3.locator('#dc').inner_text(), 'answered chip expected'
    pg3.select_option('#tkst', 'closed')
    pg3.click('button[data-tkapply]')
    pg3.wait_for_function("() => document.querySelector('#dc').innerText.includes('بسته')", timeout=15000)
    pg3.screenshot(path='/tmp/e2em_7_admin_closed.png')
    print('✅ admin: replied (→answered) then closed via apply — chips update')

    # ---------- 9) ADMIN: dept filter (negative + positive) ----------
    pg3.goto(BASE + '/#/a/tickets')
    pg3.wait_for_selector('#tkfs', state='visible', timeout=15000)
    pg3.select_option('#tkfd', 'مالی')
    pg3.wait_for_function("() => document.querySelector('#dc').innerText.includes('تیکتی ثبت نشده است')", timeout=15000)
    pg3.select_option('#tkfd', 'فنی')
    pg3.wait_for_function("() => document.querySelector('#dc table tbody tr') && document.querySelector('#dc table tbody tr').innerText.includes('بسته')", timeout=15000)
    pg3.screenshot(path='/tmp/e2em_7b_admin_filter.png')
    print('✅ admin: dept filter works (مالی → empty، فنی → بسته‌شده)')

    # ---------- 10) CLIENT: sees admin reply + closed (no reply input) ----------
    pg.reload()
    pg.goto(BASE + f'/#/c/ticket/{tid}')
    pg.wait_for_selector('#dc .msgs .m', state='visible', timeout=15000)
    msgs = pg.locator('#dc .msgs .m').count()
    assert msgs >= 3, msgs
    assert 'فرمت فایل' in pg.locator('#dc .msgs').inner_text()
    assert 'بسته' in pg.locator('#dc').inner_text()
    assert pg.locator('#tkrep').count() == 0, 'reply input must be gone when closed'
    pg.screenshot(path='/tmp/e2em_8_client_closed.png')
    print('✅ client: sees admin reply + closed status; reply form hidden')

    b.close()

if errors:
    real_errors = [e for e in errors if 'favicon' not in e and 'Failed to load resource' not in e]
    if real_errors:
        print('JS ERRORS:')
        for e in real_errors: print(' ', e)
        sys.exit(1)
print('ALL CMD-007 E2E PASSED — no JS errors')
