#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-008 — تست مرورگر واقعی ماژول اسناد (فاز ۳ گام ۶) روی هارنس محلی + دیتابیس واقعی.
سناریو: آماده‌سازی پرونده با API (ثبت ← پیشنهاد ← تایید مدیر = assigned)
← مشتری وارد /c/documents می‌شود (بدون نوار زرد، گاوصندوق خالی) ← سند واقعی از UI آپلود می‌کند
← سند در گاوصندوق با نام/حجم/سطح دسترسی درست دیده می‌شود ← دانلود واقعی و تطابق بایت‌به‌بایت
← حذف با مودال ← گاوصندوق خالی می‌شود. بدون خطای JS."""
import os, sys
from playwright.sync_api import sync_playwright

BASE = os.environ.get('DO_BASE', 'http://127.0.0.1:3208')
errors = []

DOC = b'%PDF-1.4\n% dadgar e2e cmd-008\n' + bytes(range(256))
DOCNAME = 'سند ملک.pdf'

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
    cc = b.new_context(); cl = b.new_context(); ca = b.new_context()

    # ---------- 0) setup via API: case → proposal → accept (assigned) ----------
    cc_c = login_api(cc, 'client_t', 'ClientT#2026')
    st, j = api(cc, 'POST', '/api/cases', cc_c, {'category': 'ملکی', 'title': 'تست مرورگر اسناد — ملک', 'description': 'e2e CMD-008'})
    assert st == 200 and j.get('ok'), (st, j)
    case_id = int(j['id'])
    lc = login_api(cl, 'lawyer_t', 'LawyerT#2026')
    st, j = api(cl, 'POST', f'/api/cases/{case_id}/proposals', lc, {'amount': 5200000, 'days': 20, 'note': 'e2e'})
    assert st == 200 and j.get('ok'), (st, j)
    prop_id = int(j['id'])
    ac = login_api(ca, 'admin_t', 'AdminT#2026x')
    st, j = api(ca, 'POST', f'/api/proposals/{prop_id}/accept', ac)
    assert st == 200 and j.get('ok'), (st, j)
    st, j = api(cc, 'GET', '/api/documents', cc_c)
    assert st == 200 and j.get('rows') == [], (st, j)
    print('✅ setup: case', case_id, 'assigned; vault empty')

    # ---------- 1) CLIENT: documents page real + honest empty state ----------
    pg = cc.new_page()
    pg.on('pageerror', lambda e: errors.append('PAGEERROR-C: ' + str(e)))
    pg.on('console', lambda m: errors.append('CONSOLE-ERR-C: ' + m.text) if m.type == 'error' else None)
    pg.goto(BASE + '/#/c/documents')
    pg.wait_for_function("() => document.querySelector('#dc') && document.querySelector('#dc').innerText.includes('گاوصندوق خالی است')", timeout=15000)
    assert pg.locator('.demo').count() == 0, 'demo banner must be gone on cDocs'
    pg.screenshot(path='/tmp/e2ed_1_vault_empty.png')
    print('✅ client: documents page real (no banner, honest empty state)')

    # ---------- 2) CLIENT: upload real file via UI ----------
    pg.select_option('#dccase', str(case_id))
    pg.set_input_files('#dcfile', files=[{'name': DOCNAME, 'mimeType': 'application/pdf', 'buffer': DOC}])
    pg.screenshot(path='/tmp/e2ed_2_upload_form.png')
    pg.click('button[data-docup]')
    pg.wait_for_selector('#dc table tbody tr', timeout=15000)
    row = pg.locator('#dc table tbody tr').first.inner_text()
    assert DOCNAME in row, row
    assert 'اشتراک با وکیل' in row, 'assigned case must show shared chip: ' + row
    assert 'مگابایت' in row or 'بایت' in row, row
    pg.screenshot(path='/tmp/e2ed_3_uploaded.png')
    print('✅ client: document uploaded via UI → listed with name, size and shared chip')

    # ---------- 3) CLIENT: real download + byte match ----------
    with pg.expect_download() as dli:
        pg.click('button[data-docdl]')
    dl = dli.value
    assert dl.suggested_filename == DOCNAME, dl.suggested_filename
    dl.save_as('/tmp/e2ed_download.pdf')
    got = open('/tmp/e2ed_download.pdf', 'rb').read()
    assert got == DOC, 'downloaded bytes differ (%d vs %d)' % (len(got), len(DOC))
    pg.screenshot(path='/tmp/e2ed_4_downloaded.png')
    print('✅ client: real download, suggested filename correct, bytes identical')

    # ---------- 4) LAWYER: docs visible via API (no UI page by design — open decision) ----------
    st, j = api(cl, 'GET', '/api/documents', lc)
    assert st == 200 and len(j['rows']) == 1 and j['rows'][0]['name'] == DOCNAME, (st, j)
    print('✅ lawyer: sees the document via API (UI page is a documented open decision)')

    # ---------- 5) CLIENT: delete via modal → vault empty again ----------
    pg.click('button[data-docdel]')
    pg.wait_for_selector('.md [data-y]', state='visible', timeout=15000)
    assert 'حذف سند' in pg.locator('.md h3').inner_text()
    pg.screenshot(path='/tmp/e2ed_5_delete_modal.png')
    pg.click('.md [data-y]')
    pg.wait_for_function("() => document.querySelector('#dc') && document.querySelector('#dc').innerText.includes('گاوصندوق خالی است')", timeout=15000)
    assert pg.locator('#dc table').count() == 0
    pg.screenshot(path='/tmp/e2ed_6_deleted.png')
    print('✅ client: document deleted via modal → vault empty again')

    b.close()

if errors:
    real_errors = [e for e in errors if 'favicon' not in e and 'Failed to load resource' not in e]
    if real_errors:
        print('JS ERRORS:')
        for e in real_errors: print(' ', e)
        sys.exit(1)
print('ALL CMD-008 E2E PASSED — no JS errors')
