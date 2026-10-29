import 'package:local_auth/local_auth.dart';

/// قرارداد بیومتریک — بازکردن اپ با اثر انگشت/Face (DOC-04 §۸ «ورود سریع»)
///
/// رمز اصلی هرگز بیومتریک نمی‌شود؛ بیومتریک فقط درِ بازکردن اپ با توکن زنده است.
abstract interface class BiometricAuth {
  Future<bool> isAvailable();
  Future<bool> authenticate({required String reason});
}

/// پیاده‌سازی واقعی با local_auth
final class LocalAuthBiometric implements BiometricAuth {
  LocalAuthBiometric({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on Exception {
      return false;
    }
  }
}
