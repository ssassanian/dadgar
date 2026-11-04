/// تست ویجت صفحه‌ی «مدیریت مالی» — M6 (CMD-028)
library;

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:dadgar_mobile/features/billing/presentation/admin_billing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AdminBillingScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('AdminBillingScreen — فهرست مدیریتی', () {
    testWidgets('کارت با نام مشتری + دکمه‌ی ثبت پرداخت برای در انتظار',
        (tester) async {
      final repo = FakeBillingRepository(
        response: InvoicesResponse(
          todayD: 8,
          rows: const [
            Invoice(
              id: 19,
              amount: 5000000,
              status: 'pending',
              createdAt: 1792701000,
              paidAt: null,
              caseId: null,
              clientName: 'مشتری تست چرخه',
            ),
          ],
        ),
      );
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('مشتری تست چرخه'), findsOneWidget);
      expect(find.text('۵٬۰۰۰٬۰۰۰ تومان'), findsOneWidget);
      expect(find.text('ثبت پرداخت'), findsOneWidget);
      expect(find.text('صدور فاکتور'), findsOneWidget); // FAB
    });

    testWidgets('ثبت پرداخت → دیالوگ تایید → PATCH و پیام موفقیت',
        (tester) async {
      final repo = FakeBillingRepository(
        response: InvoicesResponse(
          todayD: 8,
          rows: const [
            Invoice(
              id: 19,
              amount: 5000000,
              status: 'pending',
              createdAt: 1792701000,
              paidAt: null,
              caseId: null,
              clientName: 'مشتری تست چرخه',
            ),
          ],
        ),
      );
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      await tester.tap(find.text('ثبت پرداخت'));
      await tester.pumpAndSettle();

      expect(find.text('پرداخت فاکتور ۱۹ به مبلغ ۵٬۰۰۰٬۰۰۰ تومان ثبت شود؟'),
          findsOneWidget);

      await tester.tap(find.text('ثبت پرداخت').last);
      await tester.pumpAndSettle();

      expect(repo.statusArgs.single, (id: 19, status: 'paid'));
    });

    testWidgets('فاکتور پرداخت‌شده → نام وکیل + دکمه‌ی بازکردن',
        (tester) async {
      final repo = FakeBillingRepository(
        response: InvoicesResponse(
          todayD: 8,
          rows: const [
            Invoice(
              id: 20,
              amount: 7000000,
              status: 'paid',
              createdAt: 1792701000,
              paidAt: 1792787400,
              caseId: 56,
              clientName: 'مشتری تست چرخه',
              lawyerName: 'وکیل تست چرخه',
            ),
          ],
        ),
      );
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('وکیل پرونده: وکیل تست چرخه'), findsOneWidget);
      expect(find.text('بازکردن'), findsOneWidget);
      expect(find.text('ثبت پرداخت'), findsNothing);
    });

    testWidgets('فهرست خالی → پیام صادقانه عین وب', (tester) async {
      final container = dadgarContainer(billingRepository: FakeBillingRepository());
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(
        find.text('هنوز فاکتوری برای شما صادر نشده است.'),
        findsOneWidget,
      );
    });

    testWidgets('۴۰۳ (نقش غیر مدیر به هر دلیل) → پیام عین سرور',
        (tester) async {
      final container = dadgarContainer(
        billingRepository: FakeBillingRepository(
          failWith: const ApiException('دسترسی ندارید.', statusCode: 403),
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('دسترسی ندارید.'), findsOneWidget);
    });
  });
}
