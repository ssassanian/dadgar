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
import '../features/billing/presentation/admin_billing_screen.dart';
import '../features/billing/presentation/invoices_screen.dart';
import '../features/cases/presentation/case_detail_screen.dart';
import '../features/cases/presentation/cases_screen.dart';
import '../features/cases/presentation/new_case_screen.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/documents/presentation/upload_doc_screen.dart';
import '../features/home/home_screen.dart';
import '../features/messages/presentation/chat_screen.dart';
import '../features/messages/presentation/new_ticket_screen.dart';
import '../features/messages/presentation/ticket_detail_screen.dart';
import '../features/messages/presentation/tickets_screen.dart';
import '../features/messages/presentation/threads_screen.dart';
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
      GoRoute(
        path: '/invoices',
        builder: (context, state) => const InvoicesScreen(),
      ),
      GoRoute(
        path: '/admin/billing',
        builder: (context, state) => const AdminBillingScreen(),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) => const TicketsScreen(),
      ),
      GoRoute(
        path: '/tickets/new',
        builder: (context, state) => const NewTicketScreen(),
      ),
      GoRoute(
        path: '/tickets/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return TicketDetailScreen(ticketId: id);
        },
      ),
      GoRoute(
        path: '/threads',
        builder: (context, state) => const ThreadsScreen(),
      ),
      GoRoute(
        path: '/threads/:caseId',
        builder: (context, state) {
          final id =
              int.tryParse(state.pathParameters['caseId'] ?? '') ?? 0;
          return ChatScreen(caseId: id);
        },
      ),
      GoRoute(
        path: '/documents',
        builder: (context, state) => const DocumentsScreen(),
      ),
      GoRoute(
        path: '/documents/upload',
        builder: (context, state) => const UploadDocScreen(),
      ),
      GoRoute(
        path: '/cases/:id/upload',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return UploadDocScreen(caseId: id);
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
            '/cases/new' ||
            '/invoices' ||
            '/admin/billing' ||
            '/tickets' ||
            '/tickets/new' ||
            '/threads' ||
            '/documents' ||
            '/documents/upload' =>
              null,
            final l when _isCaseDetail(l) => null,
            final l when _isTicketDetail(l) => null,
            final l when _isThreadChat(l) => null,
            final l when _isCaseUpload(l) => null,
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

/// مسیر جزئیات تیکت — '/tickets/12' (خود '/tickets' و '/tickets/new' نیست)
bool _isTicketDetail(String location) {
  if (!location.startsWith('/tickets/')) return false;
  final rest = location.substring('/tickets/'.length);
  return rest.isNotEmpty && int.tryParse(rest) != null;
}

/// مسیر چت پرونده — '/threads/34'
bool _isThreadChat(String location) {
  if (!location.startsWith('/threads/')) return false;
  final rest = location.substring('/threads/'.length);
  return rest.isNotEmpty && int.tryParse(rest) != null;
}

/// مسیر بارگذاری سند به پرونده — '/cases/7/upload'
bool _isCaseUpload(String location) {
  if (!location.startsWith('/cases/')) return false;
  final rest = location.substring('/cases/'.length);
  if (!rest.endsWith('/upload')) return false;
  final id = rest.substring(0, rest.length - '/upload'.length);
  return id.isNotEmpty && int.tryParse(id) != null;
}
