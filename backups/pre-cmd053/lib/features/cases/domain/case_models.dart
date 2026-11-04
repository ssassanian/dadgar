/// مدل دامنه‌ی پرونده‌ها — M2 (DOC-04 §۱۱ ردیف M2)
///
/// شکل داده دقیقاً همان پاسخ `GET /api/cases` و `GET /api/cases/:id` سرور
/// است (CMD-003)؛ هیچ دانه‌ی داده‌ی جدیدی از سمت موبایل اختراع نمی‌شود
/// (S-4). فیلدهای نقش‌محور اختیاری‌اند: `excerpt` برای وکیلِ ناشناس،
/// `client_name/client_phone` فقط مدیر، `description` کامل فقط مالک/مدیر.
library;

/// وضعیت پرونده — همان پنج مقدار سرور با ترتیب چرخه:
/// waiting → proposing → assigned → running → done
extension type const CaseStatus(String value) {
  static const waiting = CaseStatus('waiting');
  static const proposing = CaseStatus('proposing');
  static const assigned = CaseStatus('assigned');
  static const running = CaseStatus('running');
  static const done = CaseStatus('done');

  /// برچسب فارسی نمایشی — آینه‌ی نقشه‌ی ST رابط وب
  String get labelFa => switch (value) {
        'waiting' => 'در انتظار بررسی',
        'proposing' => 'در حال پیشنهاد',
        'assigned' => 'تخصیص‌یافته',
        'running' => 'در حال انجام',
        'done' => 'بسته‌شده',
        _ => value,
      };
}

/// یک ردیف فهرست پرونده — خروجی `caseListRow` سرور
final class CaseSummary {
  const CaseSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.finalPrice,
    this.clientId,
    this.lawyerId,
    this.lawyerName = '',
    this.excerpt,
    this.clientName,
    this.clientPhone,
  });

  final int id;
  final String title;
  final String category;
  final String status;

  /// epoch-seconds — نمایش با تقویم شمسی نیتیو (M3)
  final int createdAt;
  final int updatedAt;
  final int? finalPrice;

  final int? clientId;
  final int? lawyerId;
  final String lawyerName;

  /// خلاصه‌ی ۱۶۰نویسه‌ای — فقط برای نقش‌های بدون دسترسی کامل
  final String? excerpt;
  final String? clientName;
  final String? clientPhone;

  CaseStatus get statusValue => CaseStatus(status);

  static CaseSummary fromJson(Map<String, dynamic> json) {
    return CaseSummary(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      status: json['status'] as String? ?? 'waiting',
      createdAt: (json['created_at'] as num? ?? 0).toInt(),
      updatedAt: (json['updated_at'] as num? ?? 0).toInt(),
      finalPrice: json['final_price'] == null
          ? null
          : (json['final_price'] as num).toInt(),
      clientId: json['client_id'] == null
          ? null
          : (json['client_id'] as num).toInt(),
      lawyerId: json['lawyer_id'] == null
          ? null
          : (json['lawyer_id'] as num).toInt(),
      lawyerName: json['lawyer_name'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      clientName: json['client_name'] as String?,
      clientPhone: json['client_phone'] as String?,
    );
  }
}

/// جزئیات پرونده — خروجی `GET /api/cases/:id` سرور
final class CaseDetail {
  const CaseDetail({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.finalPrice,
    this.lawyerName = '',
    this.description,
    this.excerpt,
    this.proposals = const [],
  });

  final int id;
  final String title;
  final String category;
  final String status;
  final int createdAt;
  final int updatedAt;
  final int? finalPrice;
  final String lawyerName;

  /// توضیحات کامل — فقط مالک (موکل) و مدیر می‌گیرند
  final String? description;

  /// خلاصه — برای نقش‌های بدون دسترسی کامل
  final String? excerpt;

  /// پیشنهادهای وکلا — فقط در payload مدیر می‌آید (CMD-003 در web.js)؛
  /// M6 (CMD-028): پایه‌ی اقدامات مدیر در موبایل (تایید پیشنهاد)
  final List<Proposal> proposals;

  CaseStatus get statusValue => CaseStatus(status);

  static CaseDetail fromJson(Map<String, dynamic> json) {
    return CaseDetail(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      status: json['status'] as String? ?? 'waiting',
      createdAt: (json['created_at'] as num? ?? 0).toInt(),
      updatedAt: (json['updated_at'] as num? ?? 0).toInt(),
      finalPrice: json['final_price'] == null
          ? null
          : (json['final_price'] as num).toInt(),
      lawyerName: json['lawyer_name'] as String? ?? '',
      description: json['description'] as String?,
      excerpt: json['excerpt'] as String?,
      proposals: (json['proposals'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Proposal.fromJson)
          .toList(growable: false),
    );
  }
}

/// یک پیشنهاد وکیل — ردیف `proposals[]` در جزئیات پرونده (payload مدیر):
/// {id, lawyer_name, amount, days, note, status, created_at}
final class Proposal {
  const Proposal({
    required this.id,
    required this.lawyerName,
    required this.amount,
    required this.days,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String lawyerName;

  /// مبلغ پیشنهادی — تومان
  final int amount;

  /// مدت اجرا — روز
  final int days;
  final String note;

  /// pending | accepted | rejected
  final String status;

  /// epoch-seconds
  final int createdAt;

  /// برچسب فارسی وضعیت — ناشناخته = مقدار خام
  String get statusLabelFa => switch (status) {
        'pending' => 'در انتظار',
        'accepted' => 'تایید‌شده',
        'rejected' => 'رد شده',
        _ => status,
      };

  static Proposal fromJson(Map<String, dynamic> json) {
    return Proposal(
      id: (json['id'] as num).toInt(),
      lawyerName: json['lawyer_name'] as String? ?? '',
      amount: (json['amount'] as num? ?? 0).toInt(),
      days: (json['days'] as num? ?? 0).toInt(),
      note: json['note'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: (json['created_at'] as num? ?? 0).toInt(),
    );
  }
}

/// پاسخ صفحه‌بندی‌شده‌ی GET /api/cases
final class CasesPage {
  const CasesPage({
    required this.rows,
    required this.page,
    required this.pages,
    required this.total,
  });

  final List<CaseSummary> rows;
  final int page;
  final int pages;
  final int total;

  static CasesPage fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CaseSummary.fromJson)
        .toList(growable: false);
    return CasesPage(
      rows: rows,
      page: (json['page'] as num? ?? 1).toInt(),
      pages: (json['pages'] as num? ?? 1).toInt(),
      total: (json['total'] as num? ?? 0).toInt(),
    );
  }
}
