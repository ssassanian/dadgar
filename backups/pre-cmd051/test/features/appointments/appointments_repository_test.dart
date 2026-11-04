import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/core/secure/token_store.dart';
import 'package:dadgar_mobile/features/appointments/data/appointments_repository.dart';
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
  group('DioAppointmentsRepository — قرارداد GET/POST/PATCH سرور', () {
    test('fetch: مسیر درست + تجزیه‌ی کامل صفحه', () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(200, {
          'ok': true,
          'now': 1792701000,
          'today_d': 7,
          'rows': [
            {
              'id': 11,
              'starts_at': 1792787400,
              'day': 2,
              'slot': '۰۹:۰۰',
              'kind': 'حضوری',
              'status': 'booked',
              'created_at': 1792701000,
            },
          ],
          'taken': [
            {'d': 2, 'j': '۰۹:۰۰'},
            {'d': 2, 'j': '۱۲:۰۰'},
          ],
        });
      });
      final repo =
          DioAppointmentsRepository(client: _clientWith(adapter));

      final page = await repo.fetch();

      expect(captured!.path, '/api/appointments');
      expect(captured!.method, 'GET');
      expect(page.rows, hasLength(1));
      expect(page.rows.first.id, 11);
      expect(page.rows.first.day, 2);
      expect(page.rows.first.slot, '۰۹:۰۰');
      expect(page.rows.first.kind, 'حضوری');
      expect(page.rows.first.status, 'booked');
      expect(page.serverNowSeconds, 1792701000);
      expect(page.todayDay, 7);
      expect(page.taken, {'2:۰۹:۰۰', '2:۱۲:۰۰'});
    });

    test('fetch: 401 → پیام صادقانه‌ی وضعیت ۴۰۱ برای کنترلر', () async {
      final repo = DioAppointmentsRepository(
        client: _clientWith(
          _FakeAdapter((options) => _json(401, {'error': 'ورود لازم است'})),
        ),
      );
      expect(
        () => repo.fetch(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'ورود لازم است'),
        ),
      );
    });

    test('book: مسیر/بدنه درست + خواندن شناسه', () async {
      final captured = <RequestOptions>[];
      final repo = DioAppointmentsRepository(
        client: _clientWith(_FakeAdapter((options) {
          captured.add(options);
          if (options.method == 'POST') {
            return _json(200, <String, Object?>{'ok': true, 'id': 42});
          }
          return _json(200, <String, Object?>{
            'ok': true,
            'rows': <Object?>[],
            'taken': <Object?>[],
          });
        })),
      );

      final id = await repo.book(day: 10, slot: '۱۶:۰۰', kind: 'آنلاین');

      expect(id, 42);
      final post = captured.firstWhere((o) => o.method == 'POST');
      expect(post.path, '/api/appointments');
      expect(post.data, {'day': 10, 'slot': '۱۶:۰۰', 'kind': 'آنلاین'});
    });

    test('book: ۴۰۹ بازه‌ی پر → پیام فارسی سرور حفظ می‌شود', () async {
      final repo = DioAppointmentsRepository(
        client: _clientWith(_FakeAdapter(
          (options) => _json(409, {'error': 'این بازه قبلاً رزرو شده است؛ بازه‌ی دیگری انتخاب کنید.'}),
        )),
      );
      expect(
        () => repo.book(day: 3, slot: '۰۹:۰۰', kind: 'حضوری'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message',
                  'این بازه قبلاً رزرو شده است؛ بازه‌ی دیگری انتخاب کنید.'),
        ),
      );
    });

    test('updateStatus: PATCH با بدنه‌ی وضعیت', () async {
      final captured = <RequestOptions>[];
      final repo = DioAppointmentsRepository(
        client: _clientWith(_FakeAdapter((options) {
          captured.add(options);
          return _json(200, {'ok': true});
        })),
      );

      await repo.updateStatus(id: 11, status: 'canceled');

      final patch = captured.single;
      expect(patch.method, 'PATCH');
      expect(patch.path, '/api/appointments/11');
      expect(patch.data, {'status': 'canceled'});
    });
  });
}
