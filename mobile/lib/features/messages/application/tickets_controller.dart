/// کنترلرهای تیکت — M5 (DOC-04 §۱۱ ردیف M5)
///
/// سه وضعیت UI: فهرست، ساخت تیکت جدید، گفتگوی تیکت. اعتبارسنجی پیش از
/// ارسال آینه‌ی قواعد سرور است (subject ۳..۱۲۰، body ۳..۳۰۰۰، پاسخ
/// ۱..۳۰۰۰) تا پیام‌ها با سرور یکدست بماند. پس از پاسخ موفق، جزئیات
/// با وضعیت بازگشتی سرور تازه‌سازی می‌شود.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../data/messages_contract.dart';
import '../data/messages_repository.dart';
import '../domain/ticket_models.dart';

/// وضعیت بارگذاری — الگوی ماژول‌ها (هر فیچر نسخه‌ی خودش — S-5)
enum LoadStatus { loading, ready, error }

/// پیام صادقانه — 401 تا حکم D-6 یعنی «اتصال زنده فعال نیست»
String honestApiMessage(ApiException e) {
  if (e.statusCode == 401) {
    return 'اتصال زنده به سرور پس از حکم مدیر بر D-6 فعال می‌شود — '
        'کد موبایل آماده است';
  }
  return e.message;
}

/// وضعیت UI فهرست تیکت‌ها
final class TicketsUi {
  const TicketsUi({
    this.status = LoadStatus.loading,
    this.rows = const [],
    this.busy = false,
    this.message,
    this.isError = false,
  });

  final LoadStatus status;
  final List<TicketSummary> rows;
  final bool busy;
  final String? message;
  final bool isError;

  TicketsUi copyWith({
    LoadStatus? status,
    List<TicketSummary>? rows,
    bool? busy,
    String? message,
    bool? isError,
    bool clearMessage = false,
  }) {
    return TicketsUi(
      status: status ?? this.status,
      rows: rows ?? this.rows,
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

/// کنترلر فهرست تیکت‌ها
final class TicketsController extends Notifier<TicketsUi> {
  MessagesRepository get _repo => ref.read(messagesRepositoryProvider);

  @override
  TicketsUi build() {
    Future.microtask(_load);
    return const TicketsUi();
  }

  Future<void> _load() async {
    state = state.copyWith(status: LoadStatus.loading, clearMessage: true);
    try {
      final rows = await _repo.fetchTickets();
      state = state.copyWith(
        status: LoadStatus.ready,
        rows: rows,
        isError: false,
        clearMessage: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: LoadStatus.error,
        message: honestApiMessage(e),
        isError: true,
      );
    }
  }

  Future<void> reload() => _load();
}

/// وضعیت UI ساخت تیکت جدید
final class NewTicketUi {
  const NewTicketUi({
    this.subject = '',
    this.dept = '',
    this.priority = '',
    this.body = '',
    this.busy = false,
    this.doneId,
    this.message,
    this.isError = false,
  });

  final String subject;
  final String dept;
  final String priority;
  final String body;
  final bool busy;

  /// شناسه‌ی تیکت ساخته‌شده — موفقیت
  final int? doneId;
  final String? message;
  final bool isError;

  NewTicketUi copyWith({
    String? subject,
    String? dept,
    String? priority,
    String? body,
    bool? busy,
    int? doneId,
    String? message,
    bool? isError,
    bool clearMessage = false,
  }) {
    return NewTicketUi(
      subject: subject ?? this.subject,
      dept: dept ?? this.dept,
      priority: priority ?? this.priority,
      body: body ?? this.body,
      busy: busy ?? this.busy,
      doneId: doneId ?? this.doneId,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

/// کنترلر ساخت تیکت — اعتبارسنجی آینه‌ی سرور قبل از POST
final class NewTicketController extends Notifier<NewTicketUi> {
  MessagesRepository get _repo => ref.read(messagesRepositoryProvider);

  @override
  NewTicketUi build() => const NewTicketUi();

  void setSubject(String v) =>
      state = state.copyWith(subject: v, isError: false, clearMessage: true);

  void setDept(String v) =>
      state = state.copyWith(dept: v, isError: false, clearMessage: true);

  void setPriority(String v) =>
      state = state.copyWith(priority: v, isError: false, clearMessage: true);

  void setBody(String v) =>
      state = state.copyWith(body: v, isError: false, clearMessage: true);

  /// ثبت — برمی‌گرداند شناسه‌ی تیکت در موفقیت، وگرنه null
  Future<int?> submit() async {
    final subjectError = MessagesContract.validateSubject(state.subject);
    final bodyError = MessagesContract.validateTicketBody(state.body);
    if (!MessagesContract.tkDepts.contains(state.dept)) {
      state = state.copyWith(message: 'بخش را انتخاب کنید', isError: true);
      return null;
    }
    if (!MessagesContract.tkPris.contains(state.priority)) {
      state = state.copyWith(message: 'اولویت را انتخاب کنید', isError: true);
      return null;
    }
    if (subjectError != null || bodyError != null) {
      state = state.copyWith(
        message: subjectError ?? bodyError,
        isError: true,
      );
      return null;
    }
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final id = await _repo.createTicket(
        subject: state.subject.trim(),
        dept: state.dept,
        priority: state.priority,
        body: state.body.trim(),
      );
      state = state.copyWith(
        busy: false,
        doneId: id,
        message: 'تیکت ثبت شد — در انتظار پاسخ پشتیبانی',
        isError: false,
      );
      return id;
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        message: honestApiMessage(e),
        isError: true,
      );
      return null;
    }
  }
}

/// وضعیت UI گفتگوی یک تیکت
final class TicketDetailUi {
  const TicketDetailUi({
    this.status = LoadStatus.loading,
    this.detail,
    this.busy = false,
    this.message,
    this.isError = false,
  });

  final LoadStatus status;

  /// جزئیات تیکت — در وضعیت ready پر می‌شود
  final TicketDetail? detail;
  final bool busy;

  /// پیام وضعیت (خطا یا پیام موفقیت پاسخ)
  final String? message;
  final bool isError;

  /// تیکت بسته → پاسخ غیرفعال با پیام سرور
  bool get isClosed => detail?.statusValue == TicketStatus.closed;

  TicketDetailUi copyWith({
    LoadStatus? status,
    TicketDetail? detail,
    bool? busy,
    String? message,
    bool? isError,
    bool clearMessage = false,
  }) {
    return TicketDetailUi(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

/// کنترلر گفتگوی تیکت — بارگذاری + پاسخ + تازه‌سازی با وضعیت سرور
///
/// Riverpod 3: FamilyNotifier حذف شده — الگوی رسمی، Notifier با سازنده‌ی
/// آرگومان‌دار است (آرگومان فیلد خود کلاس می‌شود؛ build() بدون ورودی).
final class TicketDetailController extends Notifier<TicketDetailUi> {
  TicketDetailController(this.arg);

  /// شناسه‌ی تیکت — از خانواده‌ی provider تزریق می‌شود
  final int arg;

  MessagesRepository get _repo => ref.read(messagesRepositoryProvider);

  @override
  TicketDetailUi build() {
    Future.microtask(() => _load(arg));
    return const TicketDetailUi();
  }

  Future<void> _load(int id) async {
    state = state.copyWith(status: LoadStatus.loading, clearMessage: true);
    try {
      final detail = await _repo.fetchTicket(id: id);
      state = state.copyWith(
        status: LoadStatus.ready,
        detail: detail,
        isError: false,
        clearMessage: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: LoadStatus.error,
        message: honestApiMessage(e),
        isError: true,
      );
    }
  }

  Future<void> reload() => _load(arg);

  /// ارسال پاسخ — موفقیت: جزئیات با وضعیت جدید سرور بازخوانی می‌شود
  Future<bool> sendReply(String body) async {
    final error = MessagesContract.validateReplyBody(body);
    if (error != null) {
      state = state.copyWith(message: error, isError: true);
      return false;
    }
    if (state.isClosed) {
      state = state.copyWith(
        message: MessagesContract.ticketClosedMessage,
        isError: true,
      );
      return false;
    }
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      await _repo.replyTicket(id: arg, body: body.trim());
      final detail = await _repo.fetchTicket(id: arg);
      state = state.copyWith(
        busy: false,
        detail: detail,
        message: 'پاسخ ارسال شد',
        isError: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        message: honestApiMessage(e),
        isError: true,
      );
      return false;
    }
  }
}

/// خانواده‌ی گفتگوی تیکت — بر شناسه‌ی تیکت (الگوی Riverpod 3: سازنده‌ی آرگومان‌دار)
final ticketDetailProvider =
    NotifierProvider.family<TicketDetailController, TicketDetailUi, int>(
  TicketDetailController.new,
);

/// provider فهرست تیکت‌ها — M5
final ticketsControllerProvider =
    NotifierProvider<TicketsController, TicketsUi>(TicketsController.new);

/// provider ثبت تیکت جدید — M5
final newTicketControllerProvider =
    NotifierProvider<NewTicketController, NewTicketUi>(
  NewTicketController.new,
);
