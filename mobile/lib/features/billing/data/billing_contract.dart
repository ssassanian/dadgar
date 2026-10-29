/// آینه‌ی قرارداد مالی سمت سرور — CMD-005 فاز ۳ گام ۳ در `web/lib/web.js`
///
/// S-4: موبایل فقط همین قرارداد موجود را مصرف می‌کند؛ هیچ مسیر/شکل جدیدی
/// تعریف نمی‌شود و سرور با این ماژول صفر تغییر می‌کند.
///
/// محدوده‌ی موبایل = نمای مشتری (اپ موبایل اپ مشتری است؛ صدور/پرداخت مدیریتی
/// در پنل وب می‌ماند و POST/PATCH فاکتور نقش مدیر می‌خواهد — وکیل هم 403).
///
/// ثابت‌های سرور (عیناً از web.js):
///   INV_LIMIT = 300 — سقف ردیف‌های یک پاسخ (بدون صفحه‌بندی؛ نزولی created_at,id)
///   وضعیت‌ها: pending | paid — برچسب وب BIST: در انتظار / پرداخت‌شده
///   محدوده‌ی مبلغ صدور (مدیر): ۱۰۰۰ .. ۱۰ میلیارد تومان — برای مستندسازی قرارداد
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
  /// نمی‌شود)
  static const String paymentGatewayMessage =
      'درگاه پرداخت هنوز متصل نشده است؛ پس از تصمیم مدیر فعال می‌شود.';

  /// خالی صادقانه — عین متن وب
  static const String emptyMessage = 'هنوز فاکتوری برای شما صادر نشده است.';

  /// محدوده‌ی مبلغ صدور سمت مدیر — فقط برای مستندسازی قرارداد در آینه
  static const int amountMin = 1000;
  static const int amountMax = 10 * 1000 * 1000 * 1000;

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
