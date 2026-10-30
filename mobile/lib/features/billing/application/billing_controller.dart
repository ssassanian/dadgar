/// کنترلر مالی — M4 (DOC-04 §۱۱ ردیف M4) + M6 (CMD-028)
///
/// نمای مشتری: فهرست فاکتورهای خود کاربر + دکمه‌ی «پرداخت آنلاین» که حالا
/// POST /api/payments/request می‌زند — تا انتخاب درگاه (CMD بعدی) سرور 503
/// با عین پیام صادقانه می‌دهد؛ هیچ پرداخت جعلی ثبت نمی‌شود.
/// نمای مدیر (M6): صدور فاکتور دستی + ثبت پرداخت/بازکردن — همان قرارداد
/// CMD-005 که از قبل روی سرور بوده است (S-4).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../data/billing_repository.dart';
import '../domain/invoice_models.dart';

/// وضعیت بارگذاری داده — مشترک بین کنترلرهای ماژول (الگوی M2/M3:
/// هر فیچر نسخه‌ی خودش را دارد تا از هم جدا بمانند — S-5)
enum LoadStatus { loading, ready, error }

/// وضعیت UI فهرست فاکتورها
final class BillingUi {
  const BillingUi({
    this.status = LoadStatus.loading,
    this.rows = const [],
    this.todayD = 1,
    this.busy = false,
    this.message,
    this.isError = false,
  });

  final LoadStatus status;
  final List<Invoice> rows;

  /// «امروز» جلالی تهران از سرور (today_d) — برای نوار بالای فهرست
  final int todayD;
  final bool busy;
  final String? message;
  final bool isError;

  /// جمع مبلغ فاکتورهای پرداخت‌شده — تومان
  int get paidTotal => rows
      .where((r) => r.statusValue == InvoiceStatus.paid)
      .fold(0, (a, r) => a + r.amount);

  /// شمار فاکتورهای در انتظار
  int get pendingCount =>
      rows.where((r) => r.statusValue == InvoiceStatus.pending).length;

  BillingUi copyWith({
    LoadStatus? status,
    List<Invoice>? rows,
    int? todayD,
    bool? busy,
    String? message,
    bool? isError,
    bool clearMessage = false,
  }) {
    return BillingUi(
      status: status ?? this.status,
      rows: rows ?? this.rows,
      todayD: todayD ?? this.todayD,
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

/// کنترلر فهرست فاکتورها — قرارداد تخت سرور (بدون صفحه‌بندی)
final class BillingController extends Notifier<BillingUi> {
  BillingRepository get _repo => ref.read(billingRepositoryProvider);

  @override
  BillingUi build() {
    Future.microtask(_load);
    return const BillingUi();
  }

  /// پیام صادقانه — 401 تا حکم D-6 یعنی «اتصال زنده فعال نیست»
  String _honestMessage(ApiException e) {
    if (e.statusCode == 401) {
      return 'اتصال زنده به سرور پس از حکم مدیر بر D-6 فعال می‌شود — '
          'کد موبایل آماده است';
    }
    return e.message;
  }

  Future<void> _load() async {
    state = state.copyWith(status: LoadStatus.loading, clearMessage: true);
    try {
      final res = await _repo.fetchInvoices();
      state = state.copyWith(
        status: LoadStatus.ready,
        rows: res.rows,
        todayD: res.todayD,
        isError: false,
        clearMessage: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: LoadStatus.error,
        message: _honestMessage(e),
        isError: true,
      );
    }
  }

  /// تلاش دوباره (همراه pull-to-refresh)
  Future<void> reload() => _load();

  /// M6 — درخواست پرداخت آنلاین فاکتور خودی (اسکلت بی‌طرف CMD-028):
  /// پیام نتیجه در state.message می‌نشیند؛ خروجی برای لانچر pay_url
  Future<PayRequestResult?> requestPayment(int invoiceId) async {
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final result = await _repo.requestPayment(invoiceId: invoiceId);
      state = state.copyWith(
        busy: false,
        isError: false,
        message: switch (result) {
          PayNotConfigured(:final message) => message,
          PayUrlReady() => null, // لانچر در صفحه؛ پیام لازم نیست
        },
      );
      return result;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, message: _honestMessage(e), isError: true);
      return null;
    }
  }

  /// M6 — صدور فاکتور دستی (فقط مدیر) → شناسه در موفقیت، وگرنه null
  Future<int?> issueInvoice({required int clientId, required int amount}) async {
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final id = await _repo.issueInvoice(clientId: clientId, amount: amount);
      await _load(); // فهرست تازه — بعدش پیام می‌نشیند تا _load پاکش نکند
      state = state.copyWith(
        busy: false,
        isError: false,
        message: 'فاکتور صادر شد.',
      );
      return id;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, message: _honestMessage(e), isError: true);
      return null;
    }
  }

  /// M6 — ثبت پرداخت/بازکردن (فقط مدیر)
  Future<bool> setInvoiceStatus({required int id, required String status}) async {
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      await _repo.setInvoiceStatus(id: id, status: status);
      await _load(); // فهرست تازه — بعدش پیام می‌نشیند تا _load پاکش نکند
      state = state.copyWith(
        busy: false,
        isError: false,
        message: status == 'paid' ? 'پرداخت ثبت شد.' : 'فاکتور بازگشایی شد.',
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, message: _honestMessage(e), isError: true);
      return false;
    }
  }
}

/// M6 — فهرست حداقلی مشتری‌ها برای فرم صدور (GET /api/users?role=client)
/// autoDispose: با هر باز شدن فرم تازه می‌شود
final billingClientsProvider = FutureProvider.autoDispose<List<MinUser>>(
  (ref) async {
    final repo = ref.watch(billingRepositoryProvider);
    return repo.fetchClients();
  },
  retry: (retryCount, error) => null, // خطای ۴xx تکرار نمی‌خواهد
);
