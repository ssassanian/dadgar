# dadgar

dadgar lotfi

> 🌐 **سایت آنلاین است (خروجی REL-001):** https://dadgar-aboalisinacom-7507.vercel.app

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
| [docs/releases/keys-register.txt](docs/releases/keys-register.txt) | دفتر کلیدها و امضاها (طبق قانون Release) |

### آرشیو دستورات

| سند | توضیح |
|---|---|
| [docs/commands/CMD-001-2026-10-27-General-Rules.md](docs/commands/CMD-001-2026-10-27-General-Rules.md) | متن کامل دستور شماره ۱ — تصویب قانون عمومی و قانون خروجی + شروع مستندسازی |
| [docs/commands/CMD-002-2026-10-27-Online-Deployment.md](docs/commands/CMD-002-2026-10-27-Online-Deployment.md) | متن کامل دستور شماره ۲ — آنلاین‌سازی سایت فاز ۲ (متوقف — در انتظار تصمیم مدیر) |

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
├── web/                             ← لایه مهاجرت Vercel+Supabase (خروجی REL-001 — تگ v1.0.0)
│   ├── api/                         ← ۳ ورودی سرورلس (API / HTML با nonce / 404)
│   ├── lib/                         ← db.pg.js (آداپتور Postgres) + web.js (پورت وفادار) + security/sms/config (کپی مستقیم)
│   ├── dynamic/index.html           ← همان index.html مرجع (با CSP nonce سرو می‌شود)
│   ├── db/schema.sql                ← اسکیمای Postgres (پورت وفادار SQLite)
│   ├── scripts/                     ← ابزار عملیاتی (create-admin.pg / هارنس تست)
│   └── vercel.json
└── docs/
    ├── 00-CONSTITUTION.md           ← قانون عمومی (DOC-000)
    ├── 01-RELEASE-RULES.md          ← قانون خروجی (DOC-001)
    ├── 02-COMMANDS-REGISTER.md      ← دفتر دستورات (DOC-002)
    ├── 03-ACTIVITY-LOG.md           ← گزارش فعالیت‌ها (DOC-003)
    ├── releases/                    ← ثبت خروجی‌ها (REL-XXX) و دفتر کلیدها
    └── commands/
        ├── CMD-001-...-General-Rules.md
        └── CMD-002-...-Online-Deployment.md
```

> **قانون طلایی:** هیچ کاری بدون رعایت [قانون عمومی](docs/00-CONSTITUTION.md) انجام نمی‌شود. پیش از شروع هر کاری، ابتدا مستندات این مخزن بررسی می‌شود.
