# -*- coding: utf-8 -*-
"""CMD-056 — اسکرین‌شات محلی تم سورمه‌ای و نوار مشتریان برای بازبینی چشمی."""
import subprocess
import time
from playwright.sync_api import sync_playwright

PORT = 3217
srv = subprocess.Popen(
    ['node', 'scripts/dev-server.js'],
    env={'PATH': '/usr/local/bin:/usr/bin:/bin', 'PORT': str(PORT),
         'NODE_ENV': 'development', 'APP_SECRET': 'x' * 60},
    cwd='/home/z/my-project/dadgar/web',
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(2)

try:
    with sync_playwright() as p:
        br = p.chromium.launch()
        pg = br.new_page(viewport={'width': 1440, 'height': 900})
        pg.goto(f'http://127.0.0.1:{PORT}/', wait_until='networkidle')
        pg.screenshot(path='/tmp/render/local-navy-hero.png')
        pg.locator('#clients').scroll_into_view_if_needed()
        time.sleep(1.2)
        pg.screenshot(path='/tmp/render/local-navy-clients.png')
        pg.locator('#about').scroll_into_view_if_needed()
        time.sleep(1.2)
        pg.screenshot(path='/tmp/render/local-navy-leaders.png')
        pg.locator('#contact').scroll_into_view_if_needed()
        time.sleep(1.2)
        pg.screenshot(path='/tmp/render/local-navy-contact.png')
        # حالت روز برای مقایسه
        pg.evaluate("localStorage.setItem('dadgar-theme','light')")
        pg.reload(wait_until='networkidle')
        pg.locator('#clients').scroll_into_view_if_needed()
        time.sleep(1.2)
        pg.screenshot(path='/tmp/render/local-light-clients.png')
        # موبایل
        pg.evaluate("localStorage.setItem('dadgar-theme','navy')")
        mg = br.new_page(viewport={'width': 390, 'height': 844})
        mg.goto(f'http://127.0.0.1:{PORT}/', wait_until='networkidle')
        mg.screenshot(path='/tmp/render/local-navy-mobile-hero.png')
        mg.locator('#clients').scroll_into_view_if_needed()
        time.sleep(1.2)
        mg.screenshot(path='/tmp/render/local-navy-mobile-clients.png')
        br.close()
finally:
    srv.terminate()
print('shots done')
