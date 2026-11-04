/// لایه‌ی data پیام/تیکت — M5 (DOC-04 §۱۱ ردیف M5)
///
/// مسیرهای «موجود» سرور از CMD-007 هستند (S-4):
///   GET  /api/tickets              فهرست تیکت‌های خود (سقف ۲۰۰)
///   POST /api/tickets              ساخت تیکت {subject, dept, priority, body}
///   GET  /api/tickets/:id          جزئیات + پیام‌ها (۴۰۴ ضدافشا)
///   POST /api/tickets/:id/replies  پاسخ {body} — تیکت بسته 400
///   GET  /api/threads              گفتگوهای پرونده‌های تخصیص‌یافته (سقف ۵۰)
///   GET  /api/messages?case_id=N   پیام‌های یک گفتگو (سقف ۳۰۰)
///   POST /api/messages             ارسال پیام {case_id, body}
///
/// احراز هویت با Bearer (interceptor مشترک ApiClient) — پذیرش سمت سرور
/// منوط به حکم مدیر بر D-6 است.
library;

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../domain/chat_models.dart';
import '../domain/ticket_models.dart';

abstract interface class MessagesRepository {
  Future<List<TicketSummary>> fetchTickets();

  /// ساخت تیکت → شناسه‌ی جدید (۴۲۹ = سقف نرخ سرور)
  Future<int> createTicket({
    required String subject,
    required String dept,
    required String priority,
    required String body,
  });

  /// جزئیات + پیام‌ها — ۴۰۴ ضدافشا حفظ می‌شود
  Future<TicketDetail> fetchTicket({required int id});

  /// پاسخ به تیکت → وضعیت جدید سرور (answered/open/…)
  Future<String> replyTicket({required int id, required String body});

  Future<List<Thread>> fetchThreads();

  Future<ChatEnvelope> fetchMessages({required int caseId});

  Future<int> sendMessage({required int caseId, required String body});
}

final class DioMessagesRepository implements MessagesRepository {
  DioMessagesRepository({required ApiClient client}) : _client = client;

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

  List<T> _rowsOf<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return (json['rows'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<TicketSummary>> fetchTickets() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.tickets);
      _requireOk(response, 'دریافت تیکت‌ها ناموفق بود');
      return _rowsOf(_requireMap(response), TicketSummary.fromJson);
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<int> createTicket({
    required String subject,
    required String dept,
    required String priority,
    required String body,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.tickets,
        data: {
          'subject': subject,
          'dept': dept,
          'priority': priority,
          'body': body,
        },
      );
      _requireOk(response, 'ثبت تیکت ناموفق بود');
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
  Future<TicketDetail> fetchTicket({required int id}) async {
    try {
      final response = await _dio.get<dynamic>('${ApiEndpoints.tickets}/$id');
      _requireOk(response, 'تیکت یافت نشد.');
      return TicketDetail.fromJson(_requireMap(response));
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<String> replyTicket({required int id, required String body}) async {
    try {
      final response = await _dio.post<dynamic>(
        '${ApiEndpoints.tickets}/$id/replies',
        data: {'body': body},
      );
      _requireOk(response, 'ارسال پاسخ ناموفق بود');
      final data = _requireMap(response);
      return data['status'] as String? ?? '';
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<List<Thread>> fetchThreads() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.threads);
      _requireOk(response, 'دریافت گفتگوها ناموفق بود');
      return _rowsOf(_requireMap(response), Thread.fromJson);
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<ChatEnvelope> fetchMessages({required int caseId}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.messages,
        queryParameters: {'case_id': '$caseId'},
      );
      _requireOk(response, 'پرونده یافت نشد.');
      return ChatEnvelope.fromJson(_requireMap(response));
    } on ApiException {
      rethrow;
    } on Object catch (e) {
      throw ApiException.from(e);
    }
  }

  @override
  Future<int> sendMessage({required int caseId, required String body}) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.messages,
        data: {'case_id': caseId, 'body': body},
      );
      _requireOk(response, 'ارسال پیام ناموفق بود');
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
}
