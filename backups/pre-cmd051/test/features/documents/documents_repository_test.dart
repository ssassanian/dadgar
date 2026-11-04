/// تست قرارداد و مخزن اسناد — CMD-008 با آداپتور فیک dio
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/core/secure/token_store.dart';
import 'package:dadgar_mobile/features/documents/data/documents_contract.dart';
import 'package:dadgar_mobile/features/documents/data/documents_repository.dart';
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
  group('DocumentsContract — آینه‌ی CMD-008', () {
    test('ثابت‌های سرور عیناً', () {
      expect(DocumentsContract.docLimit, 300);
      expect(DocumentsContract.docMaxBytes, 4 * 1024 * 1024);
      expect(DocumentsContract.nameMax, 200);
      expect(DocumentsContract.emptyFile, 'فایل سند خالی است.');
      expect(
        DocumentsContract.uploadRateLimit,
        'سقف بارگذاری سند در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
      );
      expect(DocumentsContract.sharedLabel, 'اشتراک با وکیل');
      expect(DocumentsContract.privateLabel, 'محرمانه');
    });

    test('formatSize: واحد انسانی با ارقام فارسی', () {
      expect(DocumentsContract.formatSize(512), '۵۱۲ بایت');
      expect(DocumentsContract.formatSize(2048), '۲ کیلوبایت');
      expect(DocumentsContract.formatSize(1048576), '۱٫۰ مگابایت'
          .replaceAll('٫', '.'), ); // 1.0 با نقطه/ممیز محلی — فقط وجود واحد
      expect(
        DocumentsContract.formatSize(4 * 1024 * 1024).contains('مگابایت'),
        isTrue,
      );
    });
  });

  group('DioDocumentsRepository — قرارداد سرور CMD-008', () {
    test('fetchDocuments: مسیر + تجزیه‌ی ردیف با mine/shared سرور',
        () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(200, {
          'ok': true,
          'rows': [
            {
              'id': 21,
              'case_id': 7,
              'case_title': 'اختلاف بر سر مبیع',
              'name': 'قرارداد.jpg',
              'mime': 'image/jpeg',
              'size': 245760,
              'mine': true,
              'shared': true,
              'created_at': 1792701000,
            },
          ],
        });
      });
      final repo = DioDocumentsRepository(client: _clientWith(adapter));

      final rows = await repo.fetchDocuments();

      expect(captured!.path, '/api/documents');
      final d = rows.single;
      expect(d.id, 21);
      expect(d.name, 'قرارداد.jpg');
      expect(d.mine, isTrue);
      expect(d.shared, isTrue);
      expect(d.size, 245760);
    });

    test('upload: بدنه‌ی خام + هدر x-file-name (URL-encoded) + content-type',
        () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(200, {'ok': true, 'id': 55});
      });
      final repo = DioDocumentsRepository(client: _clientWith(adapter));

      final id = await repo.upload(
        caseId: 7,
        name: 'اسناد پرونده.png',
        mime: 'image/png',
        bytes: [1, 2, 3],
      );

      expect(captured!.path, '/api/cases/7/documents');
      expect(captured!.method, 'POST');
      expect(
        captured!.headers['x-file-name'],
        Uri.encodeComponent('اسناد پرونده.png'),
      );
      expect(captured!.headers['Content-Type'], 'image/png');
      expect(id, 55);
    });

    test('upload: ۴۲۹ سقف نرخ → پیام فارسی سرور عیناً', () async {
      final adapter = _FakeAdapter(
        (_) => _json(429, {
          'error':
              'سقف بارگذاری سند در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
        }),
      );
      final repo = DioDocumentsRepository(client: _clientWith(adapter));

      await expectLater(
        repo.upload(
          caseId: 7,
          name: 'x.jpg',
          mime: 'image/jpeg',
          bytes: [1],
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'سقف بارگذاری سند در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
          ),
        ),
      );
    });

    test('download: بایت‌به‌بایت + ۴۰۴ ضدافشا', () async {
      final adapter = _FakeAdapter(
        (options) => options.path.endsWith('/api/documents/21/file')
            ? ResponseBody.fromBytes([9, 8, 7], 200)
            : _json(404, {'error': 'سند یافت نشد.'}),
      );
      final repo = DioDocumentsRepository(client: _clientWith(adapter));

      final bytes = await repo.download(id: 21);
      expect(bytes, [9, 8, 7]);

      await expectLater(
        repo.download(id: 99),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'سند یافت نشد.')
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('delete: مسیر DELETE + ۴۰۴ ضدافشا برای سند غیر خودی', () async {
      var status = 200;
      final adapter = _FakeAdapter(
        (options) => status == 200
            ? _json(200, {'ok': true})
            : _json(404, {'error': 'سند یافت نشد.'}),
      );
      final repo = DioDocumentsRepository(client: _clientWith(adapter));

      await repo.delete(id: 21);

      status = 404;
      await expectLater(
        repo.delete(id: 99),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'سند یافت نشد.')
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('401 → ApiException با کد ۴۰۱ (تا حکم D-6)', () async {
      final adapter = _FakeAdapter((_) => _json(401, {'error': 'no'}));
      final repo = DioDocumentsRepository(client: _clientWith(adapter));

      await expectLater(
        repo.fetchDocuments(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });
}
