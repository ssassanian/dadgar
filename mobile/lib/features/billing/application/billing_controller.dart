/// کنترلر مالی — M4 (DOC-04 §۱۱ ردیف M4)
///
/// نمای مشتری فقط خواندنی است: فهرست فاکتورهای خود کاربر + دکمه‌ی
/// «پرداخت آنلاین» با پیام صادقانه‌ی درگاه (تصمیم باز CMD-005 — هیچ
/// پرداخت جعلی ثبت نمی‌شود). منطق پیش از ارسال هیچ اعتبارسنجی POST
/// ندارد چون موبایل در این ماژول فقط GET می‌زند.
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
}
