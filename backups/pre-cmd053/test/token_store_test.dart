import 'package:dadgar_mobile/core/secure/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryTokenStore — قرارداد ذخیره‌ی امن', () {
    test('خواندن بدون داده → null', () async {
      final store = InMemoryTokenStore();
      expect(await store.read(), isNull);
    });

    test('ذخیره و خواندن گردش کامل توکن‌ها', () async {
      final store = InMemoryTokenStore();
      await store.save(
        const AuthTokens(access: 'a1', refresh: 'r1', username: 'ali'),
      );
      final tokens = await store.read();
      expect(tokens, isNotNull);
      expect(tokens!.access, 'a1');
      expect(tokens.refresh, 'r1');
      expect(tokens.username, 'ali');
    });

    test('پاکسازی → بدون نشست', () async {
      final store = InMemoryTokenStore();
      await store.save(const AuthTokens(access: 'a1'));
      await store.clear();
      expect(await store.read(), isNull);
    });

    test('پرچم قفل اپ — ذخیره/خواندن', () async {
      final store = InMemoryTokenStore();
      expect(await store.readFlag('dadgar.app_lock'), isFalse);
      await store.saveFlag('dadgar.app_lock', true);
      expect(await store.readFlag('dadgar.app_lock'), isTrue);
    });
  });
}
