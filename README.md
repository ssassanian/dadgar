# dadgar

dadgar lotfi

> 🌐 **سایت آنلاین است:** https://dadgar-aboalisinacom-7507.vercel.app
> ✅ **REL-001 (v1.0.0):** سایت فاز ۲ آنلاین شد — ورود/نشست/پروفایل واقعی
> ✅ **REL-002 (v1.1.0):** فاز ۳ گام ۱ — چرخه پرونده به دیتابیس وصل شد (۸ صفحه، ۹ API، AES-256-GCM)
> ✅ **REL-003 (v1.2.0):** فاز ۳ گام ۲ — نوبت‌دهی به دیتابیس وصل شد (۳ صفحه، ۳ API، حریم خصوصی وکیل ناشناس)
> ✅ **REL-004 (v1.3.0):** فاز ۳ گام ۳ — ماژول مالی به دیتابیس وصل شد (۲ صفحه، ۴ API، صدور/پرداخت/بازکردن فاکتور)
> ✅ **REL-005 (v1.4.0):** فاز ۳ گام ۴ — ماژول نظرات به دیتابیس وصل شد (۲ پنل + ویترین عمومی، ۵ API، ماسک نام + میزان‌رسی مدیر + تکمیل گذار done چرخه پرونده)
> ✅ **REL-006 (v1.5.0):** فاز ۳ گام ۵ — ماژول پیام/تیکت به دیتابیس وصل شد (۴ صفحه‌ی مشترک، ۸ API، چت پرونده‌محور + AES-256-GCM روی متن تیکت/پیام + اصلاح فیلتر وکیل مالی)
> ✅ **REL-007 (v1.6.0):** فاز ۳ گام ۶ — ماژول اسناد به دیتابیس وصل شد (گاوصندوق مشتری، ۴ API، آپلود باینری ۴ مگابایت + AES-256-GCM روی نام و محتوای فایل + دانلود امن attachment/RFC5987)

---

## 📚 مستندات رسمی پروژه (مرجع نهایی)

این مخزن، **منبع اصلی و مرجع نهایی (Single Source of Truth)** پروژه است. طبق قانون عمومی، تمام فایل‌ها و مستندات همیشه باید در همین‌جا همگام و به‌روز باشند.

### قوانین الزام‌آور

| سند | توضیح |
|---|---|
| [docs/00-CONSTITUTION.md](docs/00-CONSTITUTION.md) | **قانون عمومی پروژه** — ۲۳ ماده الزام‌آور: نحوه تغییر، تفکیک وب/موبایل، فریز، گیت‌هاب، مهندسی کد |
| [docs/01-RELEASE-RULES.md](docs/01-RELEASE-RULES.md) | **قانون خروجی (Release)** — ممیزی پیش از خروجی، مستند خروجی، کلید و امضا، پکیج‌نیم یکتا، تفکیک اندروید/iOS |

### دفاتر رسمی

| سند | توضیح |
|---|---|
| [docs/02-COMMANDS-REGISTER.md](docs/02-COMMANDS-REGISTER.md) | دفتر ثبت و شماره‌گذاری تمام دستورات مدیر (CMD-XXX) |
| [docs/03-ACTIVITY-LOG.md](docs/03-ACTIVITY-LOG.md) | گزارش تمام کارهای انجام‌شده (ACT-XXX) |

### خروجی‌ها (Releases)

| سند | توضیح |
|---|---|
| [docs/releases/REL-001.md](docs/releases/REL-001.md) | خروجی شماره ۱ — آنلاین شدن سایت فاز ۲ روی Vercel+Supabase (تگ v1.0.0) |
| [docs/releases/REL-002.md](docs/releases/REL-002.md) | خروجی شماره ۲ — فاز ۳ گام ۱: چرخه پرونده متصل به دیتابیس (تگ v1.1.0) |
| [docs/releases/REL-003.md](docs/releases/REL-003.md) | خروجی شماره ۳ — فاز ۳ گام ۲: نوبت‌دهی متصل به دیتابیس (تگ v1.2.0) |
| [docs/releases/REL-004.md](docs/releases/REL-004.md) | خروجی شماره ۴ — فاز ۳ گام ۳: ماژول مالی متصل به دیتابیس (تگ v1.3.0) |
| [docs/releases/REL-005.md](docs/releases/REL-005.md) | خروجی شماره ۵ — فاز ۳ گام ۴: ماژول نظرات متصل به دیتابیس (تگ v1.4.0) |
| [docs/releases/REL-006.md](docs/releases/REL-006.md) | خروجی شماره ۶ — فاز ۳ گام ۵: ماژول پیام/تیکت متصل به دیتابیس (تگ v1.5.0) |
| [docs/releases/REL-007.md](docs/releases/REL-007.md) | خروجی شماره ۷ — فاز ۳ گام ۶: ماژول اسناد متصل به دیتابیس (تگ v1.6.0) |
| [docs/releases/keys-register.txt](docs/releases/keys-register.txt) | دفتر کلیدها و امضاها (طبق قانون Release) |

### آرشیو دستورات

| سند | توضیح |
|---|---|
| [docs/commands/CMD-001-2026-10-27-General-Rules.md](docs/commands/CMD-001-2026-10-27-General-Rules.md) | متن کامل دستور شماره ۱ — تصویب قانون عمومی و قانون خروجی + شروع مستندسازی |
| [docs/commands/CMD-002-2026-10-27-Online-Deployment.md](docs/commands/CMD-002-2026-10-27-Online-Deployment.md) | متن کامل دستور شماره ۲ — آنلاین‌سازی سایت فاز ۲ + مهاجرت Vercel+Supabase |
| [docs/commands/CMD-003-2026-10-28-Phase3-Step1-Case-Cycle.md](docs/commands/CMD-003-2026-10-28-Phase3-Step1-Case-Cycle.md) | متن کامل دستور شماره ۳ — فاز ۳ گام ۱: اتصال چرخه پرونده به دیتابیس |
| [docs/commands/CMD-004-2026-10-28-Phase3-Step2-Appointments.md](docs/commands/CMD-004-2026-10-28-Phase3-Step2-Appointments.md) | متن کامل دستور شماره ۴ — فاز ۳ گام ۲: اتصال نوبت‌دهی به دیتابیس |
| [docs/commands/CMD-005-2026-10-28-Phase3-Step3-Billing.md](docs/commands/CMD-005-2026-10-28-Phase3-Step3-Billing.md) | متن کامل دستور شماره ۵ — فاز ۳ گام ۳: اتصال ماژول مالی به دیتابیس |
| [docs/commands/CMD-006-2026-10-28-Phase3-Step4-Reviews.md](docs/commands/CMD-006-2026-10-28-Phase3-Step4-Reviews.md) | متن کامل دستور شماره ۶ — فاز ۳ گام ۴: اتصال ماژول نظرات به دیتابیس |
| [docs/commands/CMD-007-2026-10-28-Phase3-Step5-Messages-Tickets.md](docs/commands/CMD-007-2026-10-28-Phase3-Step5-Messages-Tickets.md) | متن کامل دستور شماره ۷ — فاز ۳ گام ۵: اتصال ماژول پیام/تیکت به دیتابیس |
| [docs/commands/CMD-008-2026-10-28-Phase3-Step6-Documents.md](docs/commands/CMD-008-2026-10-28-Phase3-Step6-Documents.md) | متن کامل دستور شماره ۸ — فاز ۳ گام ۶: اتصال ماژول اسناد به دیتابیس |

---

## 🗂 ساختار مخزن

```
dadgar/
├── README.md                        ← همین فایل
├── dadgar/                          ← نسخه مرجع اصلی سایت (فاز ۱ و ۲ — عیناً از zip دریافتی، بدون تغییر)
│   ├── server.js                    ← بک‌اند امن Node.js (بدون وابستگی بیرونی، SQLite داخلی)
│   ├── public/index.html            ← سایت کامل (SPA)
│   ├── lib/ · scripts/ · test/
│   └── README.md                    ← راهنمای اجرای خود پروژه
├── web/                             ← لایه مهاجرت Vercel+Supabase (v1.0.0 تا v1.6.0) — Root Directory پروژه Vercel
│   ├── api/                         ← ۳ ورودی سرورلس (API / HTML با nonce / 404)
│   ├── lib/                         ← db.pg.js (آداپتور Postgres) + web.js (پورت وفادار + API چرخه پرونده + API نوبت‌دهی + API مالی + API نظرات + API پیام/تیکت + API اسناد) + security/sms/config
│   ├── dynamic/index.html           ← index.html مرجع + صفحات واقعی VR فاز ۳ (تزریق با inject-cycle.py و inject-book.py و inject-bill.py و inject-rev.py و inject-msg.py و inject-docs.py)
│   ├── db/schema.sql                ← اسکیمای Postgres (پورت وفادار SQLite)
│   ├── scripts/                     ← ابزار عملیاتی (create-admin.pg / inject / تست API و e2e / هارنس)
│   └── vercel.json
├── mobile/                          ← اپ نیتیو موبایل Flutter (M0 — مونوریپو طبق CMD-016؛ ایزوله کامل از web/، اتصال فقط REST API — DOC-04 v2.1)
│   ├── lib/ · test/ · assets/fonts/vazirmatn/
│   └── pubspec.yaml                 ← پین Flutter 3.41.0 در CI
├── .github/workflows/
│   └── mobile-ci.yml                ← CI موبایل — فقط مسیر mobile/** (دست‌نخورده روی دیپلوی وب)
└── docs/
    ├── 00-CONSTITUTION.md           ← قانون عمومی (DOC-000)
    ├── 01-RELEASE-RULES.md          ← قانون خروجی (DOC-001)
    ├── 02-COMMANDS-REGISTER.md      ← دفتر دستورات (DOC-002)
    ├── 03-ACTIVITY-LOG.md           ← گزارش فعالیت‌ها (DOC-003)
    ├── 04-MOBILE-NATIVE-SPEC.md     ← سند فنی موبایل (DOC-04 v2.1)
    ├── releases/                    ← ثبت خروجی‌ها (REL-XXX) و دفتر کلیدها
    └── commands/
        ├── CMD-001-...-General-Rules.md
        ├── CMD-002-...-Online-Deployment.md
        └── CMD-003-...-Phase3-Step1-Case-Cycle.md
```

> **مونوریپو (CMD-016 — 2026-10-29):** با تصمیم مدیر («یک ریپو باشه»)، اپ موبایل از مخزن جدا `ssassanian/dadgar-mobile` (بایگانی‌شده) به پوشه‌ی `mobile/` همین مخزن منتقل شد — جدایی دایرکتوری کامل، صفر فایل مشترک با `web/`، و CI فیلترشده بر اساس مسیر. متن کامل: [DOC-04 v2.1](docs/04-MOBILE-NATIVE-SPEC.md).

> **قانون طلایی:** هیچ کاری بدون رعایت [قانون عمومی](docs/00-CONSTITUTION.md) انجام نمی‌شود. پیش از شروع هر کاری، ابتدا مستندات این مخزن بررسی می‌شود.
