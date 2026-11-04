import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/core/secure/token_store.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  test('بدون نشست: بازیابی → بدون احراز هویت', () async {
    final container = dadgarContainer(realAuthController: true);
    addTearDown(container.dispose);

    final initial = container.read(authControllerProvider);
    expect(initial, isA<AuthUnknown>());

    // اجازه به microtask بازیابی
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(authControllerProvider),
      isA<AuthUnauthenticated>(),
    );
  });

  test('نشست ذخیره‌شده: بازیابی → احراز هویت با نام کاربری', () async {
    final store = InMemoryTokenStore();
    await store.save(
      const AuthTokens(access: 'a1', refresh: 'r1', username: 'ali'),
    );
    final container = dadgarContainer(tokenStore: store, realAuthController: true);
    addTearDown(container.dispose);

    // kick build → زمان‌بندی microtask بازیابی
    expect(container.read(authControllerProvider), isA<AuthUnknown>());

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final status = container.read(authControllerProvider);
    expect(status, isA<Authenticated>());
    expect((status as Authenticated).username, 'ali');
  });

  test('ورود موفق → وضعیت احراز هویت + یک فراخوانی login', () async {
    final repo = FakeAuthRepository();
    final container = dadgarContainer(repository: repo);
    addTearDown(container.dispose);

    final ok = await container
        .read(authControllerProvider.notifier)
        .login(username: 'ali', password: 'secret');
    expect(ok, isTrue);
    expect(repo.loginCalls, 1);

    final status = container.read(authControllerProvider);
    expect(status, isA<Authenticated>());
    expect((status as Authenticated).username, 'ali');
  });

  test('ورود ناموفق → خطا پرتاب می‌شود و وضعیت بدون احراز می‌ماند', () async {
    final repo =
        FakeAuthRepository(failWith: const ApiException('نام کاربری یا رمز عبور نادرست است', statusCode: 401));
    final container = dadgarContainer(repository: repo);
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(authControllerProvider.notifier)
          .login(username: 'ali', password: 'wrong'),
      throwsA(isA<ApiException>()),
    );
    expect(
      container.read(authControllerProvider),
      isA<AuthUnauthenticated>(),
    );
  });

  test('خروج → پاکسازی و بدون احراز هویت', () async {
    final repo = FakeAuthRepository();
    final container = dadgarContainer(
      authStatus: const Authenticated('ali'),
      repository: repo,
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).logout();

    expect(repo.logoutCalls, 1);
    expect(
      container.read(authControllerProvider),
      isA<AuthUnauthenticated>(),
    );
  });
}
