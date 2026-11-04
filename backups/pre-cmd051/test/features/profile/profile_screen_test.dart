/// تست ویجت صفحه‌ی پروفایل (CMD-046 فاز ۳ — طرح bProfile)
///
/// دروازه‌ها: کارت حساب با نام واقعی نشست، قرص «حساب فعال»، سوییچ
/// بیومتریک M1، دیالوگ تأیید خروج (انصراف = بدون logout).
library;

import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/auth/domain/session_user.dart';
import 'package:dadgar_mobile/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ProfileScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('کارت حساب: نام کاربری نشست + قرص حساب فعال', (tester) async {
    final container = dadgarContainer(
      authStatus: const Authenticated('امیر رستگاری'),
    );
    addTearDown(container.dispose);

    await _pump(tester, container);

    expect(find.text('پروفایل'), findsOneWidget);
    expect(find.text('امیر رستگاری'), findsOneWidget);
    expect(find.text('حساب فعال'), findsOneWidget);
    // آواتار حرف اول نام
    expect(find.text('ا'), findsOneWidget);
  });

  testWidgets('پنل امنیت: سوییچ بیومتریک M1 و دکمه‌ی خروج مخرب', (tester) async {
    final container = dadgarContainer(
      authStatus: const Authenticated('کاربر'),
    );
    addTearDown(container.dispose);

    await _pump(tester, container);

    expect(find.text('امنیت'), findsOneWidget);
    expect(find.text('ورود با بیومتریک'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('خروج از این دستگاه'), findsOneWidget);
  });

  testWidgets('خروج: دیالوگ تأیید باز می‌شود؛ انصراف بدون ابطال توکن',
      (tester) async {
    final auth = FakeAuthRepository()
      ..me = const SessionUser(
        id: 1,
        role: 'client',
        name: 'کاربر',
        username: 'کاربر',
      );
    final container = dadgarContainer(
      authStatus: const Authenticated('کاربر'),
      repository: auth,
    );
    addTearDown(container.dispose);

    await _pump(tester, container);

    await tester.tap(find.text('خروج از این دستگاه'));
    await tester.pumpAndSettle();

    expect(find.text('خروج از حساب'), findsOneWidget);
    expect(find.text('توکن این دستگاه ابطال و نشست پاک می‌شود.'), findsOneWidget);

    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();

    expect(find.text('خروج از حساب'), findsNothing);
    expect(auth.logoutCalls, 0);
  });
}
