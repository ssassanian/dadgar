import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

/// وضعیت احراز هویت — سه حالت بسته (splash → login/home → lock)
sealed class AuthStatus {
  const AuthStatus();
}

/// در حال بازیابی نشست از ذخیره‌ی امن
final class AuthUnknown extends AuthStatus {
  const AuthUnknown();
}

/// بدون نشست معتبر
final class AuthUnauthenticated extends AuthStatus {
  const AuthUnauthenticated();
}

/// نشست معتبر با نام کاربری
final class Authenticated extends AuthStatus {
  const Authenticated(this.username);

  final String username;
}

/// کنترلر نشست — Riverpod 3 Notifier (DOC-04 §۴: state compile-safe)
class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    // بازیابی نشست پس از اولین فریم — بدون مسدود کردن اجرای اپ
    Future.microtask(restore);
    return const AuthUnknown();
  }

  Future<void> restore() async {
    try {
      final username =
          await ref.read(authRepositoryProvider).restoreSession();
      state = username == null
          ? const AuthUnauthenticated()
          : Authenticated(username);
    } on Exception {
      state = const AuthUnauthenticated();
    }
  }

  /// ورود — true = موفق؛ خطا به UI برای نمایش پیام صادقانه پرتاب می‌شود
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    final resolved =
        await ref.read(authRepositoryProvider).login(
              username: username,
              password: password,
            );
    state = Authenticated(resolved);
    return true;
  }

  /// خروج از دستگاه — همیشه وضعیت محلی پاک می‌شود
  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const AuthUnauthenticated();
    }
  }
}
