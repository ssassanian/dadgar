#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-031 debug — inspect aDash render state"""
import time, sys
from playwright.sync_api import sync_playwright

BASE = 'http://127.0.0.1:3202'
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page()
    errs = []
    pg.on('pageerror', lambda e: errs.append('PAGEERROR: ' + str(e)))
    pg.on('console', lambda m: errs.append('CONSOLE-' + m.type + ': ' + m.text) if m.type in ('error', 'warning') else None)
    pg.goto(BASE + '/#/login')
    pg.fill('#lu', 'admin_t'); pg.fill('#lp', 'AdminT#2026x'); pg.click('[data-lg]')
    time.sleep(3)
    print('after login hash:', pg.evaluate("() => location.hash"))
    pg.goto(BASE + '/#/a')
    time.sleep(6)
    print('hash:', pg.evaluate("() => location.hash"))
    dc = pg.locator('#dc')
    print('dc exists:', dc.count())
    print('dc text (first 300):', dc.inner_text()[:300] if dc.count() else 'N/A')
    print('VR.aDash defined:', pg.evaluate("() => typeof VR.aDash"))
    print('PC keys:', pg.evaluate("() => Object.keys(window.PC||{})"))
    print('PC.da o keys:', pg.evaluate("() => {var d=window.PC&&window.PC['da'];if(!d)return null;return Object.keys(d.o).map(k=>[k,d.o[k]&&d.o[k].ok,d.o[k]&&!!d.o[k].j])}"))
    for e in errs: print('ERR:', e[:200])
    pg.screenshot(path='/tmp/e2ep_dbg.png')
    b.close()
