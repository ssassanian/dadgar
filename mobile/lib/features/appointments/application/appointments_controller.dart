/// کنترلر نوبت‌دهی — M3 (DOC-04 §۱۱ ردیف M3)
///
/// وضعیت UI تقویم + بازه‌ها + رزرو/لغو؛ منطق «گذشته/پر» دقیقاً هم‌ساز
/// قواعد سرور است (POST: زمان گذشته = 400، بازه‌ی پر = 409) تا پیش از
/// ارسال، بازه‌های بی‌فایده غیرفعال شوند و پیام‌ها با سرور یکدست بماند.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../data/appointments_contract.dart';
import '../data/appointments_repository.dart';
import '../domain/appointment.dart';

/// وضعیت بارگذاری داده‌ی نوبت‌دهی
enum LoadStatus { loading, ready, error }

/// وضعیت یک بازه برای انتخاب
enum SlotState { free, taken, past }

/// وضعیت UI نوبت‌دهی
final class AppointmentsUi {
  const AppointmentsUi({
    this.status = LoadStatus.loading,
    this.rows = const [],
    this.taken = const <String>{},
    this.serverNowSeconds = 0,
    this.todayDay = 1,
    this.selectedDay,
    this.selectedSlot,
    this.selectedKind = 'حضوری',
    this.busy = false,
    this.message,
    this.isError = false,
  });

  final LoadStatus status;
  final List<Appointment> rows;
  final Set<String> taken;
  final int serverNowSeconds;
  final int todayDay;
  final int? selectedDay;
  final String? selectedSlot;
  final String selectedKind;
  final bool busy;
  final String? message;
  final bool isError;

  /// وضعیت یک بازه — قواعد سرور: زمان گذشته یا اشغال‌شده غیرقابل رزرو
  SlotState slotStateFor(int day, String slot) {
    final minutes = AppointmentContract.slotMinutesOf(slot);
    if (minutes == null) return SlotState.taken;
    final startsAt = AppointmentContract.startsAtOf(day, minutes);
    if (startsAt <= serverNowSeconds) return SlotState.past;
    if (taken.contains(AppointmentContract.takenKey(day, slot))) {
      return SlotState.taken;
    }
    return SlotState.free;
  }

  /// آیا روز کاملاً بسته است (همه‌ی بازه‌ها گذشته یا پر)؟
  bool isDayClosed(int day) {
    for (final slot in AppointmentContract.slotLabels.values) {
      if (slotStateFor(day, slot) == SlotState.free) return false;
    }
    return true;
  }

  AppointmentsUi copyWith({
    LoadStatus? status,
    List<Appointment>? rows,
    Set<String>? taken,
    int? serverNowSeconds,
    int? todayDay,
    int? selectedDay,
    String? selectedSlot,
    String? selectedKind,
    bool? busy,
    String? message,
    bool? isError,
    bool clearMessage = false,
  }) {
    return AppointmentsUi(
      status: status ?? this.status,
      rows: rows ?? this.rows,
      taken: taken ?? this.taken,
      serverNowSeconds: serverNowSeconds ?? this.serverNowSeconds,
      todayDay: todayDay ?? this.todayDay,
      selectedDay: selectedDay ?? this.selectedDay,
      selectedSlot: selectedSlot ?? this.selectedSlot,
      selectedKind: selectedKind ?? this.selectedKind,
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

/// کنترلر اصلی نوبت‌دهی
final class AppointmentsController extends Notifier<AppointmentsUi> {
  AppointmentsRepository get _repo => ref.read(appointmentsRepositoryProvider);

  @override
  AppointmentsUi build() {
    Future.microtask(_load);
    return const AppointmentsUi();
  }

  Future<void> _load({bool clear = true}) async {
    state = state.copyWith(status: LoadStatus.loading, clearMessage: clear);
    try {
      final page = await _repo.fetch();
      final today = page.todayDay.clamp(1, AppointmentContract.monthDays);
      final todayClosed = AppointmentContract.isDayClosed(
        day: today,
        taken: page.taken,
        nowSeconds: page.serverNowSeconds,
      );
      final selectable = todayClosed
          ? _firstOpenDay(page, after: today) ?? today
          : today;
      state = state.copyWith(
        status: LoadStatus.ready,
        rows: page.rows,
        taken: page.taken,
        serverNowSeconds: page.serverNowSeconds,
        todayDay: page.todayDay,
        selectedDay: state.selectedDay ?? selectable,
        clearMessage: clear,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: LoadStatus.error,
        message: _honestMessage(e),
        isError: true,
      );
    }
  }

  /// پیام صادقانه — 401 تا حکم D-6 یعنی «اتصال زنده فعال نیست»
  String _honestMessage(ApiException e) {
    if (e.statusCode == 401) {
      return 'اتصال زنده به سرور پس از حکم مدیر بر D-6 فعال می‌شود — '
          'کد موبایل آماده است';
    }
    return e.message;
  }

  int? _firstOpenDay(AppointmentsPage page, {required int after}) {
    for (var d = after; d <= AppointmentContract.monthDays; d++) {
      if (!AppointmentContract.isDayClosed(
        day: d,
        taken: page.taken,
        nowSeconds: page.serverNowSeconds,
      )) {
        return d;
      }
    }
    return null;
  }

  /// تلاش دوباره برای بارگذاری
  Future<void> reload() => _load();

  void selectDay(int day) {
    state = state.copyWith(selectedDay: day, isError: false, clearMessage: true);
  }

  void selectSlot(String slot) {
    state = state.copyWith(selectedSlot: slot, isError: false, clearMessage: true);
  }

  void selectKind(String kind) {
    state = state.copyWith(selectedKind: kind, isError: false, clearMessage: true);
  }

  /// رزرو بازه‌ی انتخابی
  Future<void> book() async {
    final day = state.selectedDay;
    final slot = state.selectedSlot;
    if (day == null || slot == null) return;
    if (state.slotStateFor(day, slot) != SlotState.free) return;
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      await _repo.book(day: day, slot: slot, kind: state.selectedKind);
      state = state.copyWith(
        busy: false,
        message: 'نوبت ثبت شد — در انتظار تایید موسسه',
        isError: false,
      );
      await _load(clear: false);
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        message: _honestMessage(e),
        isError: true,
      );
    }
  }

  /// لغو نوبت خودم (موکل فقط لغو — قاعده‌ی سرور)
  Future<void> cancel(int id) async {
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      await _repo.updateStatus(id: id, status: 'canceled');
      state = state.copyWith(
        busy: false,
        message: 'نوبت لغو شد',
        isError: false,
      );
      await _load(clear: false);
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        message: _honestMessage(e),
        isError: true,
      );
    }
  }
}
