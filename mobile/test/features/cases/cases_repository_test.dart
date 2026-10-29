/// تست مخزن پرونده‌ها — قرارداد GET/GET:id/POST سرور با آداپتور فیک dio
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/core/secure/token_store.dart';
import 'package:dadgar_mobile/features/cases/data/cases_repository.dart';
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
  group('DioCasesRepository — قرارداد سرور CMD-003', () {
    test('fetchPage: مسیر + پارامتر page + تجزیه‌ی کامل ردیف', () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(200, {
          'ok': true,
          'rows': [
            {
              'id': 7,
              'title': 'اختلاف بر سر مبیع',
              'category': 'ملکی',
              'status': 'running',
              'created_at': 1792701000,
              'updated_at': 1792787400,
              'final_price': 25000000,
              'client_id': 3,
              'lawyer_id': 9,
              'lawyer_name': 'دکتر رحیمی',
            },
          ],
          'page': 2,
          'pages': 5,
          'total': 42,
        });
      });
      final repo = DioCasesRepository(client: _clientWith(adapter));

      final page = await repo.fetchPage(page: 2);

      expect(captured!.path, '/api/cases');
      expect(captured!.method, 'GET');
      expect(captured!.queryParameters['page'], '2');
      expect(page.rows, hasLength(1));
      final row = page.rows.single;
      expect(row.id, 7);
      expect(row.title, 'اختلاف بر سر مبیع');
      expect(row.category, 'ملکی');
      expect(row.statusValue.labelFa, 'در حال انجام');
      expect(row.finalPrice, 25000000);
      expect(row.lawyerName, 'دکتر رحیمی');
      expect(page.page, 2);
      expect(page.pages, 5);
      expect(page.total, 42);
    });

    test('fetchDetail: مسیر /api/cases/:id + توضیحات کامل موکل', () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(200, {
          'ok': true,
          'id': 7,
          'title': 'اختلاف بر سر مبیع',
          'category': 'ملکی',
          'status': 'assigned',
          'created_at': 1792701000,
          'updated_at': 1792787400,
          'final_price': null,
          'lawyer_name': 'دکتر رحیمی',
          'description': 'شرح کامل ماجرا برای مالک پرونده',
        });
      });
      final repo = DioCasesRepository(client: _clientWith(adapter));

      final detail = await repo.fetchDetail(id: 7);

      expect(captured!.path, '/api/cases/7');
      expect(detail.statusValue.labelFa, 'تخصیص‌یافته');
      expect(detail.description, 'شرح کامل ماجرا برای مالک پرونده');
      expect(detail.finalPrice, isNull);
    });

    test('fetchDetail: ۴۰۴ ضدافشا → پیام فارسی سرور حفظ می‌شود', () async {
      final adapter = _FakeAdapter(
        (_) => _json(404, {'error': 'پرونده یافت نشد.'}),
      );
      final repo = DioCasesRepository(client: _clientWith(adapter));

      await expectLater(
        repo.fetchDetail(id: 999),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'پرونده یافت نشد.')
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('create: POST با سه فیلد قرارداد → شناسه‌ی پرونده', () async {
      RequestOptions? captured;
      Object? body;
      final adapter = _FakeAdapter((options) {
        captured = options;
        // dio در سطح آداپتور داده را رشته‌ی JSON می‌کند (Map هم محتمل است)
        final raw = options.data;
        body = raw is String ? jsonDecode(raw) : raw;
        return _json(200, {'ok': true, 'id': 55});
      });
      final repo = DioCasesRepository(client: _clientWith(adapter));

      final id = await repo.create(
        category: 'ارث و وصیت',
        title: 'درخواست تنظیم وصیت‌نامه',
        description: 'شرح ماجرا',
      );

      expect(captured!.path, '/api/cases');
      expect(captured!.method, 'POST');
      expect((body as Map)['category'], 'ارث و وصیت');
      expect((body as Map)['title'], 'درخواست تنظیم وصیت‌نامه');
      expect(id, 55);
    });

    test('create: ۴۲۹ سقف نرخ → پیام فارسی سرور عیناً', () async {
      final adapter = _FakeAdapter(
        (_) => _json(429, {
          'error':
              'سقف ثبت پرونده در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
        }),
      );
      final repo = DioCasesRepository(client: _clientWith(adapter));

      await expectLater(
        repo.create(category: 'ملکی', title: 'عنوان درست', description: ''),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'سقف ثبت پرونده در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
          ),
        ),
      );
    });

    test('401 → ApiException با کد ۴۰۱ (تا حکم D-6)', () async {
      final adapter = _FakeAdapter((_) => _json(401, {'error': 'unauthorized'}));
      final repo = DioCasesRepository(client: _clientWith(adapter));

      await expectLater(
        repo.fetchPage(page: 1),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });
}
