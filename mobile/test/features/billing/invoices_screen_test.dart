/// تست ویجت صفحه‌ی فاکتورها — فهرست، خالی صادقانه، خطا، دکمه‌ی درگاه
library;

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:dadgar_mobile/features/billing/presentation/invoices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
  Widget child,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('InvoicesScreen — فهرست فاکتورها', () {
    testWidgets('کارت فاکتور: مبلغ فارسی + وضعیت + تاریخ شمسی رندر می‌شود',
        (tester) async {
      final repo = FakeBillingRepository(
        response: InvoicesResponse(
          todayD: 8,
          rows: const [
            Invoice(
              id: 12,
              amount: 25000000,
              status: 'paid',
              createdAt: 1792701000,
              paidAt: 1792787400,
              caseId: 7,
            ),
          ],
        ),
      );
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const InvoicesScreen());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('۲۵٬۰۰۰٬۰۰۰ تومان'), findsOneWidget);
      expect(find.text('پرداخت‌شده'), findsOneWidget);
      expect(find.text('فاکتور ۱۲'), findsOneWidget);
      expect(find.text('۱ فاکتور'), findsOneWidget);
      // پرداخت‌شده: دکمه‌ی درگاه ندارد
      expect(find.text('پرداخت آنلاین'), findsNothing);
    });

    testWidgets('فاکتور در انتظار → دکمه‌ی پرداخت آنلاین + پیام صادقانه‌ی درگاه',
        (tester) async {
      final repo = FakeBillingRepository(
        response: InvoicesResponse(
          todayD: 8,
          rows: const [
            Invoice(
              id: 13,
              amount: 1500000,
              status: 'pending',
              createdAt: 1792701000,
              paidAt: null,
              caseId: null,
            ),
          ],
        ),
      );
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const InvoicesScreen());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('در انتظار'), findsOneWidget);
      expect(find.text('۱ فاکتور • ۱ در انتظار'), findsOneWidget);
      expect(find.text('پرداخت آنلاین'), findsOneWidget);

      await tester.tap(find.text('پرداخت آنلاین'));
      await tester.pump(); // شروع انیمیشن SnackBar

      expect(
        find.text(
          'درگاه پرداخت هنوز متصل نشده است؛ پس از تصمیم مدیر فعال می‌شود.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('خالی صادقانه — عین متن وب CMD-005', (tester) async {
      final container = dadgarContainer(billingRepository: FakeBillingRepository());
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const InvoicesScreen());
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text('هنوز فاکتوری برای شما صادر نشده است.'),
        findsOneWidget,
      );
    });

    testWidgets('خطای ۴۰۱ → پیام صادقانه‌ی D-6 + تلاش دوباره', (tester) async {
      final container = dadgarContainer(
        billingRepository: FakeBillingRepository(
          failWith: const ApiException('unauthorized', statusCode: 401),
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const InvoicesScreen());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('D-6'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
    });

    testWidgets('۴۰۳ وکیل → پیام فارسی سرور عیناً', (tester) async {
      final container = dadgarContainer(
        billingRepository: FakeBillingRepository(
          failWith: const ApiException('دسترسی ندارید.', statusCode: 403),
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const InvoicesScreen());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('دسترسی ندارید.'), findsOneWidget);
    });
  });
}
