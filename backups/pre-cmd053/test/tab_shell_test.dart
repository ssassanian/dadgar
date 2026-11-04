/// گیت‌های پوسته‌ی ناوبری «دادگر S» — بازنویسی برای داک شناور (CMD-051)
///
/// سه دروازه: (۱) داک شناور پنج‌مقصدی با کلیدهای پایدار و برچسب فارسی
/// مقصد فعال، (۲) سوییچ شاخه بدون گم‌شدن داک، (۳) نقطه‌ی فاکتور فقط با
/// فاکتور پرداخت‌نشده‌ی واقعی (S-4 — صفر داده‌ی جعلی).
library;

import 'package:dadgar_mobile/app/app.dart';
import 'package:dadgar_mobile/app/tab_shell.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:dadgar_mobile/features/cases/presentation/cases_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  /// پمپ اپ کامل با نشست معتبر و فیک‌های همه‌ی شاخه‌های داک
  Future<void> pumpShell(
    WidgetTester tester, {
    FakeBillingRepository? billing,
  }) async {
    final container = dadgarContainer(
      authStatus: const Authenticated('امیر'),
      appointmentsRepository: FakeAppointmentsRepository(),
      billingRepository: billing ?? FakeBillingRepository(),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DadgarApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('دروازه ۱: داک شناور پنج‌مقصدی + برچسب مقصد فعال', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.byType(DadgarTabShell), findsOneWidget);
    expect(find.byType(DsDock), findsOneWidget);
    for (final location in <String>[
      '/',
      '/cases',
      '/appointments',
      '/invoices',
      '/profile',
    ]) {
      expect(find.byKey(ValueKey<String>('dock-$location')), findsOneWidget);
    }
    // داک فقط‌آیکونی است — نام مقصد فعال در Semantics حاضر است
    // (قاعده‌ی مهارت: نام دسترس‌پذیر برای کنترل فقط‌آیکونی)
    final semantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('dock-/')),
    );
    expect(semantics.label, 'خانه');
  });

  testWidgets('دروازه ۲: تپ روی مقصد پرونده‌ها → فهرست پرونده‌ها با داک', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const ValueKey<String>('dock-/cases')));
    await tester.pumpAndSettle();

    expect(find.byType(CasesScreen), findsOneWidget);
    // داک روی ریشه‌ها می‌ماند
    expect(find.byType(DsDock), findsOneWidget);
  });

  testWidgets('دروازه ۳: بدون فاکتور پرداخت‌نشده → بدون نقطه', (
    tester,
  ) async {
    await pumpShell(tester, billing: FakeBillingRepository());

    expect(
      find.descendant(
        of: find.byType(DsDock),
        matching: find.byType(Badge),
      ),
      findsNothing,
    );
  });

  testWidgets('دروازه ۴: فاکتور pending → نقطه روی مقصد فاکتور', (
    tester,
  ) async {
    await pumpShell(
      tester,
      billing: FakeBillingRepository(
        response: InvoicesResponse(
          rows: [
            const Invoice(
              id: 17,
              amount: 18500000,
              status: 'pending',
              createdAt: 1762000000,
              paidAt: null,
              caseId: 14,
            ),
          ],
          todayD: 1,
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(DsDock),
        matching: find.byType(Badge),
      ),
      findsOneWidget,
    );
  });
}
