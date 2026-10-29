import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

/// وضعیت قفل اپ — قفل اختیاری با بیومتریک (DOC-04 §۸ «ورود سریع»)
class AppLockState {
  const AppLockState({this.enabled = false, this.unlocked = false});

  /// آیا قفل بیومتریک توسط کاربر فعال شده است
  final bool enabled;

  /// آیا نشست جاری باز شده است (پس از unlock در طول عمر فرآیند)
  final bool unlocked;

  bool get needsUnlock => enabled && !unlocked;

  AppLockState copyWith({bool? enabled, bool? unlocked}) => AppLockState(
        enabled: enabled ?? this.enabled,
        unlocked: unlocked ?? this.unlocked,
      );
}

class AppLockController extends Notifier<AppLockState> {
  static const String _flagKey = 'dadgar.app_lock';

  @override
  AppLockState build() {
    Future.microtask(_load);
    return const AppLockState();
  }

  Future<void> _load() async {
    try {
      final enabled =
          await ref.read(tokenStoreProvider).readFlag(_flagKey);
      state = state.copyWith(enabled: enabled);
    } on Exception {
      // بدون قفل ادامه می‌دهیم — خرابی خواندن پرچم نباید اپ را مسدود کند
    }
  }

  /// تغییر وضعیت قفل از پروفایل — اگر دستگاه بیومتریک نداشته باشد
  /// فعال‌سازی ممکن نیست (خروجی false)
  Future<bool> setEnabled(bool value) async {
    if (value) {
      final biometric = ref.read(biometricAuthProvider);
      if (!await biometric.isAvailable()) return false;
    }
    await ref.read(tokenStoreProvider).saveFlag(_flagKey, value);
    state = AppLockState(enabled: value, unlocked: !value);
    return true;
  }

  void unlock() => state = state.copyWith(unlocked: true);

  /// پس از logout قفل هم ریست می‌شود
  void reset() => state = AppLockState(enabled: state.enabled);
}
