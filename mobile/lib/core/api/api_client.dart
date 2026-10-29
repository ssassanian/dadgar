import 'package:dio/dio.dart';

import '../env/env.dart';
import '../secure/token_store.dart';

/// مسیرهای API — تنها نقطه‌ی اتصال موبایل به سرور (S-4 / DOC-04 §۵-۲)
///
/// مسیرهای ۴۶گانه‌ی موجود وب عیناً دست‌نخورده می‌مانند؛ این افزوده‌ها
/// «ثبت‌شده» در DOC-04 §۵ هستند و فعال‌سازی سمت سرور آن‌ها منوط به حکم
/// صریح مدیر بر D-6 است (کد سمت موبایل از همین حالا آماده است).
abstract final class ApiEndpoints {
  static const String token = '/api/auth/token';
  static const String tokenRefresh = '/api/auth/token/refresh';
  static const String tokenRevoke = '/api/auth/token/revoke';

  /// نوبت‌دهی — مسیر «موجود» سرور (CMD-004)؛ پذیرش Bearer پس از حکم D-6
  static const String appointments = '/api/appointments';

  /// پرونده‌ها — مسیرهای «موجود» سرور (CMD-003)؛ پذیرش Bearer پس از حکم D-6
  static const String cases = '/api/cases';
}

/// خطای یکپارچه‌ی لایه‌ی API با پیام فارسی قابل نمایش به کاربر
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// نگاشت خطاهای dio به پیام‌های صادقانه‌ی فارسی — بدون افشای جزئیات فنی
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          const ApiException('زمان اتصال به سرور تمام شد — دوباره تلاش کنید'),
        DioExceptionType.connectionError => const ApiException(
            'اتصال به سرور برقرار نشد — اینترنت دستگاه را بررسی کنید',
          ),
        DioExceptionType.badResponse => ApiException(
            switch (error.response?.statusCode) {
              400 => 'درخواست نامعتبر است',
              401 => 'نام کاربری یا رمز عبور نادرست است',
              403 => 'دسترسی مجاز نیست',
              404 => 'سرویس احراز هویت هنوز فعال نشده است (در انتظار D-6)',
              429 => 'تلاش بیش از حد — کمی بعد دوباره امتحان کنید',
              _ => 'خطای سرور (${error.response?.statusCode})',
            },
            statusCode: error.response?.statusCode,
          ),
        _ => const ApiException('خطای نامشخص در ارتباط با سرور'),
      };
    }
    return const ApiException('خطای نامشخص');
  }

  @override
  String toString() => message;
}

/// کارخانه‌ی dio با interceptor توکن Bearer و چرخش خودکار پس از 401
///
/// طراحی بر اساس DOC-04 §۵-۱ (الگوی توکن برای کلاینت غیرمرورگری) و §۸
/// (توکن فقط در Keystore/Keychain — هیچ secret در کد یا باینری).
final class ApiClient {
  ApiClient({
    required TokenStore tokenStore,
    Future<bool> Function()? onUnauthorized,
    String? baseUrl,
  })  : _tokenStore = tokenStore,
        _onUnauthorized = onUnauthorized,
        _baseUrl = baseUrl ?? Env.baseUrl {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
        validateStatus: (code) => code != null && code < 500,
      ),
    );
    dio.interceptors.add(InterceptorsWrapper(onRequest: _attachToken));
    dio.interceptors.add(
      QueuedInterceptorsWrapper(onError: _handleUnauthorized),
    );
  }

  final String _baseUrl;
  final TokenStore _tokenStore;
  final Future<bool> Function()? _onUnauthorized;

  late final Dio dio;

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tokens = await _tokenStore.read();
    final access = tokens?.access;
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  Future<void> _handleUnauthorized(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final code = err.response?.statusCode;
    final skip = err.requestOptions.extra['skip_auth_retry'] == true;
    if (code != 401 || skip || _onUnauthorized == null) {
      return handler.next(err);
    }
    final refreshed = await _onUnauthorized();
    if (!refreshed) return handler.next(err);
    final tokens = await _tokenStore.read();
    final access = tokens?.access;
    if (access == null) return handler.next(err);
    final opts = err.requestOptions
      ..headers['Authorization'] = 'Bearer $access'
      ..extra['skip_auth_retry'] = true;
    try {
      final retry = await dio.fetch<dynamic>(opts);
      return handler.resolve(retry);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
