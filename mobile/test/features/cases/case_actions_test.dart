/// CMD-051 — تست اقدامات مدیر روی پرونده برای درخت «نسل S»
///
/// تست‌های کنترلر (M6/CMD-028) عیناً حفظ شده‌اند؛ تست‌های ویجت روی پوسته‌ی
/// Ds بازنویسی شده‌اند. pumpAndSettle استفاده نمی‌شود — پس از گذار وضعیت،
/// invalidه‌شدن جزئیات حلقه‌ی DsRing (انیمیشن بی‌پایان) می‌سازد؛ به‌جای آن
/// pump با مدت مشخص.
library;

import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/auth/domain/session_user.dart';
import 'package:dadgar_mobile/features/cases/application/cases_controller.dart';
import 'package:dadgar_mobile/features/cases/data/cases_contract.dart';
import 'package:dadgar_mobile/features/cases/domain/case_models.dart';
import 'package:dadgar_mobile/features/cases/presentation/case_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

CaseDetail detail({
  String status = 'proposing',
  List<Proposal> proposals = const [],
}) =>
    CaseDetail(
      id: 56,
      title: 'پرونده تست مالی',
      category: 'ملکی',
      status: status,
      createdAt: 1792701000,
      updatedAt: 1792701000,
      description: 'توضیحات تست',
      proposals: proposals,
    );

Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CaseDetailScreen(caseId: 56)),
    ),
  );
  // فریم ۱: جزئیات در حال بارگذاری؛ فریم ۲: داده + شروع کشف نقش؛
  // فریم ۳: نقش آماده → بخش مدیر رندر می‌شود
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('CaseActionsController — تایید پیشنهاد و گذار وضعیت', () {
    test('acceptProposal موفق → پیام + invalidه‌ی جزئیات', () async {
      final repo = FakeCasesRepository(details: {56: detail()});
      final container = ProviderContainer(
        overrides: [casesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(caseActionsProvider.notifier).setTarget(56);
      final ok = await container
          .read(caseActionsProvider.notifier)
          .acceptProposal(901);

      expect(ok, isTrue);
      expect(repo.acceptProposalArgs.single, 901);
      expect(
        container.read(caseActionsProvider).message,
        'پیشنهاد تایید شد و وکیل تخصیص یافت.',
      );
    });

    test('acceptProposal خطا → پیام عین سرور (پیشنهاد تعیین‌تکلیف‌شده)',
        () async {
      final repo = FakeCasesRepository()
        ..failWith = const ApiException(
          'این پیشنهاد قبلاً تعیین تکلیف شده است.',
          statusCode: 400,
        );
      final container = ProviderContainer(
        overrides: [casesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(caseActionsProvider.notifier).setTarget(56);
      final ok = await container
          .read(caseActionsProvider.notifier)
          .acceptProposal(901);

      expect(ok, isFalse);
      expect(
        container.read(caseActionsProvider).message,
        CasesContract.proposalAlreadyDecidedMessage,
      );
    });

    test('setStatus running → PATCH با وضعیت و پیام برچسب فارسی', () async {
      final repo = FakeCasesRepository(details: {56: detail(status: 'assigned')});
      final container = ProviderContainer(
        overrides: [casesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(caseActionsProvider.notifier).setTarget(56);
      final ok = await container
          .read(caseActionsProvider.notifier)
          .setStatus('running');

      expect(ok, isTrue);
      expect(
        repo.setCaseStatusArgs.single,
        (id: 56, status: 'running'),
      );
      expect(
        container.read(caseActionsProvider).message,
        'وضعیت پرونده به «در حال انجام» تغییر کرد.',
      );
    });

    test('setStatus done روی پرونده‌ی بسته → پیام عین سرور', () async {
      final repo = FakeCasesRepository()
        ..failWith = const ApiException(
          'این پرونده بسته شده است و قابل تغییر نیست.',
          statusCode: 400,
        );
      final container = ProviderContainer(
        overrides: [casesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(caseActionsProvider.notifier).setTarget(56);
      final ok = await container
          .read(caseActionsProvider.notifier)
          .setStatus('running');

      expect(ok, isFalse);
      expect(
        container.read(caseActionsProvider).message,
        CasesContract.caseDoneLockedMessage,
      );
    });
  });

  group('CaseDetailScreen — بخش اقدامات مدیر (پوسته‌ی نسل S)', () {
    testWidgets('مدیر: پیشنهادها با دکمه‌ی تایید رندر می‌شود', (tester) async {
      final repo = FakeCasesRepository(details: {
        56: detail(
          status: 'proposing',
          proposals: [
            const Proposal(
              id: 901,
              lawyerName: 'وکیل تست چرخه',
              amount: 7000000,
              days: 20,
              note: 'یادداشت تست',
              status: 'pending',
              createdAt: 1792701000,
            ),
          ],
        ),
      });
      final container = dadgarContainer(
        authStatus: const Authenticated('admin_t'),
        repository: FakeAuthRepository()
          ..me = const SessionUser(
            id: 1,
            role: 'admin',
            name: 'مدیر',
            username: 'admin_t',
          ),
        casesRepository: repo,
        // پنل اسناد جزئیات، فهرست اسناد را می‌خواند — فیک آب‌بند
        messagesRepository: FakeMessagesRepository(),
        documentsRepository: FakeDocumentsRepository(),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('اقدامات مدیر'), findsOneWidget);
      expect(find.text('وکیل تست چرخه'), findsOneWidget);
      expect(find.text('تایید پیشنهاد'), findsOneWidget);

      // دکمه پایین کارت اقدامات است — ابتدا به دید آورده می‌شود
      await tester.ensureVisible(find.text('تایید پیشنهاد'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('تایید پیشنهاد'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('تایید شود؟'), findsOneWidget);
    });

    testWidgets('مشتری: بخش اقدامات مدیر رندر نمی‌شود (یادداشت D-6 می‌ماند)',
        (tester) async {
      final repo = FakeCasesRepository(details: {56: detail()});
      final container = dadgarContainer(
        authStatus: const Authenticated('client_t'),
        repository: FakeAuthRepository()
          ..me = const SessionUser(
            id: 2,
            role: 'client',
            name: 'مشتری',
            username: 'client_t',
          ),
        casesRepository: repo,
        // پنل اسناد جزئیات، فهرست اسناد را می‌خواند — فیک آب‌بند
        messagesRepository: FakeMessagesRepository(),
        documentsRepository: FakeDocumentsRepository(),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('اقدامات مدیر'), findsNothing);
      expect(find.textContaining('پس از اتصال زنده (D-6)'), findsOneWidget);
    });

    testWidgets('مدیر: پرونده‌ی assigned → دکمه‌ی شروع اجرا', (tester) async {
      final repo = FakeCasesRepository(
        details: {56: detail(status: 'assigned')},
      );
      final container = dadgarContainer(
        authStatus: const Authenticated('admin_t'),
        repository: FakeAuthRepository()
          ..me = const SessionUser(
            id: 1,
            role: 'admin',
            name: 'مدیر',
            username: 'admin_t',
          ),
        casesRepository: repo,
        // پنل اسناد جزئیات، فهرست اسناد را می‌خواند — فیک آب‌بند
        messagesRepository: FakeMessagesRepository(),
        documentsRepository: FakeDocumentsRepository(),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('شروع اجرا'), findsOneWidget);

      // کارت اقدامات مدیر زیر کارت‌های دیگر است — ابتدا به دید آورده می‌شود
      await tester.ensureVisible(find.text('شروع اجرا'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('شروع اجرا'));
      await tester.pump(const Duration(milliseconds: 400));
      // دیالوگ تایید باز شد؛ دکمه‌ی تایید دیالوگ هم برچسب «شروع اجرا» دارد
      await tester.tap(find.text('شروع اجرا').last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      // invalidه‌شدن جزئیات → رفرش داده با pump مشخص (بدون pumpAndSettle
      // حول DsRing)
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        repo.setCaseStatusArgs.single,
        (id: 56, status: 'running'),
      );
    });

    testWidgets('مدیر: پرونده‌ی running → دکمه‌ی بستن پرونده', (tester) async {
      final repo = FakeCasesRepository(
        details: {56: detail(status: 'running')},
      );
      final container = dadgarContainer(
        authStatus: const Authenticated('admin_t'),
        repository: FakeAuthRepository()
          ..me = const SessionUser(
            id: 1,
            role: 'admin',
            name: 'مدیر',
            username: 'admin_t',
          ),
        casesRepository: repo,
        // پنل اسناد جزئیات، فهرست اسناد را می‌خواند — فیک آب‌بند
        messagesRepository: FakeMessagesRepository(),
        documentsRepository: FakeDocumentsRepository(),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('بستن پرونده'), findsOneWidget);
    });

    testWidgets('مدیر: پرونده‌ی done → یادداشت بسته‌بودن بدون دکمه',
        (tester) async {
      final repo = FakeCasesRepository(
        details: {56: detail(status: 'done')},
      );
      final container = dadgarContainer(
        authStatus: const Authenticated('admin_t'),
        repository: FakeAuthRepository()
          ..me = const SessionUser(
            id: 1,
            role: 'admin',
            name: 'مدیر',
            username: 'admin_t',
          ),
        casesRepository: repo,
        // پنل اسناد جزئیات، فهرست اسناد را می‌خواند — فیک آب‌بند
        messagesRepository: FakeMessagesRepository(),
        documentsRepository: FakeDocumentsRepository(),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(
        find.text('این پرونده بسته شده است و قابل تغییر نیست.'),
        findsOneWidget,
      );
      expect(find.text('شروع اجرا'), findsNothing);
      expect(find.text('بستن پرونده'), findsNothing);
    });
  });
}
