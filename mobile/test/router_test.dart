import 'package:dadgar_mobile/app/app.dart';
import 'package:dadgar_mobile/features/auth/application/app_lock_controller.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('ردیف ۱: بدون نشست → صفحه‌ی ورود', (tester) async {
    final container = dadgarContainer(
      authStatus: const AuthUnauthenticated(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DadgarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ورود به دادگر'), findsOneWidget);
  });

  testWidgets('ردیف ۲: نشست معتبر + قفل فعال و بسته → صفحه‌ی قفل',
      (tester) async {
    final container = dadgarContainer(
      authStatus: const Authenticated('ali'),
      lockState: const AppLockState(enabled: true, unlocked: false),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DadgarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('دادگر قفل است'), findsOneWidget);
  });

  testWidgets('ردیف ۳: نشست معتبر و باز (یا قفل غیرفعال) → خانه',
      (tester) async {
    final container = dadgarContainer(
      authStatus: const Authenticated('مدیر'),
      lockState: const AppLockState(enabled: true, unlocked: true),
      appointmentsRepository:
          FakeAppointmentsRepository(), // جریان M3 بدون شبکه
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DadgarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سلام، مدیر'), findsOneWidget);
  });

  testWidgets('ردیف ۴ (M3): نشست معتبر → خانه کارت نوبت‌دهی دارد و مسیر '
      '/appointments باز می‌شود', (tester) async {
    final container = dadgarContainer(
      authStatus: const Authenticated('مدیر'),
      appointmentsRepository: FakeAppointmentsRepository(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DadgarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('رزرو نوبت'), findsOneWidget);
    await tester.tap(find.text('رزرو نوبت'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('نوبت‌دهی'), findsOneWidget);
  });
}
