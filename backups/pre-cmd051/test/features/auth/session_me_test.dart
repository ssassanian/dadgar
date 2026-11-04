/// تست کشف نقش نشست — M6 (CMD-028): GET /api/me و gating پنل مدیر
library;

import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/auth/application/session_controller.dart';
import 'package:dadgar_mobile/features/auth/domain/session_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  group('SessionUser — تجزیه‌ی GET /api/me', () {
    test('مدیر: نقش admin → isAdmin درست', () {
      final u = SessionUser.fromJson({
        'id': 1,
        'role': 'admin',
        'name': 'مدیر سامانه',
        'username': 'admin_t',
        'email': '',
        'phone': '',
      });
      expect(u, isNotNull);
      expect(u!.isAdmin, isTrue);
      expect(u.name, 'مدیر سامانه');
    });

    test('مشتری/وکیل: isAdmin نادرست', () {
      final c = SessionUser.fromJson({
        'id': 2,
        'role': 'client',
        'name': 'مشتری',
        'username': 'client_t',
      });
      final l = SessionUser.fromJson({
        'id': 3,
        'role': 'lawyer',
        'name': 'وکیل',
        'username': 'lawyer_t',
      });
      expect(c!.isAdmin, isFalse);
      expect(l!.isAdmin, isFalse);
    });

    test('مهمان (user:null) → null — بدون کرش', () {
      expect(SessionUser.fromJson({}), isNull);
      expect(SessionUser.fromJson({'id': 1}), isNull); // بدون role
    });
  });

  group('sessionMeProvider — gating نقش‌محور', () {
    test('نشست معتبر + مدیر → SessionUser با isAdmin', () async {
      final repo = FakeAuthRepository()
        ..me = const SessionUser(
          id: 1,
          role: 'admin',
          name: 'مدیر',
          username: 'admin_t',
        );
      final container = dadgarContainer(
        authStatus: const Authenticated('admin_t'),
        repository: repo,
      );
      addTearDown(container.dispose);

      final me = await container.read(sessionMeProvider.future);
      expect(me, isNotNull);
      expect(me!.isAdmin, isTrue);
      expect(repo.fetchMeCalls, 1);
    });

    test('نشست معتبر مشتری → isAdmin نادرست', () async {
      final repo = FakeAuthRepository()
        ..me = const SessionUser(
          id: 2,
          role: 'client',
          name: 'مشتری',
          username: 'client_t',
        );
      final container = dadgarContainer(
        authStatus: const Authenticated('client_t'),
        repository: repo,
      );
      addTearDown(container.dispose);

      final me = await container.read(sessionMeProvider.future);
      expect(me!.isAdmin, isFalse);
    });

    test('بدون نشست → بدون فراخوانی /api/me — null', () async {
      final repo = FakeAuthRepository()
        ..me = const SessionUser(
          id: 1,
          role: 'admin',
          name: 'مدیر',
          username: 'admin_t',
        );
      final container = dadgarContainer(
        authStatus: const AuthUnauthenticated(),
        repository: repo,
      );
      addTearDown(container.dispose);

      final me = await container.read(sessionMeProvider.future);
      expect(me, isNull);
      expect(repo.fetchMeCalls, 0); // مهمان هرگز /api/me نمی‌زند
    });
  });
}
