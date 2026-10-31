#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-031 debug3 — case detail render: both hash formats + pageerror capture."""
import time
from playwright.sync_api import sync_playwright

BASE = 'http://127.0.0.1:3202'
CASE_ID = None
import sys
CASE_ID = sys.argv[1] if len(sys.argv) > 1 else None
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page()
    errs = []
    pg.on('pageerror', lambda e: errs.append('PAGEERROR: ' + str(e)[:300]))
    pg.on('console', lambda m: errs.append('CONSOLE-ERR: ' + m.text[:200]) if m.type == 'error' else None)
    pg.goto(BASE + '/#/login')
    pg.wait_for_selector('#lu', state='visible', timeout=15000)
    pg.fill('#lu', 'client_t'); pg.fill('#lp', 'ClientT#2026'); pg.click('[data-lg]')
    end = time.time() + 25
    while time.time() < end:
        h = pg.evaluate("() => location.hash")
        if h and h not in ('#/login', '#route_login'):
            break
        time.sleep(0.3)
    print('login hash:', pg.evaluate("() => location.hash"))
    for fmt in ['#route_c_case_' + CASE_ID, '#/c/case/' + CASE_ID]:
        errs.clear()
        pg.goto(BASE + '/#' + fmt)
        time.sleep(4)
        print('---', fmt, '->', pg.evaluate("() => location.hash"))
        print('dc:', pg.locator('#dc').inner_text()[:180].replace('\n', ' ¶ '))
        for e in errs:
            print('  ', e)
    b.close()
