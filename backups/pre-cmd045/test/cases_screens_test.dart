/// تست ویجت صفحات پرونده‌ها — فهرست، جزئیات، فرم ثبت
library;

import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/cases/domain/case_models.dart';
import 'package:dadgar_mobile/features/cases/presentation/case_detail_screen.dart';
import 'package:dadgar_mobile/features/cases/presentation/cases_screen.dart';
import 'package:dadgar_mobile/features/cases/presentation/new_case_screen.dart';
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
  group('CasesScreen — فهرست', () {
    testWidgets('ردیف‌ها با برچسب وضعیت و تاریخ فارسی رندر می‌شوند',
        (tester) async {
      final repo = FakeCasesRepository(pages: {
        1: CasesPage(
          rows: [
            const CaseSummary(
              id: 7,
              title: 'اختلاف بر سر مبیع',
              category: 'ملکی',
              status: 'running',
              createdAt: 1792701000,
              updatedAt: 1792701000,
            ),
          ],
          page: 1,
          pages: 1,
          total: 1,
        ),
      });
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(
        tester,
        container,
        const CasesScreen(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('اختلاف بر سر مبیع'), findsOneWidget);
      expect(find.text('در حال انجام'), findsOneWidget);
      expect(find.text('ملکی'), findsOneWidget);
      expect(find.text('پرونده ۷'), findsOneWidget);
      expect(find.text('۱ پرونده'), findsOneWidget);
    });

    testWidgets('خالی صادقانه — بدون داده‌ی جعلی', (tester) async {
      final container = dadgarContainer(casesRepository: FakeCasesRepository());
      addTearDown(container.dispose);

      await _pumpApp(
        tester,
        container,
        const CasesScreen(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('هنوز پرونده‌ای ثبت نکرده‌اید'), findsOneWidget);
      expect(find.text('ثبت پرونده جدید'), findsWidgets);
    });

    testWidgets('خطای ۴۰۱ → پیام صادقانه‌ی D-6 + تلاش دوباره', (tester) async {
      final container = dadgarContainer(
        casesRepository: FakeCasesRepository(
          failWith: const ApiException('unauthorized', statusCode: 401),
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(
        tester,
        container,
        const CasesScreen(),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('D-6'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
    });
  });

  group('CaseDetailScreen — جزئیات', () {
    testWidgets('عنوان، وضعیت، وکیل و توضیحات نمایش داده می‌شود',
        (tester) async {
      final repo = FakeCasesRepository(details: {
        7: const CaseDetail(
          id: 7,
          title: 'اختلاف بر سر مبیع',
          category: 'ملکی',
          status: 'assigned',
          createdAt: 1792701000,
          updatedAt: 1792787400,
          finalPrice: 25000000,
          lawyerName: 'دکتر رحیمی',
          description: 'شرح کامل ماجرا',
        ),
      });
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(
        tester,
        container,
        const CaseDetailScreen(caseId: 7),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('اختلاف بر سر مبیع'), findsOneWidget);
      // وضعیت در سربرگ و ردیف اطلاعات هر دو نمایش داده می‌شود
      expect(find.text('تخصیص‌یافته'), findsNWidgets(2));
      expect(find.text('دکتر رحیمی'), findsOneWidget);
      expect(find.text('شرح کامل ماجرا'), findsOneWidget);
      expect(find.text('۲۵,۰۰۰,۰۰۰ تومان'), findsOneWidget);
    });

    testWidgets('۴۰۴ ضدافشا → پیام عین سرور', (tester) async {
      final container = dadgarContainer(casesRepository: FakeCasesRepository());
      addTearDown(container.dispose);

      await _pumpApp(
        tester,
        container,
        const CaseDetailScreen(caseId: 999),
      );
      // خطای FutureProvider در مکروتسک → دو فریم برای رندر وضعیت خطا
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('پرونده یافت نشد.'), findsOneWidget);
    });
  });

  group('NewCaseScreen — فرم ثبت', () {
    testWidgets('شش دسته‌ی قرارداد به‌صورت چیپ نمایش داده می‌شود',
        (tester) async {
      await _pumpApp(tester, dadgarContainer(), const NewCaseScreen());
      await tester.pump();

      expect(find.text('دسته‌بندی پرونده'), findsOneWidget);
      expect(find.text('ملکی'), findsOneWidget);
      expect(find.text('خانواده'), findsOneWidget);
      expect(find.text('کیفری'), findsOneWidget);
      expect(find.text('شرکت‌ها'), findsOneWidget);
      expect(find.text('ارث و وصیت'), findsOneWidget);
      expect(find.text('قرارداد'), findsOneWidget);
    });

    testWidgets('عنوان کوتاه → خطای اعتبارسنجی بدون POST', (tester) async {
      final container = dadgarContainer(casesRepository: FakeCasesRepository());
      addTearDown(container.dispose);

      await _pumpApp(
        tester,
        container,
        const NewCaseScreen(),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'abcd');
      await tester.tap(find.text('ثبت پرونده'));
      await tester.pump();

      // اعتبارسنجی فرم جلوی submit را می‌گیرد — بدون فراخوانی سرور
      final repo =
          container.read(casesRepositoryProvider) as FakeCasesRepository;
      expect(repo.createCalls, 0);
    });
  });
}
