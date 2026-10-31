/// آینه‌ی قرارداد پرونده‌ها سمت سرور — CMD-003 فاز ۳ گام ۱ در `web/lib/web.js`
///
/// S-4: موبایل فقط همین قرارداد موجود را مصرف می‌کند؛ هیچ مسیر/شکل جدیدی
/// تعریف نمی‌شود و سرور با این ماژول صفر تغییر می‌کند.
///
/// ثابت‌های سرور (عیناً از web.js):
///   CASES_PER = 10 — اندازه‌ی صفحه
///   EXCERPT_LEN = 160 — طول خلاصه‌ی توضیحات برای نقش‌های غیر مالک
///   CATS = شش دسته‌ی ثابت
///   وضعیت‌ها: waiting → proposing → assigned → running → done
///   POST: title ۵..۱۲۰ ، description ۰..۵۰۰۰ ، سقف ۵ پرونده در ساعت (429)
///   page پارامتر: ۱..۵۰۰
library;

abstract final class CasesContract {
  /// اندازه‌ی صفحه‌ی فهرست — `CASES_PER` سرور
  static const int casesPer = 10;

  /// طول خلاصه‌ی توضیحات — `EXCERPT_LEN` سرور
  static const int excerptLen = 160;

  /// بیشینه‌ی شماره‌ی صفحه‌ی مجاز سرور
  static const int maxPage = 500;

  /// شش دسته‌ی ثابت — `CATS` سرور؛ ترتیب هم‌سان
  static const List<String> cats = [
    'ملکی',
    'خانواده',
    'کیفری',
    'شرکت‌ها',
    'ارث و وصیت',
    'قرارداد',
  ];

  /// برچسب فارسی وضعیت‌ها — همان نقشه‌ی ST رابط وب:
  /// {waiting:'در انتظار بررسی', proposing:'در حال پیشنهاد',
  ///  assigned:'تخصیص‌یافته', running:'در حال انجام', done:'بسته‌شده'}
  static const Map<String, String> statusLabels = {
    'waiting': 'در انتظار بررسی',
    'proposing': 'در حال پیشنهاد',
    'assigned': 'تخصیص‌یافته',
    'running': 'در حال انجام',
    'done': 'بسته‌شده',
  };

  /// برچسب فارسی وضعیت — ناشناخته = مقدار خام (مثل سرور)
  static String labelOfStatus(String status) =>
      statusLabels[status] ?? status;

  /// محدوده‌های اعتبارسنجی POST — `str(c.body.title, 5, 120, 'عنوان پرونده')`
  static const int titleMin = 5;
  static const int titleMax = 120;

  /// `description` اختیاری — `str(..., 0, 5000, 'توضیحات')`
  static const int descriptionMax = 5000;

  /// خطای سرور برای ۴۰۴ ضدافشا — عیناً
  static const String notFoundMessage = 'پرونده یافت نشد.';

  /// خطای سرور برای ۴۲۹ سقف نرخ — عیناً
  static const String rateLimitMessage =
      'سقف ثبت پرونده در یک ساعت تکمیل شده است. بعداً تلاش کنید.';

  /// ─── M6 (CMD-028) — پیام‌های عین سرور برای اقدامات مدیر ───
  /// PATCH /api/cases/:id (گذار رو به جلو assigned→running→done؛ done پایانی)
  static const String caseDoneLockedMessage =
      'این پرونده بسته شده است و قابل تغییر نیست.';
  static const String caseNoLawyerYetMessage =
      'پرونده هنوز وکیل تخصیص‌یافته ندارد.';
  static const String caseSameStatusMessage = 'پرونده در همین وضعیت است.';
  /// POST /api/proposals/:id/accept (اتمیک: تایید یکی، رد بقیه، تخصیص وکیل)
  static const String proposalNotFoundMessage = 'پیشنهاد یافت نشد.';
  static const String proposalAlreadyDecidedMessage =
      'این پیشنهاد قبلاً تعیین تکلیف شده است.';
  static const String caseNotInProposalStageMessage =
      'این پرونده دیگر در مرحله‌ی پیشنهاد نیست.';

  /// اعتبارسنجی سمت کاربر — آینه‌ی قواعد سرور برای جلوگیری از POST بی‌فایده.
  /// خطا = پیام فارسی؛ درست = null
  static String? validateTitle(String value) {
    final t = value.trim();
    if (t.length < titleMin) {
      return 'عنوان پرونده باید حداقل $titleMin نویسه باشد';
    }
    if (t.length > titleMax) {
      return 'عنوان پرونده حداکثر $titleMax نویسه است';
    }
    return null;
  }

  static String? validateDescription(String value) {
    if (value.length > descriptionMax) {
      return 'توضیحات حداکثر $descriptionMax نویسه است';
    }
    return null;
  }
}
