/// آینه‌ی قرارداد پیام/تیکت سمت سرور — CMD-007 فاز ۳ گام ۵ در `web/lib/web.js`
///
/// S-4: موبایل فقط همین قرارداد موجود را مصرف می‌کند؛ هیچ مسیر/شکل جدیدی
/// تعریف نمی‌شود و سرور با این ماژول صفر تغییر می‌کند. (PATCH تیکت فقط مدیر
/// است و در اپ مشتری جای ندارد.)
///
/// ثابت‌های سرور (عیناً از web.js):
///   TK_DEPTS = پنج بخش · TK_PRIS = سه اولویت
///   TK_ST = {open:'باز', review:'در حال بررسی', answered:'پاسخ داده‌شده', closed:'بسته'}
///   TK_LIMIT = 200 · MSG_LIMIT = 300 · سقف ۵۰ گفتگو در /api/threads
///   POST تیکت: subject ۳..۱۲۰ ، body ۳..۳۰۰۰ ، سقف ۵ تیکت در ساعت (429)
///   POST پاسخ: body ۱..۳۰۰۰ ، سقف ۶۰ پاسخ در ۱۰ دقیقه (429)، تیکت بسته 400
///   POST پیام: body ۱..۲۰۰۰ ، سقف ۳۰ پیام در ۱۰ دقیقه (429)، گفتگوی غیرفعال 400
library;

abstract final class MessagesContract {
  /// پنج بخش تیکت — `TK_DEPTS` سرور؛ ترتیب هم‌سان
  static const List<String> tkDepts = [
    'فنی',
    'مالی',
    'شکایات',
    'عمومی',
    'حقوقی',
  ];

  /// سه اولویت — `TK_PRIS` سرور
  static const List<String> tkPris = ['کم', 'متوسط', 'بالا'];

  /// برچسب فارسی وضعیت تیکت — نقشه‌ی TK_ST رابط وب
  static const Map<String, String> ticketStatusLabels = {
    'open': 'باز',
    'review': 'در حال بررسی',
    'answered': 'پاسخ داده‌شده',
    'closed': 'بسته',
  };

  static String labelOfTicketStatus(String status) =>
      ticketStatusLabels[status] ?? status;

  /// سقف‌های فهرست — سرور
  static const int tkLimit = 200;
  static const int msgLimit = 300;
  static const int threadsLimit = 50;

  /// طول گزیده‌ی آخرین پیام گفتگو — سرور slice(0,80)
  static const int lastExcerptLen = 80;

  /// محدوده‌های اعتبارسنجی — عین قواعد سرور
  static const int subjectMin = 3;
  static const int subjectMax = 120;
  static const int ticketBodyMin = 3;
  static const int ticketBodyMax = 3000;
  static const int replyBodyMin = 1;
  static const int replyBodyMax = 3000;
  static const int chatBodyMin = 1;
  static const int chatBodyMax = 2000;

  /// خطاهای سرور — عیناً
  static const String ticketNotFound = 'تیکت یافت نشد.';
  static const String caseNotFound = 'پرونده یافت نشد.';
  static const String ticketRateLimit =
      'سقف ارسال تیکت در یک ساعت تکمیل شده است. بعداً تلاش کنید.';
  static const String messageRateLimit =
      'تعداد پیام‌ها زیاد است. کمی بعد تلاش کنید.';
  static const String ticketClosedMessage =
      'این تیکت بسته شده است؛ برای موضوع جدید تیکت جدیدی باز کنید.';
  static const String chatNotActiveMessage =
      'گفتگوی این پرونده هنوز فعال نیست؛ پس از تخصیص وکیل باز می‌شود.';

  /// برچسب نقش فرستنده برای حباب‌ها — role از سرور
  static String labelOfRole(String role) => switch (role) {
        'client' => 'موکل',
        'lawyer' => 'وکیل',
        'admin' => 'مدیر',
        _ => 'کاربر',
      };

  static String? validateSubject(String value) {
    final t = value.trim();
    if (t.length < subjectMin) {
      return 'موضوع باید حداقل $subjectMin نویسه باشد';
    }
    if (t.length > subjectMax) {
      return 'موضوع حداکثر $subjectMax نویسه است';
    }
    return null;
  }

  static String? validateTicketBody(String value) {
    final t = value.trim();
    if (t.length < ticketBodyMin) {
      return 'متن تیکت باید حداقل $ticketBodyMin نویسه باشد';
    }
    if (t.length > ticketBodyMax) {
      return 'متن تیکت حداکثر $ticketBodyMax نویسه است';
    }
    return null;
  }

  static String? validateReplyBody(String value) {
    final t = value.trim();
    if (t.length < replyBodyMin) return 'متن پاسخ را بنویسید';
    if (t.length > replyBodyMax) {
      return 'متن پاسخ حداکثر $replyBodyMax نویسه است';
    }
    return null;
  }

  static String? validateChatBody(String value) {
    final t = value.trim();
    if (t.length < chatBodyMin) return 'متن پیام را بنویسید';
    if (t.length > chatBodyMax) {
      return 'متن پیام حداکثر $chatBodyMax نویسه است';
    }
    return null;
  }
}
