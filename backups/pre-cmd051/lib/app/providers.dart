import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../features/documents/data/documents_repository.dart';
import '../features/messages/data/messages_repository.dart';

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

/// مخزن پیام/تیکت — همان الگوی M2/M3 (dio + Bearer؛ فعال‌سازی زنده با D-6)
final messagesRepositoryProvider = Provider<MessagesRepository>(
  (ref) => DioMessagesRepository(
    client: ApiClient(tokenStore: ref.watch(tokenStoreProvider)),
  ),
);

/// مخزن اسناد — همان الگوی M2/M3 (dio + Bearer؛ فعال‌سازی زنده با D-6)
final documentsRepositoryProvider = Provider<DocumentsRepository>(
  (ref) => DioDocumentsRepository(
    client: ApiClient(tokenStore: ref.watch(tokenStoreProvider)),
  ),
);

/// M6 (CMD-028) — لانچر آدرس پرداخت درگاه (فقط https بیرونی)
/// در تست‌ها override می‌شود تا پلتفرم لمس نشود (§۹)
final payUrlLauncherProvider = Provider<Future<void> Function(String url)>(
  (ref) => (url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  },
);

/// M6 (CMD-028) — اشتراک‌گذاری PDF فاکتور (share sheet سیستم)
/// در تست‌ها override می‌شود؛ ذخیره‌ی موقت + SharePlus (API نسخه ۱۱)
final pdfShareProvider =
    Provider<Future<void> Function(String fileName, Uint8List bytes)>(
  (ref) => (fileName, bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]),
    );
  },
);
