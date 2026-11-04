import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// جفت توکن نشست موبایل — الگوی access (کوتاه‌عمر) + refresh (چرخشی)
/// مطابق DOC-04 §۵-۲
class AuthTokens {
  const AuthTokens({required this.access, this.refresh, this.username});

  final String access;
  final String? refresh;
  final String? username;
}

/// قرارداد ذخیره‌ی امن — پیاده‌سازی واقعی روی Android Keystore / iOS Keychain
/// (DOC-04 §۸: هرگز SharedPreferences یا فایل ساده)
abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> save(AuthTokens tokens);
  Future<void> clear();
  Future<bool> readFlag(String key);
  Future<void> saveFlag(String key, bool value);
}

/// پیاده‌سازی امن با flutter_secure_storage (نسخه 10.x)
final class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _accessKey = 'dadgar.auth.access';
  static const String _refreshKey = 'dadgar.auth.refresh';
  static const String _usernameKey = 'dadgar.auth.username';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    final access = await _storage.read(key: _accessKey);
    if (access == null || access.isEmpty) return null;
    final refresh = await _storage.read(key: _refreshKey);
    final username = await _storage.read(key: _usernameKey);
    return AuthTokens(access: access, refresh: refresh, username: username);
  }

  @override
  Future<void> save(AuthTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.access);
    final refresh = tokens.refresh;
    if (refresh == null) {
      await _storage.delete(key: _refreshKey);
    } else {
      await _storage.write(key: _refreshKey, value: refresh);
    }
    final username = tokens.username;
    if (username == null) {
      await _storage.delete(key: _usernameKey);
    } else {
      await _storage.write(key: _usernameKey, value: username);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _usernameKey);
  }

  @override
  Future<bool> readFlag(String key) async {
    final value = await _storage.read(key: key);
    return value == 'true';
  }

  @override
  Future<void> saveFlag(String key, bool value) =>
      _storage.write(key: key, value: value ? 'true' : 'false');
}

/// پیاده‌سازی حافظه‌ای برای تست‌ها و جریان‌های بدون پلتفرم
final class InMemoryTokenStore implements TokenStore {
  final Map<String, String> _values = {};

  AuthTokens? _tokens;
  bool _hasTokens = false;

  @override
  Future<AuthTokens?> read() async => _hasTokens ? _tokens : null;

  @override
  Future<void> save(AuthTokens tokens) async {
    _tokens = tokens;
    _hasTokens = true;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
    _hasTokens = false;
    _values.remove('dadgar.app_lock');
  }

  @override
  Future<bool> readFlag(String key) async => _values[key] == 'true';

  @override
  Future<void> saveFlag(String key, bool value) async {
    _values[key] = value ? 'true' : 'false';
  }
}
