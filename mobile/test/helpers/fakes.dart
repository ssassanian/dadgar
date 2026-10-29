import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/appointments/data/appointments_repository.dart';
import 'package:dadgar_mobile/features/appointments/domain/appointment.dart';
import 'package:dadgar_mobile/features/auth/application/app_lock_controller.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/auth/data/auth_repository.dart';
import 'package:dadgar_mobile/features/billing/data/billing_repository.dart';
import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:dadgar_mobile/features/cases/data/cases_repository.dart';
import 'package:dadgar_mobile/features/cases/domain/case_models.dart';
import 'package:dadgar_mobile/core/secure/token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// کنترلر ثابت برای تست ویجت — بدون microtask بازیابی
final class FakeAuthController extends AuthController {
  FakeAuthController(this.initial);

  final AuthStatus initial;

  @override
  AuthStatus build() => initial;
}

/// کنترلر قفل ثابت برای تست ویجت
final class FakeAppLockController extends AppLockController {
  FakeAppLockController(this.initial);

  final AppLockState initial;

  @override
  AppLockState build() => initial;
}

/// مخزن احراز هویت قابل تنظیم برای تست واحد
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.failWith, TokenStore? store}) : _store = store;

  /// اگر تنظیم شود، login این شیء را پرتاب می‌کند
  final Object? failWith;
  final TokenStore? _store;

  String? storedUsername;
  int loginCalls = 0;
  int logoutCalls = 0;

  @override
  Future<String> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    final failure = failWith;
    if (failure != null) throw failure;
    storedUsername = username;
    await _store?.save(
      AuthTokens(
        access: 'test-access',
        refresh: 'test-refresh',
        username: username,
      ),
    );
    return username;
  }

  @override
  Future<String?> restoreSession() async {
    final store = _store;
    if (store != null) {
      final tokens = await store.read();
      if (tokens == null) return null;
      return tokens.username ?? 'کاربر دادگر';
    }
    return storedUsername;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    storedUsername = null;
    await _store?.clear();
  }
}

/// مخزن نوبت‌دهی قابل تنظیم برای تست واحد — M3
final class FakeAppointmentsRepository implements AppointmentsRepository {
  FakeAppointmentsRepository({this.page, this.failWith});

  /// پاسخ موفق GET — اگر null باشد و failWith هم null باشد، صفحه‌ی خالی می‌سازد
  AppointmentsPage? page;

  /// اگر تنظیم شود، همه‌ی متدها این شیء را پرتاب می‌کنند
  Object? failWith;

  int fetchCalls = 0;
  int bookCalls = 0;
  int statusCalls = 0;
  final List<({int day, String slot, String kind})> bookArgs = [];
  final List<({int id, String status})> statusArgs = [];

  AppointmentsPage get _defaultPage => const AppointmentsPage(
        rows: [],
        taken: {},
        serverNowSeconds: 0,
        todayDay: 1,
      );

  @override
  Future<AppointmentsPage> fetch() async {
    fetchCalls++;
    final failure = failWith;
    if (failure != null) throw failure;
    return page ?? _defaultPage;
  }

  @override
  Future<int> book({
    required int day,
    required String slot,
    required String kind,
  }) async {
    bookCalls++;
    bookArgs.add((day: day, slot: slot, kind: kind));
    final failure = failWith;
    if (failure != null) throw failure;
    return 101;
  }

  @override
  Future<void> updateStatus({required int id, required String status}) async {
    statusCalls++;
    statusArgs.add((id: id, status: status));
    final failure = failWith;
    if (failure != null) throw failure;
  }
}

/// مخزن پرونده‌ها قابل تنظیم برای تست واحد — M2
final class FakeCasesRepository implements CasesRepository {
  FakeCasesRepository({this.pages = const {}, this.details = const {}, this.failWith});

  /// پاسخ هر صفحه — کلید = شماره‌ی صفحه
  final Map<int, CasesPage> pages;

  /// پاسخ جزئیات — کلید = شناسه‌ی پرونده
  final Map<int, CaseDetail> details;

  /// اگر تنظیم شود، همه‌ی متدها این شیء را پرتاب می‌کنند
  Object? failWith;

  int pageCalls = 0;
  int detailCalls = 0;
  int createCalls = 0;
  final List<({int page})> pageArgs = [];
  final List<({int id})> detailArgs = [];
  final List<({String category, String title, String description})>
      createArgs = [];

  CasesPage _emptyPage(int page) => CasesPage(
        rows: const [],
        page: page,
        pages: 1,
        total: 0,
      );

  @override
  Future<CasesPage> fetchPage({required int page}) async {
    pageCalls++;
    pageArgs.add((page: page));
    final failure = failWith;
    if (failure != null) throw failure;
    return pages[page] ?? _emptyPage(page);
  }

  @override
  Future<CaseDetail> fetchDetail({required int id}) async {
    detailCalls++;
    detailArgs.add((id: id));
    final failure = failWith;
    if (failure != null) throw failure;
    final detail = details[id];
    if (detail == null) {
      throw const ApiException(
        'پرونده یافت نشد.',
        statusCode: 404,
      );
    }
    return detail;
  }

  @override
  Future<int> create({
    required String category,
    required String title,
    required String description,
  }) async {
    createCalls++;
    createArgs.add((category: category, title: title, description: description));
    final failure = failWith;
    if (failure != null) throw failure;
    return 201;
  }
}

/// مخزن مالی قابل تنظیم برای تست واحد — M4
final class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository({this.response, this.failWith});

  /// پاسخ موفق GET /api/invoices
  InvoicesResponse? response;

  /// اگر تنظیم شود، fetchInvoices این شیء را پرتاب می‌کند
  Object? failWith;

  int calls = 0;

  @override
  Future<InvoicesResponse> fetchInvoices() async {
    calls++;
    final failure = failWith;
    if (failure != null) throw failure;
    return response ?? const InvoicesResponse(rows: [], todayD: 1);
  }
}

/// ساخت ProviderContainer با فیک‌های نشست — کمکی مشترک تست‌ها
ProviderContainer dadgarContainer({
  AuthStatus authStatus = const AuthUnauthenticated(),
  AppLockState lockState = const AppLockState(),
  FakeAuthRepository? repository,
  FakeAppointmentsRepository? appointmentsRepository,
  FakeCasesRepository? casesRepository,
  FakeBillingRepository? billingRepository,
  TokenStore? tokenStore,
  bool realAuthController = false,
  bool realAppLockController = false,
}) {
  final store = tokenStore ?? InMemoryTokenStore();
  final effectiveRepo = repository ?? FakeAuthRepository(store: store);
  return ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(effectiveRepo),
      if (appointmentsRepository != null)
        appointmentsRepositoryProvider
            .overrideWithValue(appointmentsRepository),
      if (casesRepository != null)
        casesRepositoryProvider.overrideWithValue(casesRepository),
      if (billingRepository != null)
        billingRepositoryProvider.overrideWithValue(billingRepository),
      if (!realAuthController)
        authControllerProvider
            .overrideWith(() => FakeAuthController(authStatus)),
      if (!realAppLockController)
        appLockControllerProvider
            .overrideWith(() => FakeAppLockController(lockState)),
    ],
  );
}
