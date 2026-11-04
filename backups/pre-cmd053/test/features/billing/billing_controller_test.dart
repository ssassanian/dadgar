/// تست کنترلر مالی — بارگذاری/خالی/خطا/تازه‌سازی
library;

import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/billing/application/billing_controller.dart';
import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Invoice _row(int id, {String status = 'pending', int amount = 1500000}) =>
    Invoice(
      id: id,
      amount: amount,
      status: status,
      createdAt: 1792701000,
      paidAt: status == 'paid' ? 1792787400 : null,
      caseId: null,
    );

Future<void> _pumpUntil(
  ProviderContainer container,
  bool Function(BillingUi) predicate,
) async {
  for (var i = 0; i < 50; i++) {
    if (predicate(container.read(billingControllerProvider))) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('شرط ظرف ۵۰ پمپ برقرار نشد');
}

void main() {
  group('BillingController — فهرست فاکتورها', () {
    test('بارگذاری اول: ردیف‌ها + today_d + شمارنده‌ها', () async {
      final repo = FakeBillingRepository(
        response: InvoicesResponse(
          rows: [_row(1), _row(2), _row(3, status: 'paid', amount: 25000000)],
          todayD: 8,
        ),
      );
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      container.read(billingControllerProvider.notifier);
      await _pumpUntil(container, (ui) => ui.status == LoadStatus.ready);

      final ui = container.read(billingControllerProvider);
      expect(ui.rows, hasLength(3));
      expect(ui.todayD, 8);
      expect(ui.pendingCount, 2);
      expect(ui.paidTotal, 25000000);
      expect(repo.calls, 1);
    });

    test('پاسخ خالی → آماده با صفر ردیف (خالی صادقانه در UI)', () async {
      final repo = FakeBillingRepository();
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      container.read(billingControllerProvider.notifier);
      await _pumpUntil(container, (ui) => ui.status == LoadStatus.ready);

      final ui = container.read(billingControllerProvider);
      expect(ui.rows, isEmpty);
      expect(ui.isError, isFalse);
    });

    test('خطای ۴۰۱ → پیام صادقانه‌ی D-6 (نه پیام فنی)', () async {
      final repo = FakeBillingRepository(
        failWith: const ApiException('unauthorized', statusCode: 401),
      );
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      container.read(billingControllerProvider.notifier);
      await _pumpUntil(container, (ui) => ui.status == LoadStatus.error);

      final ui = container.read(billingControllerProvider);
      expect(ui.isError, isTrue);
      expect(ui.message, contains('D-6'));
    });

    test('خطای ۴۰۳ وکیل → پیام فارسی سرور عیناً', () async {
      final repo = FakeBillingRepository(
        failWith: const ApiException('دسترسی ندارید.', statusCode: 403),
      );
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      container.read(billingControllerProvider.notifier);
      await _pumpUntil(container, (ui) => ui.status == LoadStatus.error);

      expect(container.read(billingControllerProvider).message,
          'دسترسی ندارید.');
    });

    test('reload: دوباره بارگذاری می‌کند و خطا پاک می‌شود', () async {
      final repo = FakeBillingRepository(
        failWith: const ApiException('unauthorized', statusCode: 401),
      );
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      final controller = container.read(billingControllerProvider.notifier);
      await _pumpUntil(container, (ui) => ui.status == LoadStatus.error);

      // رفع خطا در فیک → تلاش دوباره موفق
      repo.failWith = null;
      repo.response = InvoicesResponse(rows: [_row(9)], todayD: 3);
      await controller.reload();

      final ui = container.read(billingControllerProvider);
      expect(ui.status, LoadStatus.ready);
      expect(ui.rows.single.id, 9);
      expect(ui.isError, isFalse);
      expect(repo.calls, 2);
    });
  });
}
