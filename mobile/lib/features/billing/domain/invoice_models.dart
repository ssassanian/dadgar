/// مدل دامنه‌ی مالی — M4 (DOC-04 §۱۱ ردیف M4)
///
/// شکل داده دقیقاً همان پاسخ `GET /api/invoices` سرور برای نقش مشتری است
/// (CMD-005)؛ هیچ دانه‌ی داده‌ی جدیدی از سمت موبایل اختراع نمی‌شود (S-4).
/// نمای مشتری نام مشتری/وکیل نمی‌گیرد (حریم خصوصی CMD-005)؛ `case_id`
/// null یعنی فاکتور دستیِ بدون اتصال به پرونده.
library;

/// وضعیت فاکتور — دو مقدار سرور با چرخه‌ی گذار مدیر:
/// pending → paid (ثبت پرداخت) و paid → pending (بازکردن)
extension type const InvoiceStatus(String value) {
  static const pending = InvoiceStatus('pending');
  static const paid = InvoiceStatus('paid');

  /// برچسب فارسی نمایشی — آینه‌ی نقشه‌ی BIST رابط وب
  String get labelFa => switch (value) {
        'pending' => 'در انتظار',
        'paid' => 'پرداخت‌شده',
        _ => value,
      };
}

/// یک ردیف فاکتور — خروجی `GET /api/invoices` (نمای مشتری)
final class Invoice {
  const Invoice({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.paidAt,
    required this.caseId,
  });

  final int id;

  /// مبلغ به تومان — بازه‌ی صدور سرور ۱۰۰۰ .. ۱۰ میلیارد
  final int amount;
  final String status;

  /// epoch-seconds — نمایش با تقویم شمسی نیتیو (M3)
  final int createdAt;

  /// epoch-seconds یا null — null یعنی هنوز پرداخت نشده
  final int? paidAt;

  /// null = فاکتور دستی بدون پرونده‌ی متصل
  final int? caseId;

  InvoiceStatus get statusValue => InvoiceStatus(status);

  static Invoice fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: (json['id'] as num).toInt(),
      amount: (json['amount'] as num? ?? 0).toInt(),
      status: json['status'] as String? ?? 'pending',
      createdAt: (json['created_at'] as num? ?? 0).toInt(),
      paidAt: json['paid_at'] == null
          ? null
          : (json['paid_at'] as num).toInt(),
      caseId:
          json['case_id'] == null ? null : (json['case_id'] as num).toInt(),
    );
  }
}

/// پاسخ کامل `GET /api/invoices` — فهرست تخت بدون صفحه‌بندی (سقف ۳۰۰)
/// + `today_d` سرور برای محاسبات «امروز» تهران
final class InvoicesResponse {
  const InvoicesResponse({
    required this.rows,
    required this.todayD,
  });

  final List<Invoice> rows;

  /// روز جلالی «امروز» تهران از سرور — ۱..۳۱
  final int todayD;

  static InvoicesResponse fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Invoice.fromJson)
        .toList(growable: false);
    return InvoicesResponse(
      rows: rows,
      todayD: (json['today_d'] as num? ?? 1).toInt(),
    );
  }
}
