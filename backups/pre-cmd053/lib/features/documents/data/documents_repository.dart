/// لایه‌ی data اسناد — M5 (DOC-04 §۱۱ ردیف M5)
///
/// مسیرهای «موجود» سرور از CMD-008 هستند (S-4):
///   GET    /api/documents               فهرست اسناد پرونده‌های خود (سقف ۳۰۰)
///   POST   /api/cases/:id/documents     آپلود بدنه‌ی خام (≤۴MB، x-file-name)
///   GET    /api/documents/:id/file      دانلود بایت‌به‌بایت
///   DELETE /api/documents/:id           حذف — فقط بارگذار یا مدیر (۴۰۴ ضدافشا)
///
/// احراز هویت با Bearer (interceptor مشترک ApiClient) — پذیرش سمت سرور
/// منوط به حکم مدیر بر D-6 است.
library;

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../domain/document_models.dart';

abstract interface class DocumentsRepository {
  Future<List<DocSummary>> fetchDocuments();

  /// آپلود سند به پرونده → شناسه‌ی سند (۴۲۹ = سقف ۲۰ در ساعت سرور)
  Future<int> upload({
    required int caseId,
    required String name,
    required String mime,
    required List<int> bytes,
  });

  /// دانلود بایت‌به‌بایت — محتوا سمت سرور AES-256-GCM بازگشایی می‌شود
  Future<List<int>> download({required int id});

  /// حذف سند — فقط بارگذار یا مدیر؛ ۴۰۴ ضدافشا حفظ می‌شود
  Future<void> delete({required int id});
}

final class DioDocumentsRepository implements DocumentsRepository {
  DioDocumentsRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Dio get _dio => _client.dio;

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
  Future<List<DocSummary>> fetchDocuments() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.documents);
      _requireOk(response, 'دریافت اسناد ناموفق بود');
      final data = _requireMap(response);
      return (data['rows'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DocSummary.fromJson)
          .toList(growable: false);
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<int> upload({
    required int caseId,
    required String name,
    required String mime,
    required List<int> bytes,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '${ApiEndpoints.cases}/$caseId/documents',
        data: bytes,
        options: Options(
          headers: {
            // قرارداد سرور: نام فایل در هدر x-file-name (URL-encoded)
            'x-file-name': Uri.encodeComponent(name),
            'Content-Type': mime,
          },
        ),
      );
      _requireOk(response, 'بارگذاری سند ناموفق بود');
      final data = _requireMap(response);
      final id = data['id'];
      if (id is! num) throw const ApiException('پاسخ سرور کامل نبود');
      return id.toInt();
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<List<int>> download({required int id}) async {
    try {
      final response = await _dio.get<List<int>>(
        '${ApiEndpoints.documents}/$id/file',
        options: Options(responseType: ResponseType.bytes),
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw _serverError(response, 'سند یافت نشد.');
      }
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const ApiException('سند قابل بازیابی نیست.');
      }
      return bytes;
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<void> delete({required int id}) async {
    try {
      final response = await _dio.delete<dynamic>('${ApiEndpoints.documents}/$id');
      _requireOk(response, 'سند یافت نشد.');
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }
}
