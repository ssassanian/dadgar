#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-006 — تست مرورگر واقعی ماژول نظرات (فاز ۳ گام ۴) روی هارنس محلی + دیتابیس واقعی.
سناریو: آماده‌سازی چرخه پرونده با API (مشتری ← پیشنهاد وکیل ← تایید مدیر ← done)
← مشتری در cRev نظر ثبت می‌کند ← وکیل ماسک‌شده می‌بیند ← عمومی خالی ← مدیر تایید می‌کند
← عمومی منتشر می‌شود ← وضعیت در فهرست مشتری «منتشرشده» می‌شود."""
import os, sys, time
from playwright.sync_api import sync_playwright

BASE = os.environ.get('RV_BASE', 'http://127.0.0.1:3204')
errors = []

def api(ctx, method, path, csrf=None, data=None):
    headers = {}
    if csrf: headers['x-csrf-token'] = csrf
    fn = getattr(ctx.request, method.lower())
    r = fn(BASE + path, headers=headers, data=data)  # data=dict → JSON
    try: j = r.json()
    except Exception: j = {}
    return r.status, j

def login_api(ctx, user, pwd):
    st, j = api(ctx, 'POST', '/api/auth/login', data={'username': user, 'password': pwd})
    assert st == 200 and j.get('csrf'), (st, j)
    return j['csrf']

# توجه: ورود فقط با API انجام می‌شود؛ کوکی نشست در کانتکست مرورگر هست و UI مستقیم
# به صفحه‌ی هدف می‌رود (صفحه‌ی login برای کاربر واردشده ریدایرکت می‌کند).

with sync_playwright() as p:
    b = p.chromium.launch()
    cc = b.new_context(); cl = b.new_context(); ca = b.new_context()

    # ---------- 0) setup via API: case → proposal → accept → running → done ----------
    cc_c = login_api(cc, 'client_t', 'ClientT#2026')
    st, j = api(cc, 'POST', '/api/cases', cc_c, {'category': 'قرارداد', 'title': 'تست مرورگر نظرات — ملک', 'description': 'e2e CMD-006'})
    assert st == 200 and j.get('ok'), (st, j)
    case_id = int(j['id'])  # lastInsertRowid ممکن است رشته برگردد
    lc = login_api(cl, 'lawyer_t', 'LawyerT#2026')
    st, j = api(cl, 'GET', '/api/cases?scope=open')
    assert st == 200 and any(r['id'] == case_id for r in j['rows']), (st, case_id)
    st, j = api(cl, 'POST', f'/api/cases/{case_id}/proposals', lc, {'amount': 6500000, 'days': 15, 'note': 'e2e'})
    assert st == 200 and j.get('ok'), (st, j)
    prop_id = int(j['id'])
    ac = login_api(ca, 'admin_t', 'AdminT#2026x')
    st, j = api(ca, 'POST', f'/api/proposals/{prop_id}/accept', ac)
    assert st == 200 and j.get('ok'), (st, j)
    st, j = api(ca, 'PATCH', f'/api/cases/{case_id}', ac, {'status': 'done'})
    assert st == 200 and j.get('ok'), (st, j)
    print('✅ setup: case', case_id, 'reached done (real cycle via API)')

    # ---------- 1) CLIENT: cRev real, no banner, real form ----------
    pg = cc.new_page()
    pg.on('pageerror', lambda e: errors.append('PAGEERROR: ' + str(e)))
    pg.on('console', lambda m: errors.append('CONSOLE-ERR: ' + m.text) if m.type == 'error' else None)
    pg.goto(BASE + '/#/c/review')
    pg.wait_for_selector('#rvcs option', state='attached', timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on cRev'
    opt = pg.locator('#rvcs option').first.inner_text()
    assert 'پرونده ' in opt and 'تست مرورگر نظرات' in opt, opt
    pg.screenshot(path='/tmp/e2er_1_client_form.png')
    print('✅ client: cRev real form with done case in select')

    # ---------- 2) CLIENT: submit review (stars + body + consent) ----------
    pg.click('[data-rt="4"]')
    pg.fill('#rvtx', 'پیگیری دقیق، گزارش‌های منظم و صادقانه.')
    pg.check('#rvok')
    pg.click('button[data-revsave]')
    pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    row = pg.locator('#dc table tbody tr').first.inner_text()
    assert 'در انتظار تایید مدیر' in row, row
    assert 'تست مرورگر نظرات' in row, row
    pg.screenshot(path='/tmp/e2er_2_submitted.png')
    print('✅ client: review submitted → pending-moderation chip in my list')
    pg.wait_for_timeout(400)
    assert pg.locator('#rvcs').count() == 0, 'select must be gone after review'
    print('✅ client: duplicate prevented in UI (no reviewable case left)')

    # ---------- 3) LAWYER: masked list + avg ----------
    pg2 = cl.new_page()
    pg2.on('pageerror', lambda e: errors.append('PAGEERROR-L: ' + str(e)))
    pg2.on('console', lambda m: errors.append('CONSOLE-ERR-L: ' + m.text) if m.type == 'error' else None)
    pg2.goto(BASE + '/#/l/reviews')
    pg2.wait_for_selector('.pb b', state='visible', timeout=15000)
    assert pg2.locator('.demo').count() == 0, 'demo banner must be gone on lRev'
    body = pg2.locator('#dc').inner_text()
    assert 'م. ت. چ.' in body, 'masked initial expected: ' + body[:300]
    assert 'مشتری تست چرخه' not in body, 'FULL NAME LEAK to lawyer UI'
    assert 'از ۱ نظر ثبت‌شده' in body, 'avg/count expected: ' + body[:300]
    pg2.screenshot(path='/tmp/e2er_3_lawyer.png')
    print('✅ lawyer: real avg + masked client initial, no full name')

    # ---------- 4) GUEST: public page real (moderation gate — empty) ----------
    pg3 = b.new_page()  # بدون ورود
    pg3.on('pageerror', lambda e: errors.append('PAGEERROR-G: ' + str(e)))
    pg3.on('console', lambda m: errors.append('CONSOLE-ERR-G: ' + m.text) if m.type == 'error' else None)
    pg3.goto(BASE + '/#/reviews')
    pg3.wait_for_selector('#app .card2', state='visible', timeout=15000)
    # نکته‌ی معماری: صفحات عمومی DEMOBN نمی‌گیرند؛ واقعی‌بودن با پیام خالیِ واقعی و نبود داده‌ی نمایشی اثبات می‌شود
    body = pg3.locator('#app').inner_text()
    assert 'هنوز نظری منتشر نشده است' in body, body[:300]
    assert 'م. ک.' not in body, 'demo data must be gone on public reviews'
    print('✅ guest: public page real (moderation gate — empty, no demo data)')

    # ---------- 5) ADMIN approves via API ----------
    st, j = api(ca, 'GET', '/api/reviews')
    assert st == 200 and len(j['rows']) == 1, (st, j)
    rid = j['rows'][0]['id']
    st, j = api(ca, 'PATCH', f'/api/reviews/{rid}', ac, {'approved': True})
    assert st == 200 and j.get('ok'), (st, j)
    print('✅ admin: review approved (API)')

    # ---------- 6) GUEST: published card (fresh reload to refetch) ----------
    pg3.reload()
    pg3.wait_for_selector('#app .card2.fr', state='visible', timeout=15000)
    body = pg3.locator('#app').inner_text()
    assert 'تاییدشده · با رضایت موکل' in body, body[:400]
    assert 'پیگیری دقیق، گزارش‌های منظم' in body, body[:400]
    assert 'م. ت. چ.' in body and 'مشتری تست چرخه' not in body, 'mask leak on public'
    assert 'م. ک.' not in body, 'demo data must stay gone'
    pg3.screenshot(path='/tmp/e2er_4_public.png')
    print('✅ guest: published review visible with mask + consent chip')

    # ---------- 7) CLIENT: published state in own list (fresh reload) ----------
    pg.reload()
    pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    assert 'منتشر\u200cشده' in pg.locator('#dc').inner_text(), 'published chip expected'
    print('✅ client: sees «منتشرشده» in own review list')

    b.close()

if errors:
    real_errors = [e for e in errors if 'favicon' not in e and '.jpg' not in e and '.png' not in e and 'Failed to load resource' not in e]
    if real_errors:
        print('JS ERRORS:')
        for e in real_errors: print(' ', e)
        sys.exit(1)
print('ALL CMD-006 E2E PASSED — no JS errors')
