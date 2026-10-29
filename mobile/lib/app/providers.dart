import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/secure/biometric_auth.dart';
import '../core/secure/token_store.dart';
import '../features/appointments/application/appointments_controller.dart';
import '../features/appointments/data/appointments_repository.dart';
import '../features/auth/application/app_lock_controller.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/billing/application/billing_controller.dart';
import '../features/billing/data/billing_repository.dart';
import '../features/cases/application/cases_controller.dart';
import '../features/cases/data/cases_repository.dart';

/// گراف وابستگی‌ها — نقطه‌ی واحد تزریق (M1)
///
/// در تست‌ها، هر provider با فِیک معادلش بازنویسی می‌شود؛
/// کد تولیدی هرگز مستقیماً پلتفرم را لمس نمی‌کند (قابلیت تست DOC-04 §۹).

/// ذخیره‌ی امن توکن — Keystore/Keychain در دستگاه واقعی
final tokenStoreProvider =
    Provider<TokenStore>((ref) => SecureTokenStore());

/// سرویس بیومتریک — local_auth در دستگاه واقعی
final biometricAuthProvider =
    Provider<BiometricAuth>((ref) => LocalAuthBiometric());

/// مخزن احراز هویت — dio + ذخیره‌ی امن
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DioAuthRepository(store: ref.watch(tokenStoreProvider)),
);

/// وضعیت نشست — splash → login/home
final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);

/// قفل بیومتریک اپ — وضعیت فعال/باز
final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);

/// کلاینت API نوبت‌دهی — همان الگوی M1 (dio + Bearer؛ فعال‌سازی زنده با D-6)
final appointmentsRepositoryProvider = Provider<AppointmentsRepository>(
  (ref) => DioAppointmentsRepository(
    client: ApiClient(tokenStore: ref.watch(tokenStoreProvider)),
  ),
);

/// وضعیت UI نوبت‌دهی — M3
final appointmentsControllerProvider =
    NotifierProvider<AppointmentsController, AppointmentsUi>(
  AppointmentsController.new,
);

/// مخزن پرونده‌ها — همان الگوی M3 (dio + Bearer؛ فعال‌سازی زنده با D-6)
final casesRepositoryProvider = Provider<CasesRepository>(
  (ref) => DioCasesRepository(
    client: ApiClient(tokenStore: ref.watch(tokenStoreProvider)),
  ),
);

/// وضعیت UI فهرست پرونده‌ها — M2
final casesControllerProvider =
    NotifierProvider<CasesController, CasesUi>(CasesController.new);

/// وضعیت UI ثبت پرونده جدید — M2
final createCaseControllerProvider =
    NotifierProvider<CreateCaseController, CreateCaseUi>(
  CreateCaseController.new,
);

/// جزئیات پرونده — FutureProvider.family بر شناسه (Riverpod 3) — M2
/// (تعریف در cases_controller.dart؛ اینجا فقط ارجاع مستند)
// caseDetailProvider در lib/features/cases/application/cases_controller.dart

/// مخزن مالی — همان الگوی M2/M3 (dio + Bearer؛ فعال‌سازی زنده با D-6)
final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => DioBillingRepository(
    client: ApiClient(tokenStore: ref.watch(tokenStoreProvider)),
  ),
);

/// وضعیت UI فهرست فاکتورها — M4
final billingControllerProvider =
    NotifierProvider<BillingController, BillingUi>(BillingController.new);
