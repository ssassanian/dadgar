/// تست مخزن مالی — قرارداد GET /api/invoices سرور با آداپتور فیک dio
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/core/secure/token_store.dart';
import 'package:dadgar_mobile/features/billing/data/billing_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// آداپتور فیک dio — بدون هیچ شبکه‌ای؛ پاسخ‌ها جدول‌شده‌اند
final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final ResponseBody Function(RequestOptions options) responder;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return responder(options);
  }
}

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

ApiClient _clientWith(_FakeAdapter adapter) {
  final client = ApiClient(tokenStore: InMemoryTokenStore());
  client.dio.httpClientAdapter = adapter;
  return client;
}

void main() {
  group('DioBillingRepository — قرارداد سرور CMD-005', () {
    test('fetchInvoices: مسیر + متد GET + تجزیه‌ی کامل ردیف مشتری', () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(200, {
          'ok': true,
          'now': 1792701000,
          'today_d': 8,
          'rows': [
            {
              'id': 12,
              'amount': 25000000,
              'status': 'paid',
              'created_at': 1792701000,
              'paid_at': 1792787400,
              'case_id': 7,
            },
            {
              'id': 13,
              'amount': 1500000,
              'status': 'pending',
              'created_at': 1792873800,
              'paid_at': null,
              'case_id': null,
            },
          ],
        });
      });
      final repo = DioBillingRepository(client: _clientWith(adapter));

      final res = await repo.fetchInvoices();

      expect(captured!.path, '/api/invoices');
      expect(captured!.method, 'GET');
      expect(res.todayD, 8);
      expect(res.rows, hasLength(2));

      final paid = res.rows[0];
      expect(paid.id, 12);
      expect(paid.amount, 25000000);
      expect(paid.statusValue.labelFa, 'پرداخت‌شده');
      expect(paid.paidAt, 1792787400);
      expect(paid.caseId, 7);

      final pending = res.rows[1];
      expect(pending.statusValue.labelFa, 'در انتظار');
      expect(pending.paidAt, isNull);
      expect(pending.caseId, isNull); // فاکتور دستی بدون پرونده
    });

    test('نام‌های مشتری/وکیل در نمای مشتری نادیده گرفته می‌شوند (حریم خصوصی)',
        () async {
      final adapter = _FakeAdapter(
        (_) => _json(200, {
          'ok': true,
          'today_d': 5,
          'rows': [
            {
              'id': 1,
              'amount': 1000,
              'status': 'pending',
              'created_at': 1792701000,
              'paid_at': null,
              'case_id': null,
              'client_name': 'نام مشتری',
              'lawyer_name': 'نام وکیل',
            },
          ],
        }),
      );
      final repo = DioBillingRepository(client: _clientWith(adapter));

      final res = await repo.fetchInvoices();

      // مدل مشتری این فیلدها را اصلاً ندارد — قرارداد نمای مشتری
      expect(res.rows.single.amount, 1000);
    });

    test('۴۰۳ وکیل → پیام فارسی سرور عیناً حفظ می‌شود', () async {
      final adapter = _FakeAdapter(
        (_) => _json(403, {'error': 'دسترسی ندارید.'}),
      );
      final repo = DioBillingRepository(client: _clientWith(adapter));

      await expectLater(
        repo.fetchInvoices(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'دسترسی ندارید.')
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('۴۰۱ → ApiException با کد ۴۰۱ (تا حکم D-6)', () async {
      final adapter = _FakeAdapter((_) => _json(401, {'error': 'unauthorized'}));
      final repo = DioBillingRepository(client: _clientWith(adapter));

      await expectLater(
        repo.fetchInvoices(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('پاسخ غیر JSON → پیام فارسی قابل نمایش', () async {
      final adapter = _FakeAdapter(
        (_) => ResponseBody.fromString('not json', 200),
      );
      final repo = DioBillingRepository(client: _clientWith(adapter));

      await expectLater(
        repo.fetchInvoices(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
