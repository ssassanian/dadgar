import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/appointments/presentation/appointments_screen.dart';
import '../features/appointments/presentation/my_appointments_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/lock_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/splash_view.dart';
import '../features/cases/presentation/case_detail_screen.dart';
import '../features/cases/presentation/cases_screen.dart';
import '../features/cases/presentation/new_case_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import 'providers.dart';

/// روتر اعلامی M1 با redirect مبتنی بر وضعیت نشست و قفل بیومتریک
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.listen(appLockControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
      GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/appointments',
        builder: (context, state) => const AppointmentsScreen(),
      ),
      GoRoute(
        path: '/appointments/mine',
        builder: (context, state) => const MyAppointmentsScreen(),
      ),
      GoRoute(
        path: '/cases',
        builder: (context, state) => const CasesScreen(),
      ),
      GoRoute(
        path: '/cases/new',
        builder: (context, state) => const NewCaseScreen(),
      ),
      GoRoute(
        path: '/cases/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return CaseDetailScreen(caseId: id);
        },
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final lock = ref.read(appLockControllerProvider);
      final location = state.matchedLocation;

      return switch (auth) {
        // تا پایان بازیابی نشست، همه‌جا اسپلش
        AuthUnknown() => location == '/splash' ? null : '/splash',
        AuthUnauthenticated() => switch (location) {
            '/login' || '/otp' => null,
            _ => '/login',
          },
        Authenticated() when lock.needsUnlock =>
          location == '/lock' ? null : '/lock',
        Authenticated() => switch (location) {
            '/' ||
            '/profile' ||
            '/appointments' ||
            '/appointments/mine' ||
            '/cases' ||
            '/cases/new' =>
              null,
            final l when _isCaseDetail(l) => null,
            _ => '/',
          },
      };
    },
  );
});

/// مسیر جزئیات پرونده — '/cases/123' (خود '/cases' و '/cases/new' نیست)
bool _isCaseDetail(String location) {
  if (!location.startsWith('/cases/')) return false;
  final rest = location.substring('/cases/'.length);
  return rest.isNotEmpty && int.tryParse(rest) != null;
}
