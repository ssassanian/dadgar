#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-031 debug2 — capture the real pageerror on #/a (with correct env server running)."""
import time
from playwright.sync_api import sync_playwright

BASE = 'http://127.0.0.1:3202'
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page()
    errs = []
    pg.on('pageerror', lambda e: errs.append('PAGEERROR: ' + str(e)))
    pg.on('console', lambda m: errs.append('CONSOLE-ERR: ' + m.text[:200]) if m.type == 'error' else None)
    pg.goto(BASE + '/#/login')
    pg.wait_for_selector('#lu', timeout=15000)
    pg.fill('#lu', 'admin_t'); pg.fill('#lp', 'AdminT#2026x'); pg.click('[data-lg]')
    end = time.time() + 25
    while time.time() < end:
        h = pg.evaluate("() => location.hash")
        if h and h not in ('#/login', '#route_login'):
            break
        time.sleep(0.3)
    print('hash:', pg.evaluate("() => location.hash"))
    pg.goto(BASE + '/#/a')
    time.sleep(8)
    print('dc text:', pg.locator('#dc').inner_text()[:220])
    for e in errs:
        print(e[:400])
    b.close()
