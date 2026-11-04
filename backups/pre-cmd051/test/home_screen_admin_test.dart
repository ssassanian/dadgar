/// تست gating کارت پنل مدیریت در خانه — M6 (CMD-028)
library;

import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/auth/domain/session_user.dart';
import 'package:dadgar_mobile/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 60));
}

void main() {
  group('HomeScreen — کارت پنل مدیریت مالی (نقش‌محور)', () {
    testWidgets('مدیر → کارت پنل دیده می‌شود', (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('admin_t'),
        sessionUser: const SessionUser(
          id: 1,
          role: 'admin',
          name: 'مدیر',
          username: 'admin_t',
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('پنل مدیریت مالی'), findsOneWidget);
      expect(find.text('صدور فاکتور، ثبت پرداخت و بازکردن (M6)'), findsOneWidget);
    });

    testWidgets('مشتری → کارت پنل هرگز رندر نمی‌شود', (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('client_t'),
        sessionUser: const SessionUser(
          id: 2,
          role: 'client',
          name: 'مشتری',
          username: 'client_t',
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('پنل مدیریت مالی'), findsNothing);
      // کارت‌های عادی سر جایشان هستند
      expect(find.text('صورتحساب‌ها و پرداخت'), findsOneWidget);
    });

    testWidgets('نقش کشف‌نشده (بدون /api/me) → کارت پنل مخفی (پیش‌فرض امن)',
        (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('client_t'),
        repository: FakeAuthRepository()..me = null,
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);

      expect(find.text('پنل مدیریت مالی'), findsNothing);
    });
  });
}
