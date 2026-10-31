/// آینه‌ی قرارداد اسناد سمت سرور — CMD-008 فاز ۳ گام ۶ در `web/lib/web.js`
///
/// S-4: موبایل فقط همین قرارداد موجود را مصرف می‌کند؛ هیچ مسیر/شکل جدیدی
/// تعریف نمی‌شود و سرور با این ماژول صفر تغییر می‌کند.
///
/// ثابت‌های سرور (عیناً از web.js):
///   DOC_LIMIT = 300 — سقف ردیف‌های فهرست (بدون صفحه‌بندی)
///   DOC_MAX = 4MB — سقف بارگذاری (زیر سقف بدنه‌ی سرورلس Vercel)
///   آپلود = بدنه‌ی خام + هدر x-file-name (URL-encoded) + content-type
///   نام فایل ≤ ۲۰۰ نویسه؛ خالی 400؛ ۴۰۴ ضدافشا برای پرونده/سند غیر خودی
///   «سطح دسترسی» = استنتاج عضویت پرونده: دارای وکیل «اشتراک با وکیل»،
///   بی‌وکیل «محرمانه» — همان shared سرور در فهرست.
library;

abstract final class DocumentsContract {
  /// سقف ردیف‌های فهرست — `DOC_LIMIT` سرور
  static const int docLimit = 300;

  /// سقف بارگذاری — `DOC_MAX` سرور (۴ مگابایت)
  static const int docMaxBytes = 4 * 1024 * 1024;

  /// سقف نام فایل — سرور slice(0,200)
  static const int nameMax = 200;

  /// خطاهای سرور — عیناً
  static const String caseNotFound = 'پرونده یافت نشد.';
  static const String docNotFound = 'سند یافت نشد.';
  static const String emptyFile = 'فایل سند خالی است.';
  static const String uploadRateLimit =
      'سقف بارگذاری سند در یک ساعت تکمیل شده است. بعداً تلاش کنید.';

  /// برچسب سطح دسترسی — استنتاج سرور
  static const String sharedLabel = 'اشتراک با وکیل';
  static const String privateLabel = 'محرمانه';

  /// قالب اندازه‌ی فایل — ارقام فارسی با واحد انسانی
  static String formatSize(int bytes) {
    final fa = toPersianDigits;
    if (bytes < 1024) return '${fa(bytes)} بایت';
    if (bytes < 1024 * 1024) {
      return '${fa((bytes / 1024).round())} کیلوبایت';
    }
    final mb = bytes / (1024 * 1024);
    final text = mb >= 10 ? mb.round().toString() : mb.toStringAsFixed(1);
    return '${fa(text)} مگابایت';
  }

  /// ارقام فارسی — هم‌سان با تقویم مشترک M3
  static String toPersianDigits(Object value) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var s = value.toString();
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(en[i], String.fromCharCode(0x06F0 + i));
    }
    return s;
  }
}
