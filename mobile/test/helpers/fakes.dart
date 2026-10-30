import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/appointments/data/appointments_repository.dart';
import 'package:dadgar_mobile/features/appointments/domain/appointment.dart';
import 'package:dadgar_mobile/features/auth/application/app_lock_controller.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/auth/application/session_controller.dart';
import 'package:dadgar_mobile/features/auth/data/auth_repository.dart';
import 'package:dadgar_mobile/features/auth/domain/session_user.dart';
import 'package:dadgar_mobile/features/billing/data/billing_repository.dart';
import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:dadgar_mobile/features/cases/data/cases_repository.dart';
import 'package:dadgar_mobile/features/documents/data/documents_repository.dart';
import 'package:dadgar_mobile/features/documents/domain/document_models.dart';
import 'package:dadgar_mobile/features/messages/data/messages_repository.dart';
import 'package:dadgar_mobile/features/messages/domain/chat_models.dart';
import 'package:dadgar_mobile/features/messages/domain/ticket_models.dart';
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

  /// M6 (CMD-028) — پاسخ GET /api/me (null = مهمان/خطا)
  SessionUser? me;
  int fetchMeCalls = 0;

  @override
  Future<SessionUser?> fetchMe() async {
    fetchMeCalls++;
    final failure = failWith;
    if (failure != null) {
      // کشف نقش حیاتی نیست — خطا = null (مثل پیاده‌سازی واقعی)
      return null;
    }
    return me;
  }

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
  int acceptProposalCalls = 0;
  int setCaseStatusCalls = 0;
  final List<({int page})> pageArgs = [];
  final List<({int id})> detailArgs = [];
  final List<({String category, String title, String description})>
      createArgs = [];
  final List<int> acceptProposalArgs = [];
  final List<({int id, String status})> setCaseStatusArgs = [];

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

  @override
  Future<void> acceptProposal({required int proposalId}) async {
    acceptProposalCalls++;
    acceptProposalArgs.add(proposalId);
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<void> setCaseStatus({required int id, required String status}) async {
    setCaseStatusCalls++;
    setCaseStatusArgs.add((id: id, status: status));
    final failure = failWith;
    if (failure != null) throw failure;
  }
}

/// مخزن مالی قابل تنظیم برای تست واحد — M4 + M6 (CMD-028)
final class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository({this.response, this.failWith});

  /// پاسخ موفق GET /api/invoices
  InvoicesResponse? response;

  /// اگر تنظیم شود، همه‌ی متدها این شیء را پرتاب می‌کنند
  Object? failWith;

  int calls = 0;

  // ── M6 (CMD-028) ──
  int issueCalls = 0;
  int statusCalls = 0;
  int clientsCalls = 0;
  int requestPaymentCalls = 0;
  final List<({int clientId, int amount})> issueArgs = [];
  final List<({int id, String status})> statusArgs = [];
  final List<int> requestPaymentArgs = [];
  int issuedId = 33;
  List<MinUser> clients = const [];

  /// نتیجه‌ی درخواست پرداخت — پیش‌فرض: 503 صادقانه (تا انتخاب درگاه)
  PayRequestResult paymentResult = const PayNotConfigured(
    'درگاه پرداخت هنوز متصل نشده است؛ پس از تصمیم مدیر فعال می‌شود.',
  );

  @override
  Future<InvoicesResponse> fetchInvoices() async {
    calls++;
    final failure = failWith;
    if (failure != null) throw failure;
    return response ?? const InvoicesResponse(rows: [], todayD: 1);
  }

  @override
  Future<int> issueInvoice({
    required int clientId,
    required int amount,
  }) async {
    issueCalls++;
    issueArgs.add((clientId: clientId, amount: amount));
    final failure = failWith;
    if (failure != null) throw failure;
    return issuedId;
  }

  @override
  Future<void> setInvoiceStatus({
    required int id,
    required String status,
  }) async {
    statusCalls++;
    statusArgs.add((id: id, status: status));
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<List<MinUser>> fetchClients() async {
    clientsCalls++;
    final failure = failWith;
    if (failure != null) throw failure;
    return clients;
  }

  @override
  Future<PayRequestResult> requestPayment({required int invoiceId}) async {
    requestPaymentCalls++;
    requestPaymentArgs.add(invoiceId);
    final failure = failWith;
    if (failure != null) throw failure;
    return paymentResult;
  }
}

/// مخزن پیام/تیکت قابل تنظیم برای تست واحد — M5
final class FakeMessagesRepository implements MessagesRepository {
  FakeMessagesRepository({
    this.tickets = const [],
    this.ticketDetails = const {},
    this.threads = const [],
    this.envelopes = const {},
    this.failWith,
  });

  List<TicketSummary> tickets;
  final Map<int, TicketDetail> ticketDetails;
  List<Thread> threads;
  final Map<int, ChatEnvelope> envelopes;
  Object? failWith;

  int ticketCalls = 0;
  int createTicketCalls = 0;
  int replyCalls = 0;
  int messageCalls = 0;
  int sendCalls = 0;
  final List<({String subject, String dept, String priority, String body})>
      createTicketArgs = [];
  final List<({int id, String body})> replyArgs = [];
  final List<({int caseId, String body})> sendArgs = [];
  int createdTicketId = 77;
  String replyStatus = 'answered';

  @override
  Future<List<TicketSummary>> fetchTickets() async {
    ticketCalls++;
    final f = failWith;
    if (f != null) throw f;
    return List.unmodifiable(tickets);
  }

  @override
  Future<int> createTicket({
    required String subject,
    required String dept,
    required String priority,
    required String body,
  }) async {
    createTicketCalls++;
    createTicketArgs.add(
      (subject: subject, dept: dept, priority: priority, body: body),
    );
    final f = failWith;
    if (f != null) throw f;
    return createdTicketId;
  }

  @override
  Future<TicketDetail> fetchTicket({required int id}) async {
    final f = failWith;
    if (f != null) throw f;
    final d = ticketDetails[id];
    if (d == null) {
      throw const ApiException('تیکت یافت نشد.', statusCode: 404);
    }
    return d;
  }

  @override
  Future<String> replyTicket({required int id, required String body}) async {
    replyCalls++;
    replyArgs.add((id: id, body: body));
    final f = failWith;
    if (f != null) throw f;
    return replyStatus;
  }

  @override
  Future<List<Thread>> fetchThreads() async {
    final f = failWith;
    if (f != null) throw f;
    return List.unmodifiable(threads);
  }

  @override
  Future<ChatEnvelope> fetchMessages({required int caseId}) async {
    messageCalls++;
    final f = failWith;
    if (f != null) throw f;
    final e = envelopes[caseId];
    if (e == null) {
      throw const ApiException('پرونده یافت نشد.', statusCode: 404);
    }
    return e;
  }

  @override
  Future<int> sendMessage({required int caseId, required String body}) async {
    sendCalls++;
    sendArgs.add((caseId: caseId, body: body));
    final f = failWith;
    if (f != null) throw f;
    return 900;
  }
}

/// مخزن اسناد قابل تنظیم برای تست واحد — M5
final class FakeDocumentsRepository implements DocumentsRepository {
  FakeDocumentsRepository({this.docs = const [], this.failWith});

  List<DocSummary> docs;
  Object? failWith;

  int listCalls = 0;
  int uploadCalls = 0;
  int downloadCalls = 0;
  int deleteCalls = 0;
  final List<({int caseId, String name, String mime, List<int> bytes})>
      uploadArgs = [];
  final List<int> downloadIds = [];
  final List<int> deleteIds = [];
  int uploadedId = 55;
  List<int> downloadedBytes = const [1, 2, 3];

  @override
  Future<List<DocSummary>> fetchDocuments() async {
    listCalls++;
    final f = failWith;
    if (f != null) throw f;
    return List.unmodifiable(docs);
  }

  @override
  Future<int> upload({
    required int caseId,
    required String name,
    required String mime,
    required List<int> bytes,
  }) async {
    uploadCalls++;
    uploadArgs.add(
      (caseId: caseId, name: name, mime: mime, bytes: bytes),
    );
    final f = failWith;
    if (f != null) throw f;
    return uploadedId;
  }

  @override
  Future<List<int>> download({required int id}) async {
    downloadCalls++;
    downloadIds.add(id);
    final f = failWith;
    if (f != null) throw f;
    return downloadedBytes;
  }

  @override
  Future<void> delete({required int id}) async {
    deleteCalls++;
    deleteIds.add(id);
    final f = failWith;
    if (f != null) throw f;
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
  FakeMessagesRepository? messagesRepository,
  FakeDocumentsRepository? documentsRepository,
  TokenStore? tokenStore,
  bool realAuthController = false,
  bool realAppLockController = false,

  /// M6 (CMD-028) — کاربر نشست ثابت برای sessionMeProvider
  /// (null = از فیک مخزن auth خوانده می‌شود — پیش‌فرض بدون نقش)
  SessionUser? sessionUser,
}) {
  final store = tokenStore ?? InMemoryTokenStore();
  final effectiveRepo = repository ?? FakeAuthRepository(store: store);
  return ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(effectiveRepo),
      if (sessionUser != null)
        sessionMeProvider.overrideWith((ref) => sessionUser),
      if (appointmentsRepository != null)
        appointmentsRepositoryProvider
            .overrideWithValue(appointmentsRepository),
      if (casesRepository != null)
        casesRepositoryProvider.overrideWithValue(casesRepository),
      if (billingRepository != null)
        billingRepositoryProvider.overrideWithValue(billingRepository),
      if (messagesRepository != null)
        messagesRepositoryProvider.overrideWithValue(messagesRepository),
      if (documentsRepository != null)
        documentsRepositoryProvider.overrideWithValue(documentsRepository),
      if (!realAuthController)
        authControllerProvider
            .overrideWith(() => FakeAuthController(authStatus)),
      if (!realAppLockController)
        appLockControllerProvider
            .overrideWith(() => FakeAppLockController(lockState)),
    ],
  );
}
