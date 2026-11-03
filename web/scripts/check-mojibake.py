#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CMD-049 — نگهبان انسداد متن: کشف برگشت خرابی UTF-8 (U+FFFD) و هم‌نگاره‌های عربی در درخت زنده.

پیش‌زمینه: در CMD-049 خرابی انباشته‌ی ۷۱ کاراکتر U+FFFD در web/dynamic/index.html
(۳۵ نقطه) و ۶ کاراکتر در docs/03-ACTIVITY-LOG.md کشف و از تاریخچه‌ی گیت ترمیم شد.
این گیت مطمئن می‌شود چنین خرابی‌ای دیگر به مخزن راه نیابد:
۱) کاراکتر جایگزین U+FFFD (نشانه‌ی بایت‌های UTF-8 معیوب) در هر فایل زنده؛
۲) دو هم‌نگاره‌ی عربی (U+064A و U+0643) به‌جای معادل فارسی (U+06CC و U+06A9).

اجرا:  python3 web/scripts/check-mojibake.py   →  خروج ۰ = سبز، ۱ = قرمز
"""
import os, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXCLUDE_DIRS = {'.git', 'node_modules', 'backups', '.dart_tool', 'build', '.vercel', '.idea'}
EXAMINE_EXT = {'.html', '.js', '.css', '.dart', '.md', '.json', '.yml', '.yaml', '.sh', '.py', '.txt', '.sq'}

bad_fffd, bad_homoglyph = [], []
nfiles = 0
for root, dirs, files in os.walk(REPO):
    dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith('.')]
    for fn in files:
        if os.path.splitext(fn)[1].lower() not in EXAMINE_EXT:
            continue
        p = os.path.join(root, fn)
        try:
            with open(p, encoding='utf-8') as f:
                txt = f.read()
        except (UnicodeDecodeError, OSError):
            continue
        nfiles += 1
        n = txt.count('\ufffd')
        if n:
            bad_fffd.append((os.path.relpath(p, REPO), n))
        y, k = txt.count('\u064a'), txt.count('\u0643')  # ی/ک عربی به‌جای فارسی (U+064A/U+0643)
        if y or k:
            bad_homoglyph.append((os.path.relpath(p, REPO),
                                  f'U+064A×{y} U+0643×{k}'))

print(f"نگهبان متن: {nfiles} فایل زنده واریزی شد")
if bad_fffd:
    print("قرمز — کاراکتر خراب U+FFFD:")
    for p, n in bad_fffd: print(f"  {p}: ×{n}")
if bad_homoglyph:
    print("قرمز — هم‌نگاره‌ی عربی به‌جای فارسی:")
    for p, w in bad_homoglyph: print(f"  {p}: {w}")
if not bad_fffd and not bad_homoglyph:
    print("سبز — صفر کاراکتر خراب و صفر هم‌نگاره‌ی عربی در درخت زنده")
    sys.exit(0)
sys.exit(1)
