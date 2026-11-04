/// مدل دامنه‌ی نوبت‌دهی — M3 (DOC-04 §۱۱ ردیف M3)
///
/// شکل داده دقیقاً همان پاسخ `GET /api/appointments` سرور است؛ هیچ دانه‌ی
/// داده‌ی جدیدی از سمت موبایل اختراع نمی‌شود (S-4).
library;

/// وضعیت نوبت — همان سه مقدار سرور: booked → confirmed / canceled
extension type const AppointmentStatus(String value) {
  static const booked = AppointmentStatus('booked');
  static const confirmed = AppointmentStatus('confirmed');
  static const canceled = AppointmentStatus('canceled');

  /// برچسب فارسی نمایشی
  String get labelFa => switch (value) {
        'booked' => 'رزرو شده',
        'confirmed' => 'تایید شده',
        'canceled' => 'لغو شده',
        _ => value,
      };
}

/// یک نوبت — فیلدهای اختیاری بسته به نقش‌اند (نام‌ها فقط برای مدیر می‌آیند)
final class Appointment {
  const Appointment({
    required this.id,
    required this.startsAt,
    required this.day,
    required this.slot,
    required this.kind,
    required this.status,
    this.clientId,
    this.clientName,
    this.lawyerName,
  });

  final int id;

  /// epoch-seconds تهران — مرجع یکتای زمان
  final int startsAt;

  /// روز ۱..۳۰ ماه قرارداد (محاسبه‌شده در سرور)
  final int day;

  /// برچسب بازه مثل «۰۹:۰۰»
  final String slot;
  final String kind;
  final String status;

  final int? clientId;
  final String? clientName;
  final String? lawyerName;

  AppointmentStatus get statusValue => AppointmentStatus(status);

  static Appointment fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: (json['id'] as num).toInt(),
      startsAt: (json['starts_at'] as num).toInt(),
      day: (json['day'] as num).toInt(),
      slot: json['slot'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      status: json['status'] as String? ?? 'booked',
      clientId: json['client_id'] == null
          ? null
          : (json['client_id'] as num).toInt(),
      clientName: json['client_name'] as String?,
      lawyerName: json['lawyer_name'] as String?,
    );
  }
}

/// پاسخ یکپارچه‌ی GET /api/appointments
final class AppointmentsPage {
  const AppointmentsPage({
    required this.rows,
    required this.taken,
    required this.serverNowSeconds,
    required this.todayDay,
  });

  final List<Appointment> rows;

  /// بازه‌های اشغال‌شده به‌صورت «روز:برچسب» — مثل «۳:۰۹:۰۰»
  final Set<String> taken;

  /// epoch-seconds «الان» طبق ساعت سرور (مرجع یکتای گذشته/آینده)
  final int serverNowSeconds;

  /// شماره‌ی روز امروز در ماه قرارداد (۱..۳۱؛ بیرون ماه = ۳۱)
  final int todayDay;

  static AppointmentsPage fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Appointment.fromJson)
        .toList(growable: false);
    final taken = (json['taken'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((t) => '${(t['d'] as num).toInt()}:${t['j'] ?? ''}')
        .where((k) => !k.endsWith(':'))
        .toSet();
    return AppointmentsPage(
      rows: rows,
      taken: taken,
      serverNowSeconds: (json['now'] as num? ?? 0).toInt(),
      todayDay: (json['today_d'] as num? ?? 1).toInt(),
    );
  }
}
