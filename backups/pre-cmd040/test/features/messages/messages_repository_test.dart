/// تست مخزن پیام/تیکت — قرارداد هفت مسیر CMD-007 با آداپتور فیک dio
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/core/secure/token_store.dart';
import 'package:dadgar_mobile/features/messages/data/messages_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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
  group('DioMessagesRepository — قرارداد سرور CMD-007', () {
    test('fetchTickets: مسیر + تجزیه‌ی ردیف (نام فقط مدیر — مشتری ندارد)',
        () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(200, {
          'ok': true,
          'rows': [
            {
              'id': 5,
              'subject': 'مشکل در ورود',
              'dept': 'فنی',
              'priority': 'بالا',
              'status': 'answered',
              'created_at': 1792701000,
              'updated_at': 1792787400,
              'msg_count': 3,
            },
          ],
        });
      });
      final repo = DioMessagesRepository(client: _clientWith(adapter));

      final rows = await repo.fetchTickets();

      expect(captured!.path, '/api/tickets');
      expect(rows.single.id, 5);
      expect(rows.single.statusValue.labelFa, 'پاسخ داده‌شده');
      expect(rows.single.msgCount, 3);
    });

    test('createTicket: POST با چهار فیلد قرارداد → شناسه‌ی تیکت', () async {
      RequestOptions? captured;
      Object? body;
      final adapter = _FakeAdapter((options) {
        captured = options;
        final raw = options.data;
        body = raw is String ? jsonDecode(raw) : raw;
        return _json(200, {'ok': true, 'id': 31});
      });
      final repo = DioMessagesRepository(client: _clientWith(adapter));

      final id = await repo.createTicket(
        subject: 'درخواست اصلاح فاکتور',
        dept: 'مالی',
        priority: 'متوسط',
        body: 'شرح درخواست',
      );

      expect(captured!.path, '/api/tickets');
      expect(captured!.method, 'POST');
      expect((body as Map)['dept'], 'مالی');
      expect(id, 31);
    });

    test('createTicket: ۴۲۹ سقف نرخ → پیام فارسی سرور عیناً', () async {
      final adapter = _FakeAdapter(
        (_) => _json(429, {
          'error':
              'سقف ارسال تیکت در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
        }),
      );
      final repo = DioMessagesRepository(client: _clientWith(adapter));

      await expectLater(
        repo.createTicket(
          subject: 'موضوع درست',
          dept: 'عمومی',
          priority: 'کم',
          body: 'متن درست',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'سقف ارسال تیکت در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
          ),
        ),
      );
    });

    test('fetchTicket: جزئیات + پیام‌ها با mine سرور؛ ۴۰۴ ضدافشا', () async {
      final adapter = _FakeAdapter(
        (options) => options.path.endsWith('/api/tickets/9')
            ? _json(200, {
                'ok': true,
                'ticket': {
                  'id': 9,
                  'subject': 'پیگیری نوبت',
                  'dept': 'عمومی',
                  'priority': 'کم',
                  'status': 'open',
                  'created_at': 1792701000,
                  'updated_at': 1792702000,
                  'user_name': '',
                },
                'rows': [
                  {
                    'id': 1,
                    'mine': true,
                    'role': 'client',
                    'body': 'سلام',
                    'created_at': 1792701500,
                  },
                  {
                    'id': 2,
                    'mine': false,
                    'role': 'admin',
                    'body': 'در حال بررسی است',
                    'created_at': 1792702000,
                  },
                ],
              })
            : _json(404, {'error': 'تیکت یافت نشد.'}),
      );
      final repo = DioMessagesRepository(client: _clientWith(adapter));

      final d = await repo.fetchTicket(id: 9);
      expect(d.subject, 'پیگیری نوبت');
      expect(d.messages[0].mine, isTrue);
      expect(d.messages[1].mine, isFalse);
      expect(d.messages[1].body, 'در حال بررسی است');

      await expectLater(
        repo.fetchTicket(id: 404),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'تیکت یافت نشد.')
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('replyTicket: مسیر replies + وضعیت بازگشتی سرور؛ بسته ۴۰۰ عیناً',
        () async {
      var status = 200;
      final adapter = _FakeAdapter((options) {
        if (status != 200) {
          return _json(status, {
            'error':
                'این تیکت بسته شده است؛ برای موضوع جدید تیکت جدیدی باز کنید.',
          });
        }
        return _json(200, {'ok': true, 'status': 'open'});
      });
      final repo = DioMessagesRepository(client: _clientWith(adapter));

      final st = await repo.replyTicket(id: 9, body: 'پیگیری دوباره');
      expect(st, 'open');

      status = 400;
      await expectLater(
        repo.replyTicket(id: 9, body: 'باز هم'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'این تیکت بسته شده است؛ برای موضوع جدید تیکت جدیدی باز کنید.',
          ),
        ),
      );
    });

    test('fetchThreads + fetchMessages + sendMessage: مسیرها و شکل داده',
        () async {
      final paths = <String>[];
      final adapter = _FakeAdapter((options) {
        paths.add('${options.method} ${options.path}');
        if (options.path == '/api/threads') {
          return _json(200, {
            'ok': true,
            'rows': [
              {
                'case_id': 7,
                'title': 'اختلاف بر سر مبیع',
                'category': 'ملکی',
                'status': 'assigned',
                'last_at': 1792787400,
                'last_excerpt': 'پیشنهاد شما بررسی شد',
                'last_mine': false,
              },
            ],
          });
        }
        if (options.path == '/api/messages') {
          if (options.method == 'POST') {
            return _json(200, {'ok': true, 'id': 44});
          }
          expect(options.queryParameters['case_id'], '7');
          return _json(200, {
            'ok': true,
            'case': {'id': 7, 'title': 'اختلاف بر سر مبیع', 'status': 'running'},
            'rows': [
              {
                'id': 3,
                'mine': false,
                'role': 'lawyer',
                'body': 'پیشنهاد شما بررسی شد',
                'created_at': 1792787400,
              },
            ],
          });
        }
        return _json(200, {'ok': true, 'id': 44});
      });
      final repo = DioMessagesRepository(client: _clientWith(adapter));

      final threads = await repo.fetchThreads();
      expect(threads.single.caseId, 7);
      expect(threads.single.lastExcerpt, 'پیشنهاد شما بررسی شد');

      final env = await repo.fetchMessages(caseId: 7);
      expect(env.caseTitle, 'اختلاف بر سر مبیع');
      expect(env.rows.single.mine, isFalse);

      final id = await repo.sendMessage(caseId: 7, body: 'ممنون');
      expect(id, 44);

      expect(paths, contains('GET /api/threads'));
      expect(paths, contains('GET /api/messages'));
      expect(paths, contains('POST /api/messages'));
    });

    test('sendMessage: گفتگوی غیرفعال ۴۰۰ → پیام عین سرور', () async {
      final adapter = _FakeAdapter(
        (_) => _json(400, {
          'error':
              'گفتگوی این پرونده هنوز فعال نیست؛ پس از تخصیص وکیل باز می‌شود.',
        }),
      );
      final repo = DioMessagesRepository(client: _clientWith(adapter));

      await expectLater(
        repo.sendMessage(caseId: 3, body: 'سلام'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'گفتگوی این پرونده هنوز فعال نیست؛ پس از تخصیص وکیل باز می‌شود.',
          ),
        ),
      );
    });

    test('401 → ApiException با کد ۴۰۱ (تا حکم D-6)', () async {
      final adapter = _FakeAdapter((_) => _json(401, {'error': 'no'}));
      final repo = DioMessagesRepository(client: _clientWith(adapter));

      await expectLater(
        repo.fetchTickets(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });
}
