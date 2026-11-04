/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// تست ویجت صفحه‌ی «مدیریت مالی» برای درخت ویجت نسل S — پوشش رفتاری عین
/// نسل قبل (کارت مدیر با نام مشتری/وکیل، دیالوگ تایید ثبت پرداخت → PATCH،
/// بازکردن، خالی صادقانه، ۴۰۳ عین سرور) + گیت شیت صدور فاکتور (اعتبارسنجی
/// مشتری/مبلغ و صدور موفق).
///
/// پمپ: DsRing بی‌پایان است (حالت بارگذاری/کار) → همه‌جا
/// tester.pump(Duration)؛ pumpAndSettle به‌کار نمی‌رود.
library;

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/design/ds_kit.dart';
import 'package:dadgar_mobile/design/tokens.dart';
import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:dadgar_mobile/features/billing/presentation/admin_billing_screen.dart';
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
        home: const AdminBillingScreen(),
      ),
    ),
  );
  // بارگذاری کنترلر — پمپ محدود (DsRing بی‌پایان است؛ pumpAndSettle ممنوع)
  await tester.pump(const Duration(milliseconds: 60));
  await tester.pump(const Duration(milliseconds: 60));
}

FakeBillingRepository _repoWith(List<Invoice> rows) => FakeBillingRepository(
      response: InvoicesResponse(todayD: 8, rows: rows),
    );

void main() {
  group('AdminBillingScreen — نسل S: فهرست مدیریتی', () {
    testWidgets('کارت در انتظار: نام مشتری + مبلغ/تاریخ + قرص + دکمه‌ی ثبت',
        (tester) async {
      final repo = _repoWith(const [
        Invoice(
          id: 19,
          amount: 5000000,
          status: 'pending',
          createdAt: 1792701000,
          paidAt: null,
          caseId: null,
          clientName: 'مشتری تست چرخه',
        ),
      ]);
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('مدیریت مالی'), findsOneWidget); // DsTopBar
      expect(find.text('مشتری تست چرخه'), findsOneWidget);
      expect(find.text('۵٬۰۰۰٬۰۰۰ تومان'), findsOneWidget);
      expect(find.text('در انتظار'), findsOneWidget); // قرص کهربایی
      expect(find.text('فاکتور ۱۹'), findsOneWidget);
      expect(find.text('صدور'), findsOneWidget);
      expect(find.text('پرداخت'), findsNothing);
      expect(find.text('ثبت پرداخت'), findsOneWidget);
      expect(find.text('صدور فاکتور'), findsOneWidget); // FAB

      // راستا: فارسی RTL — الزام DOC-04 §۷
      final BuildContext titleContext = tester.element(
        find.text('مدیریت مالی'),
      );
      expect(Directionality.of(titleContext), TextDirection.rtl);
    });

    testWidgets('ثبت پرداخت → دیالوگ تایید → PATCH و پیام موفقیت',
        (tester) async {
      final repo = _repoWith(const [
        Invoice(
          id: 19,
          amount: 5000000,
          status: 'pending',
          createdAt: 1792701000,
          paidAt: null,
          caseId: null,
          clientName: 'مشتری تست چرخه',
        ),
      ]);
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      await tester.tap(find.text('ثبت پرداخت'));
      await tester.pump(const Duration(milliseconds: 300)); // انیمیشن دیالوگ

      expect(find.text('پرداخت فاکتور ۱۹ به مبلغ ۵٬۰۰۰٬۰۰۰ تومان ثبت شود؟'),
          findsOneWidget);

      await tester.tap(find.text('ثبت پرداخت').last);
      // بستن دیالوگ + busy → بارگذاری (DsRing) → ready + پیام — بدون settle
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.statusArgs.single, (id: 19, status: 'paid'));
      expect(
        find.text('پرداخت ثبت شد.'),
        findsOneWidget,
      ); // SnackBar یکدست عین نسل قبل
    });

    testWidgets('فاکتور پرداخت‌شده: نام وکیل + ردیف پرداخت + دکمه‌ی بازکردن',
        (tester) async {
      final repo = _repoWith(const [
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
      ]);
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('وکیل پرونده: وکیل تست چرخه'), findsOneWidget);
      expect(find.text('پرداخت‌شده'), findsOneWidget);
      expect(find.text('پرداخت'), findsOneWidget); // ردیف DsKvRow
      expect(find.text('بازکردن'), findsOneWidget);
      expect(find.text('ثبت پرداخت'), findsNothing);
    });

    testWidgets('فهرست خالی → پیام صادقانه عین وب', (tester) async {
      final container =
          dadgarContainer(billingRepository: FakeBillingRepository());
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

    testWidgets('شیت صدور فاکتور: اعتبارسنجی + صدور موفق (قرارداد CMD-005)',
        (tester) async {
      final repo = FakeBillingRepository(
        response: const InvoicesResponse(rows: [], todayD: 8),
      )
        ..clients = const [MinUser(id: 7, name: 'مشتری تست')];
      final container = dadgarContainer(billingRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 400)); // انیمیشن شیت
      await tester.pump(const Duration(milliseconds: 200)); // گرفتن مشتری‌ها

      expect(find.text('صدور فاکتور دستی'), findsOneWidget);

      // بدون انتخاب مشتری → خطای فارسی (عین نسل قبل)
      await tester.tap(find.widgetWithText(DsButton, 'صدور فاکتور'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('مشتری را انتخاب کنید'), findsOneWidget);

      // انتخاب مشتری + مبلغ معتبر با ارقام فارسی و جداکننده
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pump(const Duration(milliseconds: 400)); // منوی دراپ‌داون
      await tester.tap(find.text('مشتری تست').last);
      await tester.pump(const Duration(milliseconds: 300)); // بستن منو
      await tester.enterText(find.byType(TextFormField), '۲۵٬۰۰۰٬۰۰۰');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.widgetWithText(DsButton, 'صدور فاکتور'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      // انیمیشن خروج شیت هم باید تا پایان پمپ شود (الگوی ۴۰۰ms)
      await tester.pump(const Duration(milliseconds: 400));

      expect(repo.issueArgs.single, (clientId: 7, amount: 25000000));
      expect(find.text('صدور فاکتور دستی'), findsNothing); // شیت بسته شد
    });
  });
}
