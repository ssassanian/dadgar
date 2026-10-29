/// لایه‌ی data پرونده‌ها — M2 (DOC-04 §۱۱ ردیف M2)
///
/// مسیرها همان مسیرهای موجود سرور از CMD-003 هستند (S-4):
///   GET  /api/cases          ?page=N  (موکل: پرونده‌های خودش)
///   GET  /api/cases/:id
///   POST /api/cases          {category, title, description}
///
/// احراز هویت با Bearer (interceptor مشترک ApiClient) — پذیرش سمت سرور
/// منوط به حکم مدیر بر D-6 است؛ تا آن زمان پاسخ 401 با پیام صادقانه
/// «در انتظار D-6» نمایش داده می‌شود.
library;

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'cases_contract.dart';
import '../domain/case_models.dart';

abstract interface class CasesRepository {
  /// یک صفحه از فهرست پرونده‌ها — صفحه‌بندی سرور (CASES_PER=10)
  Future<CasesPage> fetchPage({required int page});

  /// جزئیات یک پرونده — ۴۰۴ ضدافشا سرور حفظ می‌شود
  Future<CaseDetail> fetchDetail({required int id});

  /// ثبت پرونده → شناسه‌ی جدید (خطای ۴۲۹ = سقف نرخ سرور)
  Future<int> create({
    required String category,
    required String title,
    required String description,
  });
}

final class DioCasesRepository implements CasesRepository {
  DioCasesRepository({required ApiClient client}) : _client = client;

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
  Future<CasesPage> fetchPage({required int page}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.cases,
        queryParameters: {'page': '$page'},
      );
      _requireOk(response, 'دریافت پرونده‌ها ناموفق بود');
      return CasesPage.fromJson(_requireMap(response));
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<CaseDetail> fetchDetail({required int id}) async {
    try {
      final response = await _dio.get<dynamic>('${ApiEndpoints.cases}/$id');
      _requireOk(response, CasesContract.notFoundMessage);
      return CaseDetail.fromJson(_requireMap(response));
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<int> create({
    required String category,
    required String title,
    required String description,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.cases,
        data: {
          'category': category,
          'title': title,
          'description': description,
        },
      );
      _requireOk(response, 'ثبت پرونده ناموفق بود');
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
}
