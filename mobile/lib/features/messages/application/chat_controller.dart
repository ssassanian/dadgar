/// کنترلرهای چت پرونده — M5 (DOC-04 §۱۱ ردیف M5)
///
/// فهرست گفتگوها (پرونده‌های تخصیص‌یافته) + گفتگوی یک پرونده با ارسال پیام.
/// اعتبارسنجی آینه‌ی سرور: متن ۱..۲۰۰۰. خطای ۴۰۰ «گفتگو فعال نیست» و
/// ۴۲۹ سقف نرخ عیناً از سرور می‌آید و ماندگار نمایش داده می‌شود.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../data/messages_contract.dart';
import '../data/messages_repository.dart';
import '../domain/chat_models.dart';
import 'tickets_controller.dart'
    show LoadStatus, honestApiMessage; // اشتراک ماژولی

/// وضعیت UI فهرست گفتگوها
final class ThreadsUi {
  const ThreadsUi({
    this.status = LoadStatus.loading,
    this.rows = const [],
    this.message,
    this.isError = false,
  });

  final LoadStatus status;
  final List<Thread> rows;
  final String? message;
  final bool isError;

  ThreadsUi copyWith({
    LoadStatus? status,
    List<Thread>? rows,
    String? message,
    bool? isError,
    bool clearMessage = false,
  }) {
    return ThreadsUi(
      status: status ?? this.status,
      rows: rows ?? this.rows,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

/// کنترلر فهرست گفتگوها
final class ThreadsController extends Notifier<ThreadsUi> {
  MessagesRepository get _repo => ref.read(messagesRepositoryProvider);

  @override
  ThreadsUi build() {
    Future.microtask(_load);
    return const ThreadsUi();
  }

  Future<void> _load() async {
    state = state.copyWith(status: LoadStatus.loading, clearMessage: true);
    try {
      final rows = await _repo.fetchThreads();
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

/// وضعیت UI چت یک پرونده
final class ChatUi {
  const ChatUi({
    this.status = LoadStatus.loading,
    this.envelope,
    this.busy = false,
    this.message,
    this.isError = false,
  });

  final LoadStatus status;

  /// سربرگ پرونده + پیام‌ها — در ready پر می‌شود
  final ChatEnvelope? envelope;
  final bool busy;
  final String? message;
  final bool isError;

  ChatUi copyWith({
    LoadStatus? status,
    ChatEnvelope? envelope,
    bool? busy,
    String? message,
    bool? isError,
    bool clearMessage = false,
  }) {
    return ChatUi(
      status: status ?? this.status,
      envelope: envelope ?? this.envelope,
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

/// کنترلر چت پرونده — بارگذاری + ارسال + تازه‌سازی پس از ارسال
///
/// Riverpod 3: FamilyNotifier حذف شده — الگوی رسمی، Notifier با سازنده‌ی
/// آرگومان‌دار است (همان کشف ثبت‌شده‌ی CMD-023).
final class ChatController extends Notifier<ChatUi> {
  ChatController(this.arg);

  /// شناسه‌ی پرونده — از خانواده‌ی provider تزریق می‌شود
  final int arg;

  MessagesRepository get _repo => ref.read(messagesRepositoryProvider);

  @override
  ChatUi build() {
    Future.microtask(() => _load(arg));
    return const ChatUi();
  }

  Future<void> _load(int caseId) async {
    state = state.copyWith(status: LoadStatus.loading, clearMessage: true);
    try {
      final env = await _repo.fetchMessages(caseId: caseId);
      state = state.copyWith(
        status: LoadStatus.ready,
        envelope: env,
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

  /// ارسال پیام — موفقیت: پیام‌ها با پاسخ تازه‌ی سرور بازخوانی می‌شود
  Future<bool> send(String body) async {
    final error = MessagesContract.validateChatBody(body);
    if (error != null) {
      state = state.copyWith(message: error, isError: true);
      return false;
    }
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      await _repo.sendMessage(caseId: arg, body: body.trim());
      final env = await _repo.fetchMessages(caseId: arg);
      state = state.copyWith(
        busy: false,
        envelope: env,
        isError: false,
        clearMessage: true,
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

/// خانواده‌ی چت — بر شناسه‌ی پرونده (الگوی Riverpod 3: سازنده‌ی آرگومان‌دار)
final chatProvider =
    NotifierProvider.family<ChatController, ChatUi, int>(ChatController.new);

/// provider فهرست گفتگوها — M5
final threadsControllerProvider =
    NotifierProvider<ThreadsController, ThreadsUi>(ThreadsController.new);
