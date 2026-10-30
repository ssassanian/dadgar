/// مدل نشست کاربر — M6 (CMD-028)
///
/// شکل داده دقیقاً همان `GET /api/me` سرور است (web.js: `pub(c.user)`) —
/// {id, role, name, username, email, phone, mustChange, specialty} — موبایل
/// فقط فیلدهای لازم را می‌خواند؛ هیچ دانه‌ی جدیدی اختراع نمی‌شود (S-4).
///
/// نقش = کلید gating پنل مدیریتی موبایل: 'admin' کارت پنل و صفحات مدیریتی را
/// می‌بیند؛ 'client'/'lawyer' هرگز. قانون‌گذاری نهایی همیشه سمت سرور است
/// (ROLE('admin')) — نقشِ سمت کلاینت فقط برای «نمایش/عدم نمایش» است.
library;

/// کاربر نشست — نتیجه‌ی GET /api/me برای نشست معتبر
final class SessionUser {
  const SessionUser({
    required this.id,
    required this.role,
    required this.name,
    required this.username,
  });

  final int id;
  final String role;

  /// نام نمایشی — ممکن است خالی باشد
  final String name;
  final String username;

  bool get isAdmin => role == 'admin';

  static SessionUser? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final role = json['role'];
    if (id == null || role is! String || role.isEmpty) return null;
    return SessionUser(
      id: (id as num).toInt(),
      role: role,
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
    );
  }
}
