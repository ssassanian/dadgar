/// کنترلر نشست کاربر — M6 (CMD-028)
///
/// نقشِ نشست از GET /api/me کشف می‌شود و با وضعیت نشست (authController)
/// واکنش‌گرا است: خروج/قفل = پاک شدن نقش؛ ورود دوباره = کشف تازه.
///
/// S-4: هیچ endpoint جدیدی اختراع نشده؛ S-5: ماژول مستقل از بقیه.
/// خطای کشف نقش حیاتی نیست — null یعنی کارت‌های مدیریتی مخفی می‌مانند
/// (قانون‌گذاری نهایی همیشه سمت سرور با ROLE('admin') است).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'auth_controller.dart';
import '../domain/session_user.dart';

/// کشف نقش نشست — autoDispose تا با تغییر وضعیت نشست تازه شود
final sessionMeProvider = FutureProvider.autoDispose<SessionUser?>(
  (ref) async {
    final auth = ref.watch(authControllerProvider);
    if (auth is! Authenticated) return null;
    final repo = ref.watch(authRepositoryProvider);
    return repo.fetchMe();
  },
  retry: (retryCount, error) => null, // خطا تکرار نمی‌خواهد — null = مخفی
);
