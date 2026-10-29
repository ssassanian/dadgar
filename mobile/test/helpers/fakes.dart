import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/features/appointments/data/appointments_repository.dart';
import 'package:dadgar_mobile/features/appointments/domain/appointment.dart';
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

/// مخزن نوبت‌دهی قابل تنظیم برای تست واحد — M3
final class FakeAppointmentsRepository implements AppointmentsRepository {
  FakeAppointmentsRepository({this.page, this.failWith});

  /// پاسخ موفق GET — اگر null باشد و failWith هم null باشد، صفحه‌ی خالی می‌سازد
  AppointmentsPage? page;

  /// اگر تنظیم شود، همه‌ی متدها این شیء را پرتاب می‌کنند
  Object? failWith;

  int fetchCalls = 0;
  int bookCalls = 0;
  int statusCalls = 0;
  final List<({int day, String slot, String kind})> bookArgs = [];
  final List<({int id, String status})> statusArgs = [];

  AppointmentsPage get _defaultPage => const AppointmentsPage(
        rows: [],
        taken: {},
        serverNowSeconds: 0,
        todayDay: 1,
      );

  @override
  Future<AppointmentsPage> fetch() async {
    fetchCalls++;
    final failure = failWith;
    if (failure != null) throw failure;
    return page ?? _defaultPage;
  }

  @override
  Future<int> book({
    required int day,
    required String slot,
    required String kind,
  }) async {
    bookCalls++;
    bookArgs.add((day: day, slot: slot, kind: kind));
    final failure = failWith;
    if (failure != null) throw failure;
    return 101;
  }

  @override
  Future<void> updateStatus({required int id, required String status}) async {
    statusCalls++;
    statusArgs.add((id: id, status: status));
    final failure = failWith;
    if (failure != null) throw failure;
  }
}

/// ساخت ProviderContainer با فیک‌های نشست — کمکی مشترک تست‌ها
ProviderContainer dadgarContainer({
  AuthStatus authStatus = const AuthUnauthenticated(),
  AppLockState lockState = const AppLockState(),
  FakeAuthRepository? repository,
  FakeAppointmentsRepository? appointmentsRepository,
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
      if (appointmentsRepository != null)
        appointmentsRepositoryProvider
            .overrideWithValue(appointmentsRepository),
      if (!realAuthController)
        authControllerProvider
            .overrideWith(() => FakeAuthController(authStatus)),
      if (!realAppLockController)
        appLockControllerProvider
            .overrideWith(() => FakeAppLockController(lockState)),
    ],
  );
}
