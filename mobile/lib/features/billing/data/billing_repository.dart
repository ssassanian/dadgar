/// لایه‌ی data مالی — M4 (DOC-04 §۱۱ ردیف M4)
///
/// مسیر همان مسیر «موجود» سرور از CMD-005 است (S-4):
///   GET /api/invoices   (مشتری: فقط فاکتورهای خودش — بدون نام‌ها)
///
/// احراز هویت با Bearer (interceptor مشترک ApiClient) — پذیرش سمت سرور
/// منوط به حکم مدیر بر D-6 است؛ تا آن زمان پاسخ 401 با پیام صادقانه
/// «در انتظار D-6» نمایش داده می‌شود.
///
/// POST/PATCH فاکتور نقش مدیر می‌خواهد و در اپ موبایل مشتری جای ندارد؛
/// به همین دلیل در آینه‌ی موبایل وجود ندارد (قرارداد کامل در سند CMD-005).
library;

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../domain/invoice_models.dart';

abstract interface class BillingRepository {
  /// فهرست فاکتورهای خود کاربر — پاسخ تخت (سقف INV_LIMIT=300، بدون صفحه‌بندی)
  Future<InvoicesResponse> fetchInvoices();
}

final class DioBillingRepository implements BillingRepository {
  DioBillingRepository({required ApiClient client}) : _client = client;

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

  @override
  Future<InvoicesResponse> fetchInvoices() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.invoices);
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw _serverError(response, 'دریافت فاکتورها ناموفق بود');
      }
      return InvoicesResponse.fromJson(_requireMap(response));
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }
}
