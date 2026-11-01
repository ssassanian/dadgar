/// تست ویجت صفحات پرونده‌ها — فهرست، جزئیات، فرم ثبت (CMD-045: بازطراحی D-3)
library;

import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/design/d3_kit.dart';
import 'package:dadgar_mobile/features/cases/domain/case_models.dart';
import 'package:dadgar_mobile/features/cases/presentation/case_detail_screen.dart';
import 'package:dadgar_mobile/features/cases/presentation/cases_screen.dart';
import 'package:dadgar_mobile/features/cases/presentation/new_case_screen.dart';
import 'package:dadgar_mobile/features/documents/domain/document_models.dart';
import 'package:dadgar_mobile/features/messages/domain/chat_models.dart';
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

CasesPage _page(List<CaseSummary> rows) => CasesPage(
      rows: rows,
      page: 1,
      pages: 1,
      total: rows.length,
    );

void main() {
  group('CasesScreen — فهرست (طرح CMD-041)', () {
    testWidgets('نوار بالا با شمارنده، چیپ‌ها و ردیف‌های دوخطی رندر می‌شود',
        (tester) async {
      final repo = FakeCasesRepository(pages: {
        1: _page([
          const CaseSummary(
            id: 7,
            title: 'اختلاف بر سر مبیع',
            category: 'ملکی',
            status: 'running',
            createdAt: 1792701000,
            updatedAt: 1792701000,
          ),
          const CaseSummary(
            id: 3,
            title: 'مطالبه‌ی وجه چک',
            category: 'شرکت‌ها',
            status: 'done',
            createdAt: 1792701000,
            updatedAt: 1792701000,
          ),
        ]),
      });
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const CasesScreen());
      await tester.pump(const Duration(milliseconds: 50));

      // نوار بالای طرح: عنوان + شمارنده‌ی واقعی (کل از سرور، در جریان از ردیف‌ها)
      expect(find.text('پرونده‌ها'), findsOneWidget);
      expect(find.text('۲ پرونده · ۱ در جریان'), findsOneWidget);

      // چیپ‌های سه‌گانه‌ی طرح
      expect(find.text('همه'), findsOneWidget);
      expect(find.text('در جریان'), findsOneWidget);
      expect(find.text('بسته'), findsOneWidget);

      // ردیف دوخطی: خط اول شماره+عنوان، قرص وضعیت، خط دوم دسته+تاریخ
      expect(find.text('پرونده ۷ · اختلاف بر سر مبیع'), findsOneWidget);
      expect(find.text('پرونده ۳ · مطالبه‌ی وجه چک'), findsOneWidget);
      expect(find.text('در حال انجام'), findsOneWidget);
      expect(find.text('بسته‌شده'), findsOneWidget);
      expect(find.textContaining('ملکی'), findsOneWidget);

      // ورود «ثبت پرونده جدید» — دکمه‌ی شبح پایان فهرست (شات CMD-037)
      expect(find.text('ثبت پرونده جدید'), findsOneWidget);
      expect(find.byType(DadgarGhostButton), findsOneWidget);
    });

    testWidgets('چیپ «بسته» فقط پرونده‌های بسته را نشان می‌دهد', (tester) async {
      final repo = FakeCasesRepository(pages: {
        1: _page([
          const CaseSummary(
            id: 7,
            title: 'اختلاف بر سر مبیع',
            category: 'ملکی',
            status: 'running',
            createdAt: 1792701000,
            updatedAt: 1792701000,
          ),
          const CaseSummary(
            id: 3,
            title: 'مطالبه‌ی وجه چک',
            category: 'شرکت‌ها',
            status: 'done',
            createdAt: 1792701000,
            updatedAt: 1792701000,
          ),
        ]),
      });
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const CasesScreen());
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('بسته'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('مطالبه‌ی وجه چک'), findsOneWidget);
      expect(find.textContaining('اختلاف بر سر مبیع'), findsNothing);

      // برگشت به «همه» → هر دو ردیف
      await tester.tap(find.text('همه'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('اختلاف بر سر مبیع'), findsOneWidget);
    });

    testWidgets('فیلتر بدون نتیجه → خالی صادقانه‌ی طرح', (tester) async {
      final repo = FakeCasesRepository(pages: {
        1: _page([
          const CaseSummary(
            id: 7,
            title: 'اختلاف بر سر مبیع',
            category: 'ملکی',
            status: 'running',
            createdAt: 1792701000,
            updatedAt: 1792701000,
          ),
        ]),
      });
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const CasesScreen());
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('بسته'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('پرونده‌ای در این وضعیت ندارید.'), findsOneWidget);
    });

    testWidgets('خالی صادقانه — بدون داده‌ی جعلی', (tester) async {
      final container = dadgarContainer(casesRepository: FakeCasesRepository());
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const CasesScreen());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('هنوز پرونده‌ای ثبت نکرده‌اید'), findsOneWidget);
      expect(find.text('ثبت پرونده جدید'), findsOneWidget);
    });

    testWidgets('خطای ۴۰۱ → پیام صادقانه‌ی D-6 + تلاش دوباره', (tester) async {
      final container = dadgarContainer(
        casesRepository: FakeCasesRepository(
          failWith: const ApiException('unauthorized', statusCode: 401),
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const CasesScreen());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('D-6'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
    });
  });

  group('CaseDetailScreen — جزئیات (طرح CMD-041)', () {
    const detail = CaseDetail(
      id: 7,
      title: 'اختلاف بر سر مبیع',
      category: 'ملکی',
      status: 'assigned',
      createdAt: 1792701000,
      updatedAt: 1792787400,
      finalPrice: 25000000,
      lawyerName: 'دکتر رحیمی',
      description: 'شرح کامل ماجرا',
    );

    testWidgets('پنل‌های طرح: مسیر پنج‌وضعیتی، مشخصات، گفتگو، اسناد',
        (tester) async {
      final repo = FakeCasesRepository(details: {7: detail});
      final messages = FakeMessagesRepository(
        envelopes: {
          7: const ChatEnvelope(
            caseId: 7,
            caseTitle: 'اختلاف بر سر مبیع',
            caseStatus: 'assigned',
            rows: [
              ChatMessage(
                id: 1,
                mine: false,
                role: 'lawyer',
                body: 'قرارداد ضمیمه را بررسی کنید',
                createdAt: 1792701000,
              ),
            ],
          ),
        },
      );
      final documents = FakeDocumentsRepository(docs: [
        const DocSummary(
          id: 11,
          caseId: 7,
          caseTitle: 'اختلاف بر سر مبیع',
          name: 'وکالتنامه.pdf',
          mime: 'application/pdf',
          size: 1258000,
          mine: true,
          shared: false,
          createdAt: 1792701000,
        ),
        const DocSummary(
          id: 12,
          caseId: 9,
          caseTitle: 'پرونده‌ی دیگر',
          name: 'سند پرونده‌ی دیگر.pdf',
          mime: 'application/pdf',
          size: 900,
          mine: true,
          shared: true,
          createdAt: 1792701000,
        ),
      ]);
      final container = dadgarContainer(
        casesRepository: repo,
        messagesRepository: messages,
        documentsRepository: documents,
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const CaseDetailScreen(caseId: 7));
      await tester.pump(const Duration(milliseconds: 100));

      // نوار بالا: عنوان + زیرنویس شماره پرونده
      expect(find.text('جزئیات پرونده'), findsOneWidget);
      expect(find.text('پرونده ۷'), findsOneWidget);

      // سربرگ طرح: عنوان + قرص وضعیت (سربرگ و ردیف وضعیت = دو بار)
      expect(find.text('اختلاف بر سر مبیع'), findsOneWidget);
      expect(find.text('تخصیص‌یافته'), findsNWidgets(2));

      // پنل مسیر پرونده — پنج وضعیت واقعی سرور و مرحله‌ی ۳ از ۵
      expect(find.text('مسیر پرونده'), findsOneWidget);
      expect(find.text('مرحله‌ی ۳ از ۵'), findsOneWidget);
      expect(find.text('در انتظار بررسی'), findsOneWidget);
      expect(find.text('بسته‌شده'), findsOneWidget);

      // مشخصات پرونده — kvهای واقعی
      expect(find.text('مشخصات پرونده'), findsOneWidget);
      expect(find.text('دکتر رحیمی'), findsOneWidget);
      expect(find.text('۲۵,۰۰۰,۰۰۰ تومان'), findsOneWidget);
      expect(find.text('شرح کامل ماجرا'), findsOneWidget);

      // گفتگو با وکیل — آخرین پیام واقعی + دکمه‌ی ورود
      expect(find.textContaining('قرارداد ضمیمه را بررسی کنید'), findsOneWidget);
      // «وکیل» دو بار: کلید ردیف مشخصات + نقش فرستنده‌ی پیام
      expect(find.text('وکیل'), findsNWidgets(2));
      expect(find.text('گفتگو با وکیل'), findsNWidgets(2)); // سربرگ + دکمه

      // اسناد پرونده — فقط اسناد همین پرونده + لینک گاوصندوق
      expect(find.text('اسناد پرونده'), findsOneWidget);
      expect(find.text('وکالتنامه.pdf'), findsOneWidget);
      expect(find.text('محرمانه'), findsOneWidget);
      expect(find.text('سند پرونده‌ی دیگر.pdf'), findsNothing);
      expect(find.text('همه‌ی اسناد گاوصندوق'), findsOneWidget);

      // دکمه‌ی شبح رزرو نوبت
      expect(find.text('رزرو نوبت با وکیل'), findsOneWidget);
    });

    testWidgets('پرونده‌ی بی‌وکیل: پیام عین سرور بدون هیچ فراخوانی گفتگو',
        (tester) async {
      final repo = FakeCasesRepository(details: {
        7: const CaseDetail(
          id: 7,
          title: 'اختلاف بر سر مبیع',
          category: 'ملکی',
          status: 'waiting',
          createdAt: 1792701000,
          updatedAt: 1792787400,
        ),
      });
      final messages = FakeMessagesRepository();
      final documents = FakeDocumentsRepository();
      final container = dadgarContainer(
        casesRepository: repo,
        messagesRepository: messages,
        documentsRepository: documents,
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const CaseDetailScreen(caseId: 7));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('گفتگوی این پرونده هنوز فعال نیست؛ پس از تخصیص وکیل باز می‌شود.'),
        findsOneWidget,
      );
      // هیچ فراخوانی گفتگو زده نشد (قاعده‌ی سرور) و دکمه‌ی ورود هم نیست
      expect(messages.messageCalls, 0);
      expect(find.byType(DadgarPrimaryButton), findsNothing);
      // وضعیت شناخته‌شده → قرص مرحله‌ی واقعی (آغاز چرخه)
      expect(find.text('مرحله‌ی ۱ از ۵'), findsOneWidget);
    });

    testWidgets('۴۰۴ ضدافشا → پیام عین سرور', (tester) async {
      final container = dadgarContainer(
        casesRepository: FakeCasesRepository(),
        messagesRepository: FakeMessagesRepository(),
        documentsRepository: FakeDocumentsRepository(),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const CaseDetailScreen(caseId: 999));
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
