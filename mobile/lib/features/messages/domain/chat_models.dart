/// مدل‌های دامنه‌ی چت پرونده — M5 (DOC-04 §۱۱ ردیف M5)
///
/// شکل داده دقیقاً همان پاسخ‌های `GET /api/threads` و `GET /api/messages`
/// سرور است (CMD-007): گفتگو فقط برای پرونده‌های دارای وکیلِ تخصیص‌یافته
/// (assigned/running/done)؛ `mine` از سرور می‌آید.
library;

/// یک گفتگو در فهرست — ردیف GET /api/threads
final class Thread {
  const Thread({
    required this.caseId,
    required this.title,
    required this.category,
    required this.status,
    required this.lastAt,
    required this.lastExcerpt,
    required this.lastMine,
  });

  final int caseId;
  final String title;
  final String category;
  final String status;

  /// آخرین فعالیت پیام یا updated_at پرونده — epoch-seconds
  final int lastAt;

  /// گزیده‌ی ۸۰نویسه‌ای آخرین پیام — خالی یعنی هنوز پیامی نیست
  final String lastExcerpt;
  final bool lastMine;

  static Thread fromJson(Map<String, dynamic> json) {
    return Thread(
      caseId: (json['case_id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      status: json['status'] as String? ?? '',
      lastAt: (json['last_at'] as num? ?? 0).toInt(),
      lastExcerpt: json['last_excerpt'] as String? ?? '',
      lastMine: json['last_mine'] as bool? ?? false,
    );
  }
}

/// یک پیام چت — ردیف GET /api/messages
final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.mine,
    required this.role,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final bool mine;
  final String role;
  final String body;
  final int createdAt;

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      mine: json['mine'] as bool? ?? false,
      role: json['role'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: (json['created_at'] as num? ?? 0).toInt(),
    );
  }
}

/// پاکت پاسخ GET /api/messages — سربرگ پرونده + ردیف پیام‌ها
final class ChatEnvelope {
  const ChatEnvelope({
    required this.caseId,
    required this.caseTitle,
    required this.caseStatus,
    required this.rows,
  });

  final int caseId;
  final String caseTitle;
  final String caseStatus;
  final List<ChatMessage> rows;

  static ChatEnvelope fromJson(Map<String, dynamic> json) {
    final cs = json['case'] as Map<String, dynamic>? ?? const {};
    final rows = (json['rows'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList(growable: false);
    return ChatEnvelope(
      caseId: (cs['id'] as num? ?? 0).toInt(),
      caseTitle: cs['title'] as String? ?? '',
      caseStatus: cs['status'] as String? ?? '',
      rows: rows,
    );
  }
}
