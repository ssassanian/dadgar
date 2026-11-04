/// آینه‌ی قرارداد مالی سمت سرور — CMD-005 فاز ۳ گام ۳ در `web/lib/web.js`
/// + M6 (CMD-028): پنل مدیریتی مالی موبایل + درخواست پرداخت (اسکلت بی‌طرف)
///
/// S-4: موبایل فقط همین قرارداد موجود را مصرف می‌کند؛ مسیرهای POST/PATCH
/// مدیر از قبل روی سرور بوده‌اند (CMD-005) و اپ مشتری نبوده است. با حکم
/// CMD-028 پنل مدیریتی موبایل همان قرارداد را آینه می‌کند — صفر تغییر سرور.
///
/// ثابت‌های سرور (عیناً از web.js):
///   INV_LIMIT = 300 — سقف ردیف‌های یک پاسخ (بدون صفحه‌بندی؛ نزولی created_at,id)
///   وضعیت‌ها: pending | paid — برچسب وب BIST: در انتظار / پرداخت‌شده
///   محدوده‌ی مبلغ صدور (مدیر): ۱۰۰۰ .. ۱۰ میلیارد تومان
///   سقف نرخ صدور: ۳۰ در ساعت (429) — فقط مدیر
library;

abstract final class BillingContract {
  /// سقف ردیف‌های فهرست — `INV_LIMIT` سرور
  static const int invLimit = 300;

  /// برچسب فارسی وضعیت‌ها — نقشه‌ی BIST رابط وب:
  /// {pending:'در انتظار', paid:'پرداخت‌شده'}
  static const Map<String, String> statusLabels = {
    'pending': 'در انتظار',
    'paid': 'پرداخت‌شده',
  };

  /// برچسب فارسی وضعیت — ناشناخته = مقدار خام (مثل سرور)
  static String labelOfStatus(String status) =>
      statusLabels[status] ?? status;

  /// خطای ۴۰۳ وکیل — عین سرور (صفحه‌ی مالی وکیل در UI مرجع هم نیست)
  static const String lawyerForbiddenMessage = 'دسترسی ندارید.';

  /// پیام صادقانه‌ی دکمه‌ی «پرداخت آنلاین» — عین متن وب (تصمیم باز CMD-005:
  /// اتصال درگاه نیازمند دستور مدیر است؛ هیچ وعده‌ی پرداخت جعلی نمایش داده
  /// نمی‌شود). در M6 همین پیام از سرور (503) می‌آید — عین هم‌بودن تست شده.
  static const String paymentGatewayMessage =
      'درگاه پرداخت هنوز متصل نشده است؛ پس از تصمیم مدیر فعال می‌شود.';

  /// خالی صادقانه — عین متن وب
  static const String emptyMessage = 'هنوز فاکتوری برای شما صادر نشده است.';

  /// محدوده‌ی مبلغ صدور سمت مدیر — آینه‌ی `int(..., 1000, 10e9, 'مبلغ فاکتور')`
  static const int amountMin = 1000;
  static const int amountMax = 10 * 1000 * 1000 * 1000;

  /// پیام‌های عین سرور — آینه‌ی خطاهای عملیات مدیر (CMD-005 در web.js)
  static const String issueRateLimitMessage =
      'سقف صدور فاکتور در یک ساعت تکمیل شده است. بعداً تلاش کنید.';
  static const String issueClientNotFoundMessage = 'مشتری یافت نشد.';
  static const String invoiceNotFoundMessage = 'فاکتور یافت نشد.';
  static const String payOnlyPendingMessage =
      'فقط فاکتور «در انتظار» قابل پرداخت است.';
  static const String reopenOnlyPaidMessage =
      'این فاکتور پرداخت‌نشده است؛ بازکردنی در کار نیست.';
  static const String payAlreadyPaidMessage = 'این فاکتور پرداخت‌شده است.';

  /// اعتبارسنجی سمت کاربر — آینه‌ی قواعد سرور قبل از POST (صدور فاکتور)
  /// خطا = پیام فارسی؛ درست = null
  static String? validateIssueAmount(String raw) {
    final digits = toEnglishDigits(raw).trim();
    if (digits.isEmpty) return 'مبلغ فاکتور نامعتبر است.';
    final n = int.tryParse(digits);
    if (n == null || n < amountMin || n > amountMax) {
      return 'مبلغ فاکتور نامعتبر است.';
    }
    return null;
  }

  /// ارقام انگلیسی — برای پارس ورودی مبلغ (ارقام فارسی/عربی هم پذیرفته می‌شود)
  static String toEnglishDigits(Object value) {
    const map = {
      '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
      '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };
    var s = value.toString();
    map.forEach((fa, en) => s = s.replaceAll(fa, en));
    return s.replaceAll(RegExp(r'[,\s٬]'), '');
  }

  /// قالب مبلغ تومان با جداکننده‌ی هزارگان و ارقام فارسی — آینه‌ی jmoney وب
  /// 25000000 → «۲۵٬۰۰۰٬۰۰۰ تومان»
  static String formatToman(int amount) {
    final digits = amount.abs().toString();
    final parts = <String>[];
    for (var i = digits.length; i > 0; i -= 3) {
      parts.insert(
        0,
        digits.substring(i - 3 < 0 ? 0 : i - 3, i),
      );
    }
    final sign = amount < 0 ? '−' : '';
    return '$sign${toPersianDigits(parts.join('٬'))} تومان';
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
