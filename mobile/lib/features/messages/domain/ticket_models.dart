/// مدل‌های دامنه‌ی تیکت — M5 (DOC-04 §۱۱ ردیف M5)
///
/// شکل داده دقیقاً همان پاسخ‌های `GET /api/tickets`، `GET /api/tickets/:id`
/// سرور است (CMD-007)؛ هیچ دانه‌ی داده‌ی جدیدی اختراع نمی‌شود (S-4).
/// نام فرستنده فقط برای مدیر می‌آید — نمای مشتری اصلاً فیلد نام ندارد.
library;

/// وضعیت تیکت — چهار مقدار سرور
extension type const TicketStatus(String value) {
  static const open = TicketStatus('open');
  static const review = TicketStatus('review');
  static const answered = TicketStatus('answered');
  static const closed = TicketStatus('closed');

  /// برچسب فارسی — آینه‌ی نقشه‌ی TK_ST وب
  String get labelFa => switch (value) {
        'open' => 'باز',
        'review' => 'در حال بررسی',
        'answered' => 'پاسخ داده‌شده',
        'closed' => 'بسته',
        _ => value,
      };
}

/// یک ردیف فهرست تیکت‌ها
final class TicketSummary {
  const TicketSummary({
    required this.id,
    required this.subject,
    required this.dept,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.msgCount,
  });

  final int id;
  final String subject;
  final String dept;
  final String priority;
  final String status;

  /// epoch-seconds
  final int createdAt;
  final int updatedAt;
  final int msgCount;

  TicketStatus get statusValue => TicketStatus(status);

  static TicketSummary fromJson(Map<String, dynamic> json) {
    return TicketSummary(
      id: (json['id'] as num).toInt(),
      subject: json['subject'] as String? ?? '',
      dept: json['dept'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: (json['created_at'] as num? ?? 0).toInt(),
      updatedAt: (json['updated_at'] as num? ?? 0).toInt(),
      msgCount: (json['msg_count'] as num? ?? 0).toInt(),
    );
  }
}

/// پیام داخل یک تیکت — خروجی rows در GET /api/tickets/:id
final class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.mine,
    required this.role,
    required this.body,
    required this.createdAt,
  });

  final int id;

  /// مالکیت پیام از سرور می‌آید — منبع یگانه‌ی حباب «من»
  final bool mine;
  final String role;
  final String body;
  final int createdAt;

  static TicketMessage fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      id: (json['id'] as num).toInt(),
      mine: json['mine'] as bool? ?? false,
      role: json['role'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: (json['created_at'] as num? ?? 0).toInt(),
    );
  }
}

/// جزئیات تیکت — سربرگ پاسخ GET /api/tickets/:id
final class TicketDetail {
  const TicketDetail({
    required this.id,
    required this.subject,
    required this.dept,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  final int id;
  final String subject;
  final String dept;
  final String priority;
  final String status;
  final int createdAt;
  final int updatedAt;
  final List<TicketMessage> messages;

  TicketStatus get statusValue => TicketStatus(status);

  static TicketDetail fromJson(Map<String, dynamic> json) {
    final ms = (json['rows'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TicketMessage.fromJson)
        .toList(growable: false);
    final t = json['ticket'] as Map<String, dynamic>? ?? const {};
    return TicketDetail(
      id: (t['id'] as num? ?? 0).toInt(),
      subject: t['subject'] as String? ?? '',
      dept: t['dept'] as String? ?? '',
      priority: t['priority'] as String? ?? '',
      status: t['status'] as String? ?? 'open',
      createdAt: (t['created_at'] as num? ?? 0).toInt(),
      updatedAt: (t['updated_at'] as num? ?? 0).toInt(),
      messages: ms,
    );
  }
}
