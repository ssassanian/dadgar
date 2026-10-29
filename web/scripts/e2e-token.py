#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-026 — تست e2e افزوده‌ی اول D-6 (توکن موبایل) روی هارنس محلی + دیتابیس واقعی.
سناریو: ورود وب (رگرسیون trim) ← توکن با رمز غلط ← توکن موفق ← Bearer روی me/appointments/cases/invoices
← نوشتن با Bearer بدون CSRF (PATCH /api/me) ← چرخش refresh (قبلی باطل) ← revoke دستگاه با refresh بدنه
← revoke دستگاه با Bearer بدون بدنه. همه‌ی توکن‌های آزمون در پایان ابطال می‌شوند."""
import requests, sys, time

BASE = 'http://127.0.0.1:3202'
U, P = 'client_t', 'ClientT#2026'
ok_count = 0

def ok(msg):
    global ok_count
    ok_count += 1
    print('✅', msg)

def expect(cond, msg, extra=''):
    if not cond:
        print('❌', msg, extra)
        sys.exit(1)
    ok(msg)

# ---------- 1) سلامت هارنس ----------
r = requests.get(BASE + '/api/health', timeout=10)
expect(r.status_code == 200 and r.json().get('ok'), 'harness healthy')

# ---------- 2) رگرسیون ورود وب (نشست کوکی + trim سازگار kind) ----------
s = requests.Session()
r = s.post(BASE + '/api/auth/login', json={'username': U, 'password': P}, timeout=10)
expect(r.status_code == 200 and r.json().get('user', {}).get('username') == U,
       'web login regression: cookie session works after kind-trim change', r.text[:200])
csrf = r.json().get('csrf', '')

# ---------- 3) توکن با رمز غلط ----------
r = requests.post(BASE + '/api/auth/token', json={'username': U, 'password': 'wrong-pass-123'}, timeout=10)
expect(r.status_code == 401 and r.json().get('error') == 'نام کاربری یا رمز عبور اشتباه است.',
       'token with wrong password → 401 exact server message', r.text[:200])

# ---------- 4) توکن موفق (قرارداد موبایل: access_token/refresh_token) ----------
r = requests.post(BASE + '/api/auth/token', json={'username': U, 'password': P, 'device': 'e2e-test'}, timeout=10)
d = r.json()
expect(r.status_code == 200 and d.get('ok') and d.get('token_type') == 'Bearer'
       and isinstance(d.get('access_token'), str) and len(d['access_token']) >= 40
       and isinstance(d.get('refresh_token'), str) and d.get('expires_in') == 900
       and d.get('user', {}).get('username') == U,
       'token issue: contract matches mobile client (access/refresh/expires_in=900/Bearer)', r.text[:300])
access1, refresh1 = d['access_token'], d['refresh_token']
BH1 = {'Authorization': 'Bearer ' + access1}

# ---------- 5) GET /api/me با Bearer ----------
r = requests.get(BASE + '/api/me', headers=BH1, timeout=10)
expect(r.status_code == 200 and r.json().get('user', {}).get('username') == U,
       'Bearer on /api/me → same account identity', r.text[:200])

# ---------- 6) مسیرهای موجود با Bearer: appointments/cases/invoices ----------
r = requests.get(BASE + '/api/appointments', headers=BH1, timeout=10)
expect(r.status_code == 200 and r.json().get('ok') is not False, 'Bearer on /api/appointments (CMD-004)', r.text[:150])
r = requests.get(BASE + '/api/cases', headers=BH1, timeout=10)
expect(r.status_code == 200 and 'rows' in r.json(), 'Bearer on /api/cases (CMD-003)', r.text[:150])
r = requests.get(BASE + '/api/invoices', headers=BH1, timeout=10)
expect(r.status_code == 200 and 'rows' in r.json(), 'Bearer on /api/invoices (CMD-005)', r.text[:150])

# ---------- 7) نوشتن با Bearer بدون هدر CSRF (گذر از لایه‌ی ۲ — بدون کوکی CSRF بی‌معناست) ----------
name_now = r.json() and requests.get(BASE + '/api/me', headers=BH1, timeout=10).json()['user']['name']
r = requests.patch(BASE + '/api/me', headers=BH1, json={'name': name_now}, timeout=10)
expect(r.status_code == 200 and r.json().get('ok'), 'write with Bearer without x-csrf-token → passes (CSRF layer is cookie-scoped)', r.text[:150])

# ---------- 8) چرخش refresh: قبلی و access وابسته باطل ----------
time.sleep(1.1)  # created_at برحسب ثانیه — برای ترتیب قطعی
r = requests.post(BASE + '/api/auth/token/refresh', json={'refresh_token': refresh1}, timeout=10)
d2 = r.json()
expect(r.status_code == 200 and d2.get('access_token') and d2.get('refresh_token')
       and d2['refresh_token'] != refresh1 and d2['access_token'] != access1,
       'refresh rotation: new pair issued', r.text[:200])
access2, refresh2 = d2['access_token'], d2['refresh_token']
r = requests.get(BASE + '/api/appointments', headers={'Authorization': 'Bearer ' + access1}, timeout=10)
expect(r.status_code == 401 and r.json().get('error') == 'ابتدا وارد شوید.',
       'old access revoked after rotation → 401 on auth route (/api/me by design always 200)', r.text[:150])
r = requests.post(BASE + '/api/auth/token/refresh', json={'refresh_token': refresh1}, timeout=10)
expect(r.status_code == 401, 'old refresh unusable after rotation → 401')

# ---------- 9) revoke دستگاه با refresh بدنه (عین کلاینت موبایل هنگام خروج) ----------
r = requests.post(BASE + '/api/auth/token/revoke', json={'refresh_token': refresh2, 'scope': 'device'}, timeout=10)
expect(r.status_code == 200 and r.json().get('ok'), 'revoke device via body refresh_token', r.text[:150])
r = requests.get(BASE + '/api/appointments', headers={'Authorization': 'Bearer ' + access2}, timeout=10)
expect(r.status_code == 401, 'access dead after device revoke → 401 on auth route')
r = requests.post(BASE + '/api/auth/token/refresh', json={'refresh_token': refresh2}, timeout=10)
expect(r.status_code == 401, 'refresh dead after device revoke → 401')

# ---------- 10) revoke دستگاه با Bearer بدون بدنه ----------
r = requests.post(BASE + '/api/auth/token', json={'username': U, 'password': P}, timeout=10)
d3 = r.json()
expect(r.status_code == 200, 'fresh token pair for bearer-revoke test')
r = requests.post(BASE + '/api/auth/token/revoke', json={}, headers={'Authorization': 'Bearer ' + d3['access_token']}, timeout=10)
expect(r.status_code == 200 and r.json().get('ok'), 'revoke device via Bearer only (no body)', r.text[:150])
r = requests.get(BASE + '/api/appointments', headers={'Authorization': 'Bearer ' + d3['access_token']}, timeout=10)
expect(r.status_code == 401, 'access dead after bearer revoke → 401 on auth route')

# ---------- 11) نشست وب دست‌نخورده + /api/me مهمان با توکن مرده همیشه 200 (طراحی موجود) ----------
r = s.get(BASE + '/api/me', timeout=10)
expect(r.status_code == 200 and r.json().get('user', {}).get('username') == U,
       'web cookie session untouched by all token operations')
r = requests.get(BASE + '/api/me', headers={'Authorization': 'Bearer dead-token-value-000'}, timeout=10)
expect(r.status_code == 200 and r.json().get('user') is None,
       'invalid Bearer on /api/me → guest 200 {user:null} (identical to invalid cookie)')

print('== e2e-token finished: %d checks passed ==' % ok_count)
