/// لایه‌ی data مالی — M4 (DOC-04 §۱۱ ردیف M4) + M6 (CMD-028)
///
/// مسیرهای «موجود» سرور (S-4 — صفر مسیر جدید؛ همه از CMD-005/CMD-028-وب):
///   GET   /api/invoices           — فاکتورها (مشتری: خودش؛ مدیر: همه با نام‌ها)
///   POST  /api/invoices           — صدور دستی (فقط مدیر)
///   PATCH /api/invoices/:id       — ثبت پرداخت/بازکردن (فقط مدیر)
///   GET   /api/users?role=client  — فهرست حداقلی فرم صدور (فقط مدیر)
///   POST  /api/payments/request   — درخواست پرداخت فاکتور خودی (CMD-028)
///
/// احراز هویت با Bearer (interceptor مشترک ApiClient) — POST/PATCH با Bearer
/// از CSRF معافند (web.js: `!sess.bearer`).
library;

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'billing_contract.dart';
import '../domain/invoice_models.dart';

abstract interface class BillingRepository {
  /// فهرست فاکتورها — پاسخ تخت (سقف INV_LIMIT=300، بدون صفحه‌بندی)
  Future<InvoicesResponse> fetchInvoices();

  /// M6 — صدور فاکتور دستی (فقط مدیر) → شناسه‌ی فاکتور جدید
  Future<int> issueInvoice({required int clientId, required int amount});

  /// M6 — ثبت پرداخت (paid) یا بازکردن (pending) — فقط مدیر
  Future<void> setInvoiceStatus({required int id, required String status});

  /// M6 — فهرست حداقلی مشتری‌ها برای فرم صدور (فقط مدیر)
  Future<List<MinUser>> fetchClients();

  /// M6 — درخواست پرداخت آنلاین فاکتور خودی (اسکلت بی‌طرف CMD-028):
  /// 503 = پیام صادقانه‌ی درگاه (PayNotConfigured)؛ 200 = PayUrlReady
  Future<PayRequestResult> requestPayment({required int invoiceId});
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

  @override
  Future<int> issueInvoice({required int clientId, required int amount}) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.invoices,
        data: {'client_id': clientId, 'amount': amount},
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw _serverError(response, 'صدور فاکتور ناموفق بود');
      }
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
  Future<void> setInvoiceStatus({
    required int id,
    required String status,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        '${ApiEndpoints.invoices}/$id',
        data: {'status': status},
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw _serverError(response, 'تغییر وضعیت فاکتور ناموفق بود');
      }
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<List<MinUser>> fetchClients() async {
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.users,
        queryParameters: {'role': 'client'},
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw _serverError(response, 'دریافت فهرست مشتریان ناموفق بود');
      }
      final data = _requireMap(response);
      final rows = (data['rows'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MinUser.fromJson)
          .toList(growable: false);
      return rows;
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<PayRequestResult> requestPayment({required int invoiceId}) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.paymentRequest,
        data: {'invoice_id': invoiceId},
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw _serverError(response, 'درخواست پرداخت ناموفق بود');
      }
      final map = _requireMap(response);
      final url = map['pay_url'];
      if (url is! String || url.isEmpty) {
        throw const ApiException('پاسخ سرور کامل نبود');
      }
      return PayUrlReady(url);
    } on DioException catch (e) {
      // dio برای ≥500 استثنا می‌اندازد (validateStatus < 500) — 503 صادقانه
      // اسکلت بی‌طرف (درگاه تنظیم نشده) اینجا به پیام عین سرور نگاشت می‌شود
      if (e.response?.statusCode == 503) {
        final data = e.response?.data;
        final msg = data is Map<String, dynamic>
            ? data['error'] as String? ?? BillingContract.paymentGatewayMessage
            : BillingContract.paymentGatewayMessage;
        return PayNotConfigured(msg);
      }
      throw ApiException.from(e);
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }
}
