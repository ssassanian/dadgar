# dadgar

dadgar lotfi

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
├── dadgar/                          ← سایت موسسه حقوقی دادگر (فاز ۱ و ۲ — عیناً از zip دریافتی، بدون تغییر)
│   ├── server.js                    ← بک‌اند امن Node.js (بدون وابستگی بیرونی، SQLite داخلی)
│   ├── public/index.html            ← سایت کامل (SPA)
│   ├── lib/ · scripts/ · test/
│   └── README.md                    ← راهنمای اجرای خود پروژه
└── docs/
    ├── 00-CONSTITUTION.md           ← قانون عمومی (DOC-000)
    ├── 01-RELEASE-RULES.md          ← قانون خروجی (DOC-001)
    ├── 02-COMMANDS-REGISTER.md      ← دفتر دستورات (DOC-002)
    ├── 03-ACTIVITY-LOG.md           ← گزارش فعالیت‌ها (DOC-003)
    └── commands/
        ├── CMD-001-...-General-Rules.md
        └── CMD-002-...-Online-Deployment.md
```

> **قانون طلایی:** هیچ کاری بدون رعایت [قانون عمومی](docs/00-CONSTITUTION.md) انجام نمی‌شود. پیش از شروع هر کاری، ابتدا مستندات این مخزن بررسی می‌شود.
