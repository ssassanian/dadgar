import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/features/auth/application/app_lock_controller.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/auth/data/auth_repository.dart';
import 'package:dadgar_mobile/core/secure/token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// کنترلر ثابت برای تست ویجت — بدون microtask بازیابی
final class FakeAuthController extends AuthController {
  FakeAuthController(this.initial);

  final AuthStatus initial;

  @override
  AuthStatus build() => initial;
}

/// کنترلر قفل ثابت برای تست ویجت
final class FakeAppLockController extends AppLockController {
  FakeAppLockController(this.initial);

  final AppLockState initial;

  @override
  AppLockState build() => initial;
}

/// مخزن احراز هویت قابل تنظیم برای تست واحد
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.failWith, TokenStore? store}) : _store = store;

  /// اگر تنظیم شود، login این شیء را پرتاب می‌کند
  final Object? failWith;
  final TokenStore? _store;

  String? storedUsername;
  int loginCalls = 0;
  int logoutCalls = 0;

  @override
  Future<String> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    final failure = failWith;
    if (failure != null) throw failure;
    storedUsername = username;
    await _store?.save(
      AuthTokens(
        access: 'test-access',
        refresh: 'test-refresh',
        username: username,
      ),
    );
    return username;
  }

  @override
  Future<String?> restoreSession() async {
    final store = _store;
    if (store != null) {
      final tokens = await store.read();
      if (tokens == null) return null;
      return tokens.username ?? 'کاربر دادگر';
    }
    return storedUsername;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    storedUsername = null;
    await _store?.clear();
  }
}

/// ساخت ProviderContainer با فیک‌های نشست — کمکی مشترک تست‌ها
ProviderContainer dadgarContainer({
  AuthStatus authStatus = const AuthUnauthenticated(),
  AppLockState lockState = const AppLockState(),
  FakeAuthRepository? repository,
  TokenStore? tokenStore,
  bool realAuthController = false,
  bool realAppLockController = false,
}) {
  final store = tokenStore ?? InMemoryTokenStore();
  final effectiveRepo = repository ?? FakeAuthRepository(store: store);
  return ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(effectiveRepo),
      if (!realAuthController)
        authControllerProvider
            .overrideWith(() => FakeAuthController(authStatus)),
      if (!realAppLockController)
        appLockControllerProvider
            .overrideWith(() => FakeAppLockController(lockState)),
    ],
  );
}
