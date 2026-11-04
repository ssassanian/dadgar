/// مدل دامنه‌ی اسناد — M5 (DOC-04 §۱۱ ردیف M5)
///
/// شکل داده دقیقاً همان پاسخ `GET /api/documents` سرور است (CMD-008)؛
/// هیچ دانه‌ی داده‌ی جدیدی اختراع نمی‌شود (S-4). `mine` از سرور می‌آید
/// (فقط بارگذار یا مدیر اجازه‌ی حذف دارد) و `shared` استنتاج عضویت
/// پرونده‌ی دارای وکیل است.
library;

/// یک ردیف فهرست اسناد
final class DocSummary {
  const DocSummary({
    required this.id,
    required this.caseId,
    required this.caseTitle,
    required this.name,
    required this.mime,
    required this.size,
    required this.mine,
    required this.shared,
    required this.createdAt,
  });

  final int id;
  final int caseId;
  final String caseTitle;
  final String name;
  final String mime;
  final int size;
  final bool mine;

  /// true = پرونده‌ی دارای وکیل («اشتراک با وکیل»)
  final bool shared;
  final int createdAt;

  static DocSummary fromJson(Map<String, dynamic> json) {
    return DocSummary(
      id: (json['id'] as num).toInt(),
      caseId: (json['case_id'] as num? ?? 0).toInt(),
      caseTitle: json['case_title'] as String? ?? '',
      name: json['name'] as String? ?? 'سند',
      mime: json['mime'] as String? ?? '',
      size: (json['size'] as num? ?? 0).toInt(),
      mine: json['mine'] as bool? ?? false,
      shared: json['shared'] as bool? ?? false,
      createdAt: (json['created_at'] as num? ?? 0).toInt(),
    );
  }
}

/// سند انتخاب‌شده برای بارگذاری — از انتخابگر (دوربین/گالری)
///
/// لایه‌ی presentation وابستگی پلتفرمی (image_picker) را به این مدل
/// تبدیل می‌کند تا مخزن/کنترلر کاملاً تست‌پذیر بمانند (DOC-04 §۹).
final class PickedDoc {
  const PickedDoc({
    required this.name,
    required this.mime,
    required this.bytes,
  });

  final String name;
  final String mime;
  final List<int> bytes;
}
