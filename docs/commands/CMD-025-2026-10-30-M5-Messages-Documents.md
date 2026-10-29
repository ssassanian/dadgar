# CMD-025 — «ادامه» → گام چهارم (پایانی) بسته‌ی M2..M5: پیام/تیکت + اسناد (M5)

| مشخصه | مقدار |
|---|---|
| شماره دستور | CMD-025 |
| تاریخ صدور | 2026-10-30 |
| صادرکننده | مدیر پروژه (ssassanian) — پیام «ادامه» |
| وضعیت | **اجرا شد — بسته‌ی M2..M5 کامل؛ فاز محلی بسته؛ اتصال زنده منوط به D-6** |
| مبنای بسته | CMD-021 (بسته‌ی M2..M5) — گام‌های پیشین: M3 (CMD-021)، M2 (CMD-023)، M4 (CMD-024)؛ این سند گام پایانی است |
| خوانش دستور | همان الگوی تفسیر ثبت‌شده‌ی CMD-017/019/023/024 — «ادامه» = ادامه‌ی توالی مصوب بسته |
| تعریف M5 | DOC-04 §۱۱ ردیف M5: «پیام/تیکت + اسناد (آپلود دوربین + دانلود) — تیکت کامل + دانلود بایت‌به‌بایت» |
| قانون جدایی | صفر تغییر در `web/`؛ فقط افزودن به `mobile/` (S-1/S-4/S-5) |

---

## متن دستور (رونوشت عینی)

> مدیر: **«ادامه»**

## محدوده‌ی اجرا — دو فیچر، هفت مسیر موجود سرور

**۱) تیکت پشتیبانی (CMD-007)** — چرخه‌ی کامل مشتری:

| مسیر سرور | موبایل |
|---|---|
| `GET /api/tickets` (سقف ۲۰۰) | فهرست کارت: موضوع/بخش/وضعیت/شمار پیام/تاریخ شمسی |
| `POST /api/tickets` (۴۲۹ = سقف ۵/ساعت) | فرم چهارتایی: subject ۳..۱۲۰، بخش پنج‌گانه، اولویت سه‌گانه، متن ۳..۳۰۰۰ — اعتبارسنجی آینه‌ای |
| `GET /api/tickets/:id` (۴۰۴ ضدافشا) | گفتگو با حباب «من/طرف» بر پایه‌ی `mine` سرور |
| `POST /api/tickets/:id/replies` | پاسخ ۱..۳۰۰۰؛ تیکت بسته با پیام عین سرور قفل؛ پس از پاسخ، بازخوانی با وضعیت بازگشتی سرور (answered/open) |
| `PATCH /api/tickets/:id` (مدیر) | **در موبایل پیاده نشد** — نقش مدیر در پنل وب می‌ماند |

**۲) چت پرونده (CMD-007)**: `GET /api/threads` (فهرست پرونده‌های تخصیص‌یافته با گزیده‌ی ۸۰نویسه‌ای آخرین پیام) + `GET /api/messages?case_id` (سقف ۳۰۰) + `POST /api/messages` (۱..۲۰۰۰؛ ۴۰۰ «گفتگو فعال نیست» عین سرور). سربرگ پرونده از پاسخ سرور.

**۳) اسناد (CMD-008)**: `GET /api/documents` (سقف ۳۰۰؛ چیپ «اشتراک با وکیل/محرمانه» = استنتاج سرور) + `POST /api/cases/:id/documents` (آپلود بدنه‌ی خام + هدر `x-file-name` URL-encoded + سقف ۴MB سمت کاربر؛ ۴۲۹ = ۲۰/ساعت) + `GET /api/documents/:id/file` (دانلود بایت‌به‌بایت با `ResponseType.bytes`، ذخیره در پوشه‌ی اسناد اپ) + `DELETE /api/documents/:id` (فقط `mine` سرور، با تایید).

## تصمیم طراحی ثبت‌شده: دو وابستگی first-party جدید (flutter.dev)

`image_picker: ^1.1.2` (آپلود دوربین/گالری — عین DOC-04 «آپلود دوربین») و `path_provider: ^2.1.4` (ذخیره‌ی دانلود). هر دو افزونه‌ی رسمی فلاتر هستند و فقط در لایه‌ی presentation/پل IO لمس می‌شوند: انتخابگر `docPickerProvider` و ذخیره‌ساز `docSaverProvider` تزریق‌شدنی‌اند و در تست‌ها override می‌شوند (DOC-04 §۹) — هیچ مسیر پلتفرمی در چرخه‌ی آزمون اجرا نمی‌شود. مرز آپلود = تصویر مدرک (دوربین/گالری)؛ بارگذاری PDF/آفیس از موبایل به‌عنوان تصمیم باز در انتهای سند ثبت شده است.

## کشف معماری ثبت‌شده: الگوی family-Notifier در Riverpod 3.3

C کشف CMD-023 (حذف `FamilyNotifier`) تکمیل شد: برای کنترلرهای خانوادگیِ **داردارِ حالت** (پاسخ تیکت/ارسال پیام)، الگوی رسمی 3.3 = کلاس `Notifier` با **سازنده‌ی آرگومان‌دار** (`TicketDetailController(this.arg)`) + `NotifierProvider.family<N, S, A>(N.new)` — `build()` بدون ورودی و آرگومان فیلد خود کلاس است (بررسی مستقیم سورس riverpod-3.3.2: `NotifierProviderFamilyBuilder.call` — `NotifierT Function(ArgT arg)`).

## فایل‌ها: ۱۹ جدید + ۸ به‌روزشده

**فیچر `messages/`** (۱۱ فایل): `data/messages_contract.dart` (TK_DEPTS/TK_PRIS/TK_ST، سقف‌ها، پیام‌های عین سرور)، `domain/ticket_models.dart`، `domain/chat_models.dart`، `data/messages_repository.dart` (هفت مسیر)، `application/tickets_controller.dart` (سه کنترلر)، `application/chat_controller.dart` (دو کنترلر)، پنج صفحه: tickets/new_ticket/ticket_detail (حباب+پاسخ)/threads/chat (حباب+ارسال).

**فیچر `documents/`** (۸ فایل): `data/documents_contract.dart` (DOC_MAX، formatSize فارسی)، `domain/document_models.dart` (+`PickedDoc`)، `data/documents_repository.dart` (چهار عملیات)، `data/documents_io.dart` (پل path_provider — جداست)، `application/documents_controller.dart` (+docSaverProvider)، `presentation/documents_picker.dart` (پل image_picker)، `presentation/documents_screen.dart`، `presentation/upload_doc_screen.dart` (انتخاب پرونده → دوربین/گالری → پیش‌نمایش → ارسال).

**اتصال‌ها**: `api_client.dart` (چهار ثابت: tickets/threads/messages/documents؛ آپلود از `cases` ساخته می‌شود)، `providers.dart` (دو مخزن)، `router.dart` (هشت مسیر جدید + چهارmatcher ضدتزریق: تیکت/چت/بارگذاری)، `home_screen.dart` (سه کارت: تیکت‌ها/گفتگو/اسناد + بنر M5)، `case_detail_screen.dart` (دکمه‌ی بارگذاری سند در AppBar)، `pubspec.yaml` (دو وابستگی + نسخه **0.3.0+3**).

## کیفیت (گیت دوگانه)

- `flutter analyze --fatal-infos` → **No issues found**
- `flutter test` → **۱۴۰/۱۴۰ سبز** (۹۸ قبلی + ۴۲ جدید: قرارداد ۹، مخزن پیام ۸، کنترلرها ۸، مخزن اسناد ۹، کنترلر اسناد ۵، ویجت ۶ + فیک‌های `FakeMessagesRepository`/`FakeDocumentsRepository`)
- سیکل رفع اشکال ثبت‌شده: سه provider جامانده (undefined)؛ `_pump` بی‌await؛ تفکیک GET/POST هم‌مسیر در فیک آداپتور؛ انتظار ارقام لاتین/فارسی در نام فایل؛ **تایمر معلق Riverpod 3** (autoDispose در unmount تایمر dispose زمان‌بندی می‌کند که fake_async را می‌شکند → تبدیل `FutureProvider.autoDispose` به `FutureProvider` ساده — کشف قابل‌استفاده‌ی آینده)

## محدوده‌های باقی‌مانده (ثبت برای مدیر — انجام نشده)

1. **بارگذاری PDF/Office از موبایل**: مرز فعلی = تصویر مدرک (دوربین/گالری)؛ انتخابگر فایل عمومی نیازمند افزونه‌ی سوم (file_picker) یا انبار شیء — تصمیم با مدیر (پیوند با تصمیم باز CMD-008: انبار شیء برای >۴MB)
2. **پیوست سند در چت/تیکت**: تصمیم باز REL-006
3. **پنل مدیریتی موبایل**: PATCH تیکت/صدور فاکتور/بازکردن — اگر مطلوب است، دستور جدید لازم است

## وضعیت بسته‌ی M2..M5

| گام | ماژول | سند | وضعیت |
|---|---|---|---|
| ۱ | M3 نوبت‌دهی | CMD-021 | ✅ |
| ۲ | M2 پرونده‌ها | CMD-023 | ✅ |
| ۳ | M4 مالی | CMD-024 | ✅ |
| ۴ | M5 پیام/تیکت + اسناد | CMD-025 | ✅ (این سند) |

فاز محلی هر چهار ماژول بسته است؛ اتصال زنده‌ی همه‌ی ماژول‌ها منوط به حکم مدیر بر **D-6** (سه مسیر توکن سمت سرور) است — کد موبایل از همین حالا آماده است.
