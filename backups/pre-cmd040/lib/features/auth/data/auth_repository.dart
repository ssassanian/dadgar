import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/secure/token_store.dart';
import '../domain/session_user.dart';

/// قرارداد لایه‌ی data احراز هویت — M1 (DOC-04 §۱۱) + M6 (CMD-028)
abstract interface class AuthRepository {
  /// ورود با همان حساب‌های موجود وب؛ خروجی = نام کاربری نشست
  Future<String> login({required String username, required String password});

  /// بازیابی نشست از ذخیره‌ی امن هنگام اجرای اپ؛ null = بدون نشست
  Future<String?> restoreSession();

  /// خروج: ابطال توکن همان دستگاه (best-effort) + پاکسازی ذخیره‌ی امن
  Future<void> logout();

  /// M6 (CMD-028) — کشف نقش نشست از GET /api/me
  /// null = مهمان/نشست نامعتبر (سرور با 200 و user:null پاسخ می‌دهد)
  Future<SessionUser?> fetchMe();
}

/// پیاده‌سازی dio — مسیرها از ApiEndpoints (DOC-04 §۵-۲)
///
/// فعال‌سازی واقعی سرور منوط به حکم مدیر بر D-6 است؛ تا آن زمان
/// درخواست‌ها با 404 پاسخ می‌گیرند و پیام صادقانه نمایش داده می‌شود.
final class DioAuthRepository implements AuthRepository {
  DioAuthRepository({required TokenStore store})
      : _store = store {
    _client = ApiClient(tokenStore: store, onUnauthorized: _refreshTokens);
  }

  final TokenStore _store;
  late final ApiClient _client;
  bool _refreshing = false;

  Dio get _dio => _client.dio;

  /// چرخش refresh — توسط interceptor پس از 401 صدا زده می‌شود
  Future<bool> _refreshTokens() async {
    if (_refreshing) return false;
    final current = await _store.read();
    final refresh = current?.refresh;
    if (refresh == null || refresh.isEmpty) return false;
    _refreshing = true;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.tokenRefresh,
        data: {'refresh_token': refresh},
        options: Options(extra: {'skip_auth_retry': true}),
      );
      final access = _pick(response.data, const ['access_token', 'accessToken']);
      if (access == null) return false;
      await _store.save(
        AuthTokens(
          access: access,
          refresh: _pick(response.data, const ['refresh_token', 'refreshToken']) ?? refresh,
          username: current?.username,
        ),
      );
      return true;
    } on DioException {
      await _store.clear();
      return false;
    } finally {
      _refreshing = false;
    }
  }

  static String? _pick(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Future<String> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.token,
        data: {'username': username, 'password': password},
        options: Options(extra: {'skip_auth_retry': true}),
      );
      final data = response.data;
      final access = _pick(data, const ['access_token', 'accessToken']);
      if (access == null) {
        throw const ApiException('پاسخ سرور کامل نبود — دوباره تلاش کنید');
      }
      final resolvedUsername = username.trim();
      await _store.save(
        AuthTokens(
          access: access,
          refresh: _pick(data, const ['refresh_token', 'refreshToken']),
          username: resolvedUsername,
        ),
      );
      return resolvedUsername;
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<String?> restoreSession() async {
    try {
      final tokens = await _store.read();
      if (tokens == null) return null;
      return tokens.username ?? 'کاربر دادگر';
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    final tokens = await _store.read();
    final refresh = tokens?.refresh;
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _dio.post<Map<String, dynamic>>(
          ApiEndpoints.tokenRevoke,
          data: {'refresh_token': refresh, 'scope': 'device'},
          options: Options(extra: {'skip_auth_retry': true}),
        );
      } on Object {
        // خروج محلی همیشه انجام می‌شود؛ ابطال سروری best-effort است
      }
    }
    await _store.clear();
  }

  @override
  Future<SessionUser?> fetchMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.me);
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final user = data['user'];
      if (user is! Map<String, dynamic>) return null; // مهمان: user:null
      return SessionUser.fromJson(user);
    } on Object {
      // کشف نقش حیاتی نیست — خطا = بدون نقش (کارت‌های مدیریتی مخفی می‌مانند)
      return null;
    }
  }
}
