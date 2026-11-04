import 'package:dadgar_mobile/app/app.dart';
import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/features/auth/application/app_lock_controller.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('مسیر اول بدون نشست = صفحه‌ی ورود: عنوان دادگر + RTL فارسی',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider
              .overrideWith(() => FakeAuthController(const AuthUnauthenticated())),
        ],
        child: const DadgarApp(),
      ),
    );
    await tester.pumpAndSettle();

    // عنوان صفحه‌ی ورود
    expect(find.text('ورود به دادگر'), findsOneWidget);
    expect(find.text('ورود'), findsOneWidget);

    // راستا: فارسی RTL — الزام DOC-04 §۷
    final BuildContext titleContext = tester.element(
      find.text('ورود به دادگر'),
    );
    expect(Directionality.of(titleContext), TextDirection.rtl);
  });

  testWidgets('نشست معتبر + قفل فعال = صفحه‌ی قفل بیومتریک', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider
              .overrideWith(() => FakeAuthController(const Authenticated('ali'))),
          appLockControllerProvider.overrideWith(
            () => FakeAppLockController(
              const AppLockState(enabled: true, unlocked: false),
            ),
          ),
        ],
        child: const DadgarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('دادگر قفل است'), findsOneWidget);
    expect(find.text('بازکردن با بیومتریک'), findsOneWidget);
  });
}
