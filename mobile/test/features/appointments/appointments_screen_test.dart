import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/appointments/data/appointments_contract.dart';
import 'package:dadgar_mobile/features/appointments/domain/appointment.dart';
import 'package:dadgar_mobile/features/appointments/presentation/appointments_screen.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Future<void> _pump(
  WidgetTester tester, {
  required FakeAppointmentsRepository repo,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        appointmentsRepository: repo,
      ),
      child: const MaterialApp(
        locale: Locale('fa'),
        supportedLocales: [Locale('fa')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AppointmentsScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

AppointmentsPage _openPage({Set<String> taken = const {}}) {
  return AppointmentsPage(
    rows: const [],
    taken: taken,
    serverNowSeconds: AppointmentContract.monthStartEpochSeconds - 86400,
    todayDay: 7,
  );
}

void main() {
  testWidgets('تقویم شمسی نیتیو: ماه قرارداد، نام روزها و خانه‌ی امروز',
      (tester) async {
    await _pump(tester, repo: FakeAppointmentsRepository(page: _openPage()));

    // سربرگ ماه قرارداد
    expect(find.text('آبان ۱۴۰۵'), findsOneWidget);
    // نام روزهای هفته از شنبه
    expect(find.text('شنبه'), findsOneWidget);
    expect(find.text('جمعه'), findsOneWidget);
    // خانه‌ی امروز (روز ۷) با ارقام فارسی
    expect(find.text('۷'), findsWidgets);
    // بازه‌ها برای روز انتخاب‌شده نمایش داده می‌شوند
    expect(find.text('۰۹:۰۰'), findsWidgets);
    expect(find.text('۱۷:۳۰'), findsWidgets);
    // یادآوری صادقانه
    expect(find.textContaining('D-6'), findsOneWidget);
  });

  testWidgets('بازه‌ی پر غیرفعال است و برچسب «پر» می‌گیرد', (tester) async {
    await _pump(
      tester,
      repo: FakeAppointmentsRepository(
        page: _openPage(taken: {'7:۰۹:۰۰'}),
      ),
    );

    expect(find.text('۰۹:۰۰ (پر)'), findsOneWidget);
    // بقیه‌ی بازه‌ها آزاد و بدون برچسب «پر»
    expect(find.text('۱۰:۳۰ (پر)'), findsNothing);
  });

  testWidgets('۴۰۱ تا حکم D-6: پیام صادقانه + تلاش دوباره', (tester) async {
    await _pump(
      tester,
      repo: FakeAppointmentsRepository(
        failWith: const ApiException('ورود لازم است', statusCode: 401),
      ),
    );

    expect(
      find.textContaining('اتصال زنده به سرور پس از حکم مدیر بر D-6'),
      findsWidgets, // پنل خطا + SnackBar — هر دو پیام صادقانه‌ی یکسان
    );
    expect(find.text('تلاش دوباره'), findsOneWidget);
  });

  testWidgets('جریان رزرو: انتخاب بازه → ثبت موفق با پیام سبز',
      (tester) async {
    final repo = FakeAppointmentsRepository(page: _openPage());
    await _pump(tester, repo: repo);

    // بازه‌ها زیر شبکه‌ی تقویم‌اند — اسکرول تا دیده‌شدن
    final slotFinder = find.text('۱۶:۰۰');
    await tester.scrollUntilVisible(
      slotFinder,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(slotFinder);
    await tester.pumpAndSettle();

    // دکمه‌ی رزرو (باز هم پایین‌تر)
    final bookFinder = find.text('رزرو این بازه');
    await tester.scrollUntilVisible(
      bookFinder,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(bookFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(repo.bookCalls, 1);
    expect(repo.bookArgs.single.kind, 'حضوری');
    expect(find.textContaining('نوبت ثبت شد'), findsWidgets);
  });
}
