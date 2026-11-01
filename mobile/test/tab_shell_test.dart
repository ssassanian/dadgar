/// گیت‌های پوسته‌ی پنج‌تبی — CMD-044 (اجرای توصیه‌های F2 و F12 بازرسی CMD-042)
///
/// سه دروازه: (۱) نوار پایین پنج‌تبی با برچسب‌های فارسی عین طرح تاییدشده،
/// (۲) سوییچ شاخه بدون گم‌شدن تب‌بار، (۳) نقطه‌ی فاکتور فقط با فاکتور
/// پرداخت‌نشده‌ی واقعی (S-4 — صفر داده‌ی جعلی).
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
  /// پمپ اپ کامل با نشست معتبر و فیک‌های همه‌ی شاخه‌های تب‌بار
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

  testWidgets('دروازه ۱: نوار پایین پنج‌تبی با برچسب‌های فارسی', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.byType(DadgarTabShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('خانه'), findsWidgets);
    expect(find.text('پرونده‌ها'), findsWidgets);
    expect(find.text('نوبت'), findsWidgets);
    expect(find.text('فاکتور'), findsWidgets);
    expect(find.text('پروفایل'), findsWidgets);
  });

  testWidgets('دروازه ۲: تپ روی تب پرونده‌ها → فهرست پرونده‌ها با تب‌بار', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('پرونده‌ها'));
    await tester.pumpAndSettle();

    expect(find.byType(CasesScreen), findsOneWidget);
    // تب‌بار روی ریشه‌ها می‌ماند — عین tabbar() پروتوتایپ
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('دروازه ۳ (F12): بدون فاکتور پرداخت‌نشده → بدون نقطه', (
    tester,
  ) async {
    await pumpShell(tester, billing: FakeBillingRepository());

    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(Badge),
      ),
      findsNothing,
    );
  });

  testWidgets('دروازه ۴ (F12): فاکتور pending → نقطه روی تب فاکتور', (
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
        of: find.byType(NavigationBar),
        matching: find.byType(Badge),
      ),
      findsOneWidget,
    );
  });
}
