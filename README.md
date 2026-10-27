# dadgar

dadgar lotfi

> 🌐 **سایت آنلاین است:** https://dadgar-aboalisinacom-7507.vercel.app
> ✅ **REL-001 (v1.0.0):** سایت فاز ۲ آنلاین شد — ورود/نشست/پروفایل واقعی
> ✅ **REL-002 (v1.1.0):** فاز ۳ گام ۱ — چرخه پرونده به دیتابیس وصل شد (۸ صفحه، ۹ API، AES-256-GCM)
> ✅ **REL-003 (v1.2.0):** فاز ۳ گام ۲ — نوبت‌دهی به دیتابیس وصل شد (۳ صفحه، ۳ API، حریم خصوصی وکیل ناشناس)
> ✅ **REL-004 (v1.3.0):** فاز ۳ گام ۳ — ماژول مالی به دیتابیس وصل شد (۲ صفحه، ۴ API، صدور/پرداخت/بازکردن فاکتور)
> ✅ **REL-005 (v1.4.0):** فاز ۳ گام ۴ — ماژول نظرات به دیتابیس وصل شد (۲ پنل + ویترین عمومی، ۵ API، ماسک نام + میزان‌رسی مدیر + تکمیل گذار done چرخه پرونده)

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
├── web/                             ← لایه مهاجرت Vercel+Supabase (v1.0.0 تا v1.4.0)
│   ├── api/                         ← ۳ ورودی سرورلس (API / HTML با nonce / 404)
│   ├── lib/                         ← db.pg.js (آداپتور Postgres) + web.js (پورت وفادار + API چرخه پرونده + API نوبت‌دهی + API مالی + API نظرات) + security/sms/config
│   ├── dynamic/index.html           ← index.html مرجع + صفحات واقعی VR فاز ۳ (تزریق با inject-cycle.py و inject-book.py و inject-bill.py و inject-rev.py)
│   ├── db/schema.sql                ← اسکیمای Postgres (پورت وفادار SQLite)
│   ├── scripts/                     ← ابزار عملیاتی (create-admin.pg / inject / تست API و e2e / هارنس)
│   └── vercel.json
└── docs/
    ├── 00-CONSTITUTION.md           ← قانون عمومی (DOC-000)
    ├── 01-RELEASE-RULES.md          ← قانون خروجی (DOC-001)
    ├── 02-COMMANDS-REGISTER.md      ← دفتر دستورات (DOC-002)
    ├── 03-ACTIVITY-LOG.md           ← گزارش فعالیت‌ها (DOC-003)
    ├── releases/                    ← ثبت خروجی‌ها (REL-XXX) و دفتر کلیدها
    └── commands/
        ├── CMD-001-...-General-Rules.md
        ├── CMD-002-...-Online-Deployment.md
        └── CMD-003-...-Phase3-Step1-Case-Cycle.md
```

> **قانون طلایی:** هیچ کاری بدون رعایت [قانون عمومی](docs/00-CONSTITUTION.md) انجام نمی‌شود. پیش از شروع هر کاری، ابتدا مستندات این مخزن بررسی می‌شود.
