/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// تست ویجت صفحه‌ی «فاکتورها» برای درخت ویجت نسل S — پوشش رفتاری عین نسل
/// قبل: پنل بدهی واقعی، کارت ردیف با قرص وضعیت (پرداخت‌شده=سبز،
/// در انتظار=کهربایی)، دکمه‌ی درگاه با پیام صادقانه‌ی 503، PDF، خالی
/// صادقانه و خطاهای ۴۰۱/۴۰۳ عین سرور.
///
/// پمپ: DsRing/اسکلت انیمیشن بی‌پایان ندارند اما برای یکدستی همه‌جا
/// tester.pump(Duration) به‌جای pumpAndSettle به کار می‌رود.
library;

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/design/tokens.dart';
import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:dadgar_mobile/features/billing/presentation/invoices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      child: MaterialApp(
        theme: Ds.lightTheme(),
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const InvoicesScreen(),
      ),
    ),
  );
  // بارگذاری کنترلر (microtask + مخزن فیک) — پمپ محدود، بدون pumpAndSettle
  await tester.pump(const Duration(milliseconds: 60));
  await tester.pump(const Duration(milliseconds: 60));
}

void main() {
  group('InvoicesScreen — نسل S: فهرست فاکتورها', () {
    testWidgets('کارت پرداخت‌شده: پنل بدهی صفر + قرص سبز + مبلغ/پرداخت + PDF',
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

      await _pumpApp(tester, container);

      // پنل بدهی فعلی — صفر (همه پرداخت‌شده)
      expect(find.text('بدهی فعلی'), findsOneWidget);
      expect(find.text('۰'), findsOneWidget);
      expect(find.text('تومان'), findsOneWidget);
      expect(find.text('همه‌ی فاکتورها پرداخت شده‌اند'), findsOneWidget);
      // کارت ردیف — عنوان + مبلغ واقعی + قرص سبز + ردیف تاریخ پرداخت
      expect(find.text('فاکتور ۱۲'), findsOneWidget);
      expect(find.text('۲۵٬۰۰۰٬۰۰۰ تومان'), findsOneWidget);
      expect(find.text('پرداخت‌شده'), findsOneWidget);
      expect(find.text('پرداخت'), findsOneWidget); // برچسب ردیف DsKvRow
      expect(find.textContaining('/'), findsOneWidget); // تاریخ شمسی
      // شمارنده‌ی DsTopBar
      expect(find.text('۱ فاکتور'), findsOneWidget);
      // PDF (M6) هست؛ دکمه‌ی درگاه نیست
      expect(find.byTooltip('PDF فاکتور'), findsOneWidget);
      expect(find.text('پرداخت آنلاین'), findsNothing);

      // راستا: فارسی RTL — الزام DOC-04 §۷
      final BuildContext titleContext = tester.element(
        find.text('فاکتورها'),
      );
      expect(Directionality.of(titleContext), TextDirection.rtl);
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

      await _pumpApp(tester, container);

      // رقم قهرمان از داده‌ی واقعی (ارقام فارسی بی‌جداکننده — عین نسل قبل)
      // + قرص کهربایی + ردیف صدور (S-4)
      expect(find.text('۱۵۰۰۰۰۰'), findsOneWidget);
      expect(find.text('۱٬۵۰۰٬۰۰۰ تومان'), findsOneWidget); // ردیف مبلغ
      expect(find.text('از ۱ فاکتور پرداخت‌نشده'), findsOneWidget);
      expect(find.text('در انتظار'), findsOneWidget);
      expect(find.text('صدور'), findsOneWidget);
      expect(find.text('پرداخت'), findsNothing); // ردیف پرداخت فقط برای paid
      expect(find.text('پرداخت آنلاین'), findsOneWidget);
      // ردیف pending هم PDF (M6) دارد
      expect(find.byTooltip('PDF فاکتور'), findsOneWidget);

      await tester.tap(find.text('پرداخت آنلاین'));
      await tester.pump(); // شروع انیمیشن SnackBar

      expect(
        find.text(
          'درگاه پرداخت هنوز متصل نشده است؛ پس از تصمیم مدیر فعال می‌شود.',
        ),
        findsOneWidget,
      );
      // قرارداد عین نسل قبل: درخواست پرداخت به سرور با شناسه‌ی فاکتور
      expect(repo.requestPaymentArgs.single, 13);
    });

    testWidgets('خالی صادقانه — عین متن وب CMD-005', (tester) async {
      final container =
          dadgarContainer(billingRepository: FakeBillingRepository());
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

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

      await _pumpApp(tester, container);

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

      await _pumpApp(tester, container);

      expect(find.text('دسترسی ندارید.'), findsOneWidget);
    });
  });
}
