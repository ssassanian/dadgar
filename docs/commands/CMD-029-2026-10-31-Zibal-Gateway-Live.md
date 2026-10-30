# CMD-029 — انتخاب مدیر: «Zibal» → اتصال کامل درگاه پرداخت آنلاین (verify سمت سرور + callback)

| مشخصه | مقدار |
|---|---|
| شماره دستور | CMD-029 |
| تاریخ صدور | 2026-10-31 |
| صادرکننده | مدیر پروژه (ssassanian) — پیام «Zibal» (انتخاب از منوی پیشنهادیِ پس از ACT-070) |
| وضعیت | **اجرا شد — درگاه کامل متصل شد؛ e2e سبز؛ استقرار + env تولید انجام شد** |
| مبنای دستور | بسته‌ی C در CMD-028 (اسکلت بی‌طرف درگاه) که انتخاب provider را به دستور بعدی موکول کرده بود |
| حکم ضمنی | گزینه‌ی ارائه‌شده عیناً «زیبال — تست چرخه‌ی کامل پرداخت بدون نیاز به ثبت‌نام» بود؛ یعنی پیاده‌سازی ماژول + verify سمت سرور + callback + همگام‌سازی env ورسل — همه در همین CMD انجام شد |
| لمس web/ | ادامه‌ی همان حکم صریح لمس وب CMD-028 (فقط مسیرهای پرداخت) — بقیه‌ی web/ دست نخورد |

---

## متن دستور (رونوشت عینی)

> مدیر: **«Zibal»**

## مرجع فنی (مستند رسمی زیبال — help.zibal.ir/ipg + مدل OpenAPI رسمی)

| موضوع | مقدار مستند |
|---|---|
| ساخت درخواست | `POST https://gateway.zibal.ir/v1/request` — `{merchant, amount(ریال), callbackUrl, orderId?, description?}` → `{trackId, result, message}` |
| صفحه پرداخت | `https://gateway.zibal.ir/start/{trackId}` (ریدایرکت مرورگر کاربر) |
| تایید | `POST https://gateway.zibal.ir/v1/verify` — `{merchant, trackId}` → `{result, status, amount(ریال), refNumber?, cardNumber?, paidAt?}` |
| قاعده‌ی ۱ امنیتی | پاسخ درگاه **همیشه HTTP 200** است؛ فقط «result» ملاک است (۱۰۰=موفق / ۱۰۴=merchant نامعتبر / …) |
| قاعده‌ی ۲ | `success=1` در callback فقط راهنمای کاربر است؛ تایید نهایی فقط verify سمت سرور |
| result های verify | **100** = پرداخت‌شده (تایید اول) / **201** = قبلا تاییدشده (تکرار — تحویل دوباره ممنوع) / **202** = پرداخت نشده |
| قاعده‌ی ۳ | مبلغ پاسخ verify باید با مبلغ ثبت‌شده یکی باشد — مغایرت = تحویل ممنوع |
| درگاه آزمایشی | merchant = رشته‌ی `zibal` — بدون ثبت‌نام، بدون پول واقعی (همان که مدیر انتخاب کرد) |
| واحد پول | زیبال «ریال» — سامانه «تومان» (لیبل UI و نمونه‌های مرجع) → ضریب ۱۰ فقط در مرز درگاه |

## پیاده‌سازی (کامیت `44af3a8`)

| فایل | محتوا |
|---|---|
| `web/lib/pay.zibal.js` جدید | ماژول درگاه با رابط بی‌طرف (`createRequest`/`verify`/`startUrl`) — خطاها بدون HTTP: `e.payGateway` (شبکه/JSON) و `e.payResult` (رد درگاه)؛ نگاشت به HttpError در web.js؛ `PAYMENT_API_BASE` فقط هارنس محلی |
| `web/lib/web.js` | **request**: اعتبارسنجی‌های قبلی حفظ (404 ضدافشا / 400 پرداخت‌شده / 503 صادقانه بدون provider / 403 وکیل) + provider≠zibal→503 + پیکربندی ناقص→503 + ساخت درخواست نزد زیبال + INSERT `payment_requests` + audit `payment_request` → `{ok, pay_url, track_id}` (قرارداد موبایل CMD-028 عیناً حفظ شد — صفر تغییر موبایل) — **callback**: 404 ضدافشا برای trackId ناشناخته + همیشه verify سمت سرور + 202→صفحه ناموفق + ردیف failed + گارد مغایرت مبلغ (mismatch + audit) + 100/201 → تایید **اتمیک-ایدمپوتنت** (`tx`: invoices→paid + payment_requests→paid؛ `u1.count>0` یعنی تحویل واقعی) + audit `payment_paid` فقط یک‌بار + **صفحه‌ی نتیجه HTML فارسی** (بدون منبع خارجی — CSP-سازگار؛ مبلغ/شماره مرجع/کارت ماسک) |
| `web/db/schema.sql` + `db/api-pending-ddl.sql` | جدول `payment_requests` (id, invoice_id CASCADE, client_id, gateway, track_id UNIQUE, amount_rial, status pending→paid\|failed\|mismatch, ref_number, card_number, created_at, paid_at) — **DDL با Management API اعمال شد (REL-011)** و جدول از پولر در دسترس و سبز شد؛ DISABLE RLS مطابق پیش‌نمونه CMD-010 |
| `web/lib/db.pg.js` | NUM_COLS += `invoice_id, track_id, amount_rial` (BIGINT→Number مثل بقیه) |
| `web/scripts/fake-zibal.js` جدید | درگاه تقلبی عین مستند (HTTP همیشه 200؛ result-only) با کنترل قطعی `?mode=ok\|already\|fail\|mismatch` |
| `web/scripts/test-bill.sh` | بخش **۱۲ج** — ری‌استارت سرور با provider=زیبال + ۹ آزمون چرخه‌ی کامل (100/201/202/مغایرت/تکرار/404/401/403) |
| `web/scripts/cleanup-bill.js` | پاکسازی `payment_requests` (با گارد 42P01 — سازگار با DDL اعمال‌نشده) + auditهای `payment%` |

## راستی‌آزمایی

- **e2e کامل سبز**: `ALL API BILL TESTS PASSED` — ۱۵ بخش صفر رگرسیون + ۱۲ج کامل (درگاه تقلبی عین مستند): ساخت پرداخت → ردیف pending با amount_rial=تومان×۱۰ → fail (success=1 نادیده شد) → ok → paid + paid_at → تکرار ایدمپوتنت (paid_at بدون تغییر، audit تکراری نشد) → مغایرت مبلغ (تحویل ممنوع + audit) → result=201 با ردیف pending (تکمیل جریان قطع‌شده، تحویل فقط یک‌بار) → cleanup کامل با صفر مانده
- **کشف ۱ — نهمین ریست محیط (میان‌جلسه)**: `.secrets/` و secretهای بازیابی‌شده و node_modules از دست رفت؛ مخزن‌ها سالم (هر دو در HEAD درست)؛ بازیابی کامل با اسکریپت‌های نسخه‌پذیر ACT-070 در <۲ دقیقه (`vercel-env-recover.py` ۲/۲ + اتصال پولر سبز) — اثبات عملی راهبرد نسخه‌پذیری
- **کشف ۲ — خروجی سندباکس به زیبال مسدود است**: TCP connect timeout به بازه‌ی IP زیبال/آروان (۱۸۵.۱۴۳.x) درحالی‌که GitHub/Vercel/Supabase بازند → دود آزمایش زنده از سندباکس غیرممکن؛ e2e قطعی با درگاه تقلبی انجام شد و صحت اتصال واقعی به تست تولید موکول شد (همان کد، همان مسیر — فقط host تفاوت دارد)
- **Mobile CI** پس از push سبز (صفر تغییر موبایل)

## استقرار و env تولید

- سه env روی پروژه‌ی `dadgar` تنظیم شد (اسکریپت نسخه‌پذیر `cmd029-set-env.py`): `PAYMENT_PROVIDER=zibal` / `PAYMENT_MERCHANT_ID=zibal` (درگاه آزمایشی مستند — بدون پول واقعی) / `PAYMENT_CALLBACK_BASE=https://dadgar-theta.vercel.app` — `PAYMENT_API_BASE` عمداً تنظیم نمی‌شود (فقط هارنس)
- دیپلوی: کامیت کد `44af3a8` + کامیت دفاتر همین سند → دو بیلد git؛ پس از READY دوم، دود تولید: login کاربر آزمایشی → فاکتور → `payments/request` → trackId **واقعی** زیبال → callback تولید → verify واقعی 202 (پرداخت‌نشده) → صفحه‌ی ناموفق → cleanup کامل

## پس از این دستور

- درگاه در حالت **آزمایشی** فعال است (merchant=`zibal` — پول واقعی جابه‌جا نمی‌شود). برای پذیرش واقعی، مدیر باید در پنل زیبال ثبت‌نام کند و `PAYMENT_MERCHANT_ID` را در ورسل با merchant واقعی عوض کند — بدون هیچ تغییر کد
- گام مرورگر کامل (کلیک «پرداخت موفق» در صفحه‌ی شبیه‌ساز زیبال) از سندباکس مسدود است؛ مسیر callback/verify همان مسیر آزمون‌شده است
