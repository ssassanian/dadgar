/// تست M6 (CMD-028) — عملیات مدیر مالی + درخواست پرداخت (اسکلت بی‌طرف)
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/core/secure/token_store.dart';
import 'package:dadgar_mobile/features/billing/data/billing_contract.dart';
import 'package:dadgar_mobile/features/billing/data/billing_repository.dart';
import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

/// آداپتور فیک dio — الگوی همان تست M4
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
  group('DioBillingRepository — عملیات مدیر (CMD-028)', () {
    test('issueInvoice: POST /api/invoices با client_id/amount', () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(200, {'ok': true, 'id': 42});
      });
      final repo = DioBillingRepository(client: _clientWith(adapter));

      final id = await repo.issueInvoice(clientId: 7, amount: 5000000);

      expect(id, 42);
      expect(captured!.method, 'POST');
      expect(captured!.path, '/api/invoices');
      expect(captured!.data, {'client_id': 7, 'amount': 5000000});
    });

    test('issueInvoice: 429 سقف نرخ → پیام عین سرور', () async {
      final adapter = _FakeAdapter(
        (_) => _json(429, {
          'error': 'سقف صدور فاکتور در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
        }),
      );
      final repo = DioBillingRepository(client: _clientWith(adapter));

      await expectLater(
        repo.issueInvoice(clientId: 7, amount: 5000000),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message',
                  BillingContract.issueRateLimitMessage)
              .having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
    });

    test('setInvoiceStatus: PATCH /api/invoices/:id با status', () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(200, {'ok': true});
      });
      final repo = DioBillingRepository(client: _clientWith(adapter));

      await repo.setInvoiceStatus(id: 19, status: 'paid');

      expect(captured!.method, 'PATCH');
      expect(captured!.path, '/api/invoices/19');
      expect(captured!.data, {'status': 'paid'});
    });

    test('setInvoiceStatus: 400 گذار نامعتبر → پیام عین سرور', () async {
      final adapter = _FakeAdapter(
        (_) => _json(400, {'error': 'فقط فاکتور «در انتظار» قابل پرداخت است.'}),
      );
      final repo = DioBillingRepository(client: _clientWith(adapter));

      await expectLater(
        repo.setInvoiceStatus(id: 1, status: 'paid'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message',
                  BillingContract.payOnlyPendingMessage)
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('fetchClients: GET /api/users?role=client — فهرست حداقلی', () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(200, {
          'ok': true,
          'rows': [
            {'id': 271, 'name': 'مشتری تست', 'role': 'client', 'created_at': 1},
          ],
        });
      });
      final repo = DioBillingRepository(client: _clientWith(adapter));

      final clients = await repo.fetchClients();

      expect(captured!.path, '/api/users');
      expect(captured!.queryParameters['role'], 'client');
      expect(clients.single.id, 271);
      expect(clients.single.name, 'مشتری تست');
    });

    test('requestPayment: 503 → PayNotConfigured با عین پیام درگاه', () async {
      RequestOptions? captured;
      final adapter = _FakeAdapter((options) {
        captured = options;
        return _json(503, {
          'error':
              'درگاه پرداخت هنوز متصل نشده است؛ پس از تصمیم مدیر فعال می‌شود.',
        });
      });
      final repo = DioBillingRepository(client: _clientWith(adapter));

      final result = await repo.requestPayment(invoiceId: 19);

      expect(captured!.method, 'POST');
      expect(captured!.path, '/api/payments/request');
      expect(captured!.data, {'invoice_id': 19});
      expect(result, isA<PayNotConfigured>());
      expect(
        (result as PayNotConfigured).message,
        BillingContract.paymentGatewayMessage,
      );
    });

    test('requestPayment: 200 → PayUrlReady (مسیر درگاه فعال آینده)', () async {
      var launched = '';
      final adapter = _FakeAdapter((options) {
        return _json(200, {'ok': true, 'pay_url': 'https://gw.example/pay/1'});
      });
      final repo = DioBillingRepository(client: _clientWith(adapter));

      final result = await repo.requestPayment(invoiceId: 19);
      expect(result, isA<PayUrlReady>());
      launched = (result as PayUrlReady).url;
      expect(launched, 'https://gw.example/pay/1');
    });
  });

  group('BillingController — عملیات مدیر', () {
    test('issueInvoice موفق → پیام + بارگذاری دوباره', () async {
      final repo = FakeBillingRepository()
        ..issuedId = 44
        ..response = const InvoicesResponse(rows: [
          Invoice(
            id: 44,
            amount: 5000000,
            status: 'pending',
            createdAt: 1792701000,
            paidAt: null,
            caseId: null,
            clientName: 'مشتری تست',
          ),
        ], todayD: 8);
      final container = ProviderContainer(
        overrides: [billingRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final id = await container
          .read(billingControllerProvider.notifier)
          .issueInvoice(clientId: 7, amount: 5000000);

      expect(id, 44);
      expect(repo.issueArgs.single, (clientId: 7, amount: 5000000));
      expect(repo.calls, 2); // بارگذاری اولیه + بارگذاری پس از صدور
      final ui = container.read(billingControllerProvider);
      expect(ui.message, 'فاکتور صادر شد.');
      expect(ui.rows.single.clientName, 'مشتری تست');
    });

    test('setInvoiceStatus paid → پیام «پرداخت ثبت شد.» + reload', () async {
      final repo = FakeBillingRepository();
      final container = ProviderContainer(
        overrides: [billingRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(billingControllerProvider.notifier)
          .setInvoiceStatus(id: 19, status: 'paid');

      expect(ok, isTrue);
      expect(repo.statusArgs.single, (id: 19, status: 'paid'));
      expect(
        container.read(billingControllerProvider).message,
        'پرداخت ثبت شد.',
      );
    });

    test('setInvoiceStatus خطای سرور → پیام فارسی عین سرور', () async {
      final repo = FakeBillingRepository()
        ..failWith = const ApiException(
          'این فاکتور پرداخت‌نشده است؛ بازکردنی در کار نیست.',
          statusCode: 400,
        );
      final container = ProviderContainer(
        overrides: [billingRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(billingControllerProvider.notifier)
          .setInvoiceStatus(id: 1, status: 'pending');

      expect(ok, isFalse);
      expect(
        container.read(billingControllerProvider).message,
        BillingContract.reopenOnlyPaidMessage,
      );
    });

    test('requestPayment 503 → پیام صادقانه در state + نتیجه', () async {
      final repo = FakeBillingRepository(); // پیش‌فرض: PayNotConfigured
      final container = ProviderContainer(
        overrides: [billingRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(billingControllerProvider.notifier)
          .requestPayment(19);

      expect(repo.requestPaymentArgs.single, 19);
      expect(result, isA<PayNotConfigured>());
      expect(
        container.read(billingControllerProvider).message,
        BillingContract.paymentGatewayMessage,
      );
    });

    test('requestPayment با PayUrlReady → بدون پیام (لانچر در صفحه)', () async {
      final repo = FakeBillingRepository()
        ..paymentResult = const PayUrlReady('https://gw.example/pay/1');
      final container = ProviderContainer(
        overrides: [billingRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(billingControllerProvider.notifier)
          .requestPayment(19);

      expect(result, isA<PayUrlReady>());
      expect(container.read(billingControllerProvider).message, isNull);
    });
  });

  group('BillingContract — اعتبارسنجی مبلغ صدور', () {
    test('مبلغ معتبر (ارقام فارسی با جداکننده) → null', () {
      expect(
        BillingContract.validateIssueAmount('۲۵٬۰۰۰٬۰۰۰'),
        isNull,
      );
      expect(BillingContract.validateIssueAmount('1000'), isNull);
    });

    test('مبلغ نامعتبر → پیام فارسی', () {
      expect(BillingContract.validateIssueAmount('999'), isNotNull);
      expect(BillingContract.validateIssueAmount(''), isNotNull);
      expect(BillingContract.validateIssueAmount('abc'), isNotNull);
    });

    test('toEnglishDigits: فارسی/عربی/جداکننده', () {
      expect(BillingContract.toEnglishDigits('۲۵٬۰۰۰'), '25000');
      expect(BillingContract.toEnglishDigits('١٢٣'), '123');
    });
  });
}
