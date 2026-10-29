/// تست کنترلرهای پرونده‌ها — فهرست/صفحه‌بندی/ثبت/جزئیات
library;

import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/cases/application/cases_controller.dart';
import 'package:dadgar_mobile/features/cases/domain/case_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

CaseSummary _row(int id, {String status = 'waiting'}) => CaseSummary(
      id: id,
      title: 'پرونده‌ی شماره $id',
      category: 'ملکی',
      status: status,
      createdAt: 1792701000,
      updatedAt: 1792701000,
    );

CasesPage _page(
  int page, {
  int pages = 1,
  List<CaseSummary>? rows,
  int total = 0,
}) =>
    CasesPage(
      rows: rows ?? const [],
      page: page,
      pages: pages,
      total: total,
    );

void main() {
  group('CasesController — فهرست و صفحه‌بندی', () {
    test('بارگذاری اول: ردیف‌ها + شمارنده‌ها', () async {
      final repo = FakeCasesRepository(pages: {
        1: _page(1, pages: 2, rows: [_row(1), _row(2)], total: 12),
      });
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      container.read(casesControllerProvider.notifier);
      await _pumpUntil(container, (ui) => ui.status == LoadStatus.ready);

      final ui = container.read(casesControllerProvider);
      expect(ui.rows.map((r) => r.id), [1, 2]);
      expect(ui.page, 1);
      expect(ui.pages, 2);
      expect(ui.total, 12);
      expect(ui.hasMore, isTrue);
      expect(repo.pageArgs.single.page, 1);
    });

    test('loadMore: صفحه‌ی دوم پیوست می‌شود؛ بعدش توقف', () async {
      final repo = FakeCasesRepository(pages: {
        1: _page(1, pages: 2, rows: [_row(1)], total: 11),
        2: _page(2, pages: 2, rows: [_row(2)], total: 11),
      });
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      // بار اول — تا ready
      final controller = container.read(casesControllerProvider.notifier);
      await _pumpUntil(container, (ui) => ui.status == LoadStatus.ready);
      expect(container.read(casesControllerProvider).rows.map((r) => r.id), [1]);

      await controller.loadMore();
      var ui = container.read(casesControllerProvider);
      expect(ui.rows.map((r) => r.id), [1, 2]);
      expect(ui.page, 2);
      expect(ui.hasMore, isFalse);

      // درخواست صفحه‌ی بعد وقتی نیست — بی‌اثر
      await controller.loadMore();
      expect(repo.pageCalls, 2);
      expect(repo.pageArgs.map((a) => a.page), [1, 2]);
    });

    test('خطای ۴۰۱ → پیام صادقانه‌ی D-6 (نه پیام فنی)', () async {
      final repo = FakeCasesRepository(
        failWith: const ApiException('unauthorized', statusCode: 401),
      );
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      container.read(casesControllerProvider.notifier);
      await _pumpUntil(container, (ui) => ui.status == LoadStatus.error);
      final ui = container.read(casesControllerProvider);
      expect(ui.isError, isTrue);
      expect(ui.message, contains('D-6'));
    });
  });

  group('CreateCaseController — ثبت پرونده', () {
    test('اعتبارسنجی آینه‌ی سرور: عنوان کوتاه رد می‌شود', () async {
      final repo = FakeCasesRepository();
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      final controller = container.read(createCaseControllerProvider.notifier);
      controller
        ..setCategory('ملکی')
        ..setTitle('abcd'); // ۴ نویسه < ۵
      final id = await controller.submit();

      expect(id, isNull);
      expect(repo.createCalls, 0);
      expect(container.read(createCaseControllerProvider).isError, isTrue);
    });

    test('بدون دسته رد می‌شود', () async {
      final repo = FakeCasesRepository();
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      final controller = container.read(createCaseControllerProvider.notifier);
      controller.setTitle('عنوان کافی برای تست');
      final id = await controller.submit();

      expect(id, isNull);
      expect(repo.createCalls, 0);
    });

    test('ثبت موفق → شناسه‌ی جدید و doneId', () async {
      final repo = FakeCasesRepository();
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      final controller = container.read(createCaseControllerProvider.notifier);
      controller
        ..setCategory('ارث و وصیت')
        ..setTitle('عنوان پرونده‌ی آزمون')
        ..setDescription('شرح');
      final id = await controller.submit();

      expect(id, 201);
      expect(repo.createCalls, 1);
      expect(repo.createArgs.single.category, 'ارث و وصیت');
      expect(container.read(createCaseControllerProvider).doneId, 201);
      expect(
        repo.createArgs.single.title,
        'عنوان پرونده‌ی آزمون',
      );
    });

    test('۴۲۹ سقف نرخ → پیام عین سرور به کاربر', () async {
      final repo = FakeCasesRepository(
        failWith: const ApiException(
          'سقف ثبت پرونده در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
          statusCode: 429,
        ),
      );
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      final controller = container.read(createCaseControllerProvider.notifier);
      controller
        ..setCategory('ملکی')
        ..setTitle('عنوان پرونده‌ی آزمون');
      final id = await controller.submit();

      expect(id, isNull);
      final ui = container.read(createCaseControllerProvider);
      expect(ui.isError, isTrue);
      expect(
        ui.message,
        'سقف ثبت پرونده در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
      );
    });
  });

  group('caseDetailProvider — جزئیات (FutureProvider.family)', () {
    test('دریافت جزئیات آماده', () async {
      final repo = FakeCasesRepository(details: {
        7: const CaseDetail(
          id: 7,
          title: 'اختلاف بر سر مبیع',
          category: 'ملکی',
          status: 'running',
          createdAt: 1792701000,
          updatedAt: 1792787400,
          lawyerName: 'دکتر رحیمی',
          description: 'شرح',
        ),
      });
      final container = dadgarContainer(casesRepository: repo);
      addTearDown(container.dispose);

      final detail = await container.read(caseDetailProvider(7).future);
      expect(detail.statusValue.labelFa, 'در حال انجام');
      expect(detail.lawyerName, 'دکتر رحیمی');
    });

    test('۴۰۴ ضدافشا → وضعیت AsyncError با پیام عین سرور', () async {
      final container = dadgarContainer(casesRepository: FakeCasesRepository());
      addTearDown(container.dispose);

      // راه‌اندازی + صبر برای تکمیل مکروتسک خطا
      container.read(caseDetailProvider(999));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(caseDetailProvider(999));
      expect(state, isA<AsyncError<CaseDetail>>());
      final error = (state as AsyncError<CaseDetail>).error;
      expect(
        error,
        isA<ApiException>()
            .having((e) => e.message, 'message', 'پرونده یافت نشد.')
            .having((e) => e.statusCode, 'statusCode', 404),
      );
    });

    test('۴۰۱ → وضعیت AsyncError با پیام صادقانه‌ی D-6', () async {
      final container = dadgarContainer(
        casesRepository: FakeCasesRepository(
          failWith: const ApiException('unauthorized', statusCode: 401),
        ),
      );
      addTearDown(container.dispose);

      container.read(caseDetailProvider(7));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(caseDetailProvider(7));
      expect(state, isA<AsyncError<CaseDetail>>());
      final error = (state as AsyncError<CaseDetail>).error;
      expect(
        error,
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('D-6'),
        ),
      );
    });
  });
}

/// صبر تا برقراری شرط روی وضعیت فهرست — microtask کنترلر async است
Future<void> _pumpUntil(
  ProviderContainer container,
  bool Function(CasesUi) condition,
) async {
  for (var i = 0; i < 200; i++) {
    if (condition(container.read(casesControllerProvider))) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('وضعیت فهرست به شرط نرسید');
}
