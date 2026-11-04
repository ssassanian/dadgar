/// لایه‌ی data نوبت‌دهی — M3 (DOC-04 §۱۱ ردیف M3)
///
/// مسیرها همان مسیرهای موجود سرور از CMD-004 هستند (S-4):
///   GET   /api/appointments
///   POST  /api/appointments            {day, slot, kind}
///   PATCH /api/appointments/:id        {status}
///
/// احراز هویت با Bearer (interceptor مشترک ApiClient) — پذیرش سمت سرور
/// منوط به حکم مدیر بر D-6 است؛ تا آن زمان پاسخ 401 با پیام صادقانه
/// «در انتظار D-6» نمایش داده می‌شود.
library;

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../domain/appointment.dart';

abstract interface class AppointmentsRepository {
  /// فهرست نوبت‌ها + بازه‌های اشغال‌شده + ساعت سرور
  Future<AppointmentsPage> fetch();

  /// رزرو بازه → شناسه‌ی نوبت (خطای ۴۰۹ = بازه پر است)
  Future<int> book({required int day, required String slot, required String kind});

  /// تغییر وضعیت — موکل فقط «canceled»
  Future<void> updateStatus({required int id, required String status});
}

final class DioAppointmentsRepository implements AppointmentsRepository {
  DioAppointmentsRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Dio get _dio => _client.dio;

  /// استخراج پیام فارسی سرور — سرور در 4xx پیام‌های کاربرمحور می‌فرستد
  ApiException _serverError(Response<dynamic> response, String fallback) {
    final data = response.data;
    final message =
        data is Map<String, dynamic> ? data['error'] as String? : null;
    if (message != null && message.isNotEmpty) {
      return ApiException(message, statusCode: response.statusCode);
    }
    return ApiException(fallback, statusCode: response.statusCode);
  }

  Map<String, dynamic> _requireMap(Response<dynamic>? response) {
    final data = response?.data;
    if (data is Map<String, dynamic>) return data;
    throw const ApiException('پاسخ سرور قابل خواندن نبود');
  }

  void _requireOk(Response<dynamic> response, String fallback) {
    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw _serverError(response, fallback);
    }
  }

  @override
  Future<AppointmentsPage> fetch() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.appointments);
      _requireOk(response, 'دریافت نوبت‌ها ناموفق بود');
      return AppointmentsPage.fromJson(_requireMap(response));
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<int> book({
    required int day,
    required String slot,
    required String kind,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.appointments,
        data: {'day': day, 'slot': slot, 'kind': kind},
      );
      _requireOk(response, 'ثبت نوبت ناموفق بود');
      final data = _requireMap(response);
      final id = data['id'];
      if (id is! num) {
        throw const ApiException('پاسخ سرور کامل نبود');
      }
      return id.toInt();
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<void> updateStatus({required int id, required String status}) async {
    try {
      final response = await _dio.patch<dynamic>(
        '${ApiEndpoints.appointments}/$id',
        data: {'status': status},
      );
      _requireOk(response, 'تغییر وضعیت نوبت ناموفق بود');
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }
}
