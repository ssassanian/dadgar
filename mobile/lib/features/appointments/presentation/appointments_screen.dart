import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/d3_kit.dart';
import '../../../design/tokens.dart';
import '../application/appointments_controller.dart';
import '../data/appointments_contract.dart';

/// صفحه‌ی نوبت‌دهی M3 — تب پوسته (بدون AppBar؛ نوار بالای طرح)
///
/// CMD-046 (فاز ۳): بازطراحی D-3 عین طرح تاییدشده‌ی CMD-041 (`bAppt` در
/// `design-preview/prototype.html`): پنل تقویم با سربرگ ماه و قرص «امروز»،
/// نوار امضایی روز (آزاد/پر — فقط از داده‌ی واقعی بازه‌ها)، چیپ‌های بازه‌ی
/// پنج‌گانه و نوع ملاقات با kit و دکمه‌ی ثبت عین طرح.
///
/// صداقت داده (S-4): «وکیل: رضا محمدی» زیرعنوان data.js است — قرارداد
/// appointments نام وکیل نمی‌دهد → زیرعنوان صادقانه. نوار روز فقط وقتی
/// معنا دارد که فهرست نوبت‌ها رسیده باشد (با 401/D-6 همگی خنثی‌اند).
/// داده از GET /api/appointments می‌آید؛ تا حکم D-6 پاسخ 401 است و
/// پیام صادقانه با دکمه‌ی تلاش دوباره نمایش داده می‌شود.
class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(appointmentsControllerProvider);
    ref.listen(appointmentsControllerProvider, (previous, next) {
      final message = next.message;
      if (message == null || message.isEmpty) return;
      final isError = next.isError;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? DadgarTokens.error : DadgarTokens.accent,
          behavior: SnackBarBehavior.floating,
        ));
    });

    return Scaffold(
      backgroundColor: DadgarTokens.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: DadgarTokens.s16),
              child: DadgarTopBar(
                title: 'نوبت‌دهی',
                subtitle: 'رزرو ملاقات با وکیل',
              ),
            ),
            Expanded(
              child: switch (ui.status) {
                LoadStatus.loading => const Center(
                    child: CircularProgressIndicator(
                        color: DadgarTokens.primary),
                  ),
                LoadStatus.error => _ErrorPane(
                    message: ui.message ?? 'دریافت اطلاعات ناموفق بود',
                    onRetry: () => ref
                        .read(appointmentsControllerProvider.notifier)
                        .reload(),
                  ),
                LoadStatus.ready => const _CalendarBody(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// وضعیت خطا — صادقانه با تلاش دوباره
final class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DadgarTokens.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 48, color: DadgarTokens.error),
              const SizedBox(height: DadgarTokens.s16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 2,
                  color: DadgarTokens.textPrimary,
                ),
              ),
              const SizedBox(height: DadgarTokens.s24),
              DadgarGhostButton('تلاش دوباره', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

/// بدنه‌ی تقویم — ماه قرارداد «آبان ۱۴۰۵» با ۵ بازه‌ی ثابت روزانه
final class _CalendarBody extends ConsumerWidget {
  const _CalendarBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(appointmentsControllerProvider);
    final controller = ref.read(appointmentsControllerProvider.notifier);
    final monthLabel =
        '${JalaliCalendar.monthNames[AppointmentContract.contractMonth - 1]} '
        '${JalaliCalendar.toPersianDigits(AppointmentContract.contractYear)}';
    final selectedDay = ui.selectedDay;
    final inMonth = ui.todayDay >= 1 &&
        ui.todayDay <= AppointmentContract.monthDays;
    final todayText = inMonth
        ? 'امروز: ${JalaliCalendar.toPersianDigits(ui.todayDay)} '
            '${JalaliCalendar.monthNames[AppointmentContract.contractMonth - 1]}'
        : 'خارج از ماه قرارداد';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        DadgarTokens.s16,
        DadgarTokens.s12,
        DadgarTokens.s16,
        DadgarTokens.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── پنل تقویم — cal-head + cal عین طرح ──
          DadgarPanel(
            head: monthLabel,
            trailing: DadgarPill(todayText),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                const _WeekDayRow(),
                const SizedBox(height: DadgarTokens.s4),
                _DayGrid(
                  selectedDay: selectedDay,
                  todayDay: ui.todayDay,
                  isDayClosed: ui.isDayClosed,
                  hasData: ui.rows.isNotEmpty,
                  slotStateFor: ui.slotStateFor,
                  onSelect: controller.selectDay,
                ),
              ],
            ),
          ),
          const SizedBox(height: DadgarTokens.s12),
          if (selectedDay != null) ...[
            _SlotSection(
              day: selectedDay,
              selectedSlot: ui.selectedSlot,
              slotStateFor: ui.slotStateFor,
              onSelect: controller.selectSlot,
            ),
            const SizedBox(height: DadgarTokens.s12),
            _KindSection(
              selectedKind: ui.selectedKind,
              onSelect: controller.selectKind,
            ),
            const SizedBox(height: DadgarTokens.s16),
            _BookButton(day: selectedDay),
          ],
          const SizedBox(height: DadgarTokens.s16),
          DadgarGhostButton(
            'نوبت‌های من',
            onPressed: () => context.push('/appointments/mine'),
          ),
          const SizedBox(height: DadgarTokens.s12),
          const DadgarEmptyBox(
            'تقویم و بازه‌ها از سرور دادگر می‌آید (همان API سایت) — اتصال زنده '
            'پس از حکم مدیر بر D-6 فعال می‌شود؛ کد موبایل آماده است.',
          ),
        ],
      ),
    );
  }
}

/// ردیف نام روزهای هفته — شنبه تا جمعه (کلاس `.dow` — ۱۱px faint)
final class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final name in JalaliCalendar.weekDayNames)
          Expanded(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: DadgarTokens.textFaint,
              ),
            ),
          ),
      ],
    );
  }
}

/// شبکه‌ی روزهای ماه — آفست هفتگی نیتیو از تقویم جلالی
final class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.selectedDay,
    required this.todayDay,
    required this.isDayClosed,
    required this.hasData,
    required this.slotStateFor,
    required this.onSelect,
  });

  final int? selectedDay;
  final int todayDay;
  final bool Function(int) isDayClosed;
  final bool hasData;
  final SlotState Function(int, String) slotStateFor;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const monthDays = AppointmentContract.monthDays;
    final firstWeekIndex = JalaliCalendar.weekIndexOf(
      AppointmentContract.jalaliOfDay(1),
    );
    final cells = <Widget>[
      for (var i = 0; i < firstWeekIndex; i++) const _EmptyCell(),
      for (var d = 1; d <= monthDays; d++)
        _DayCell(
          day: d,
          isToday: d == todayDay,
          isSelected: d == selectedDay,
          isClosed: isDayClosed(d),
          barState: _barStateOf(d),
          onTap: () => onSelect(d),
        ),
    ];
    final rows = (cells.length + 6) ~/ 7;
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: (r * 7 + c) < cells.length
                      ? cells[r * 7 + c]
                      : const _EmptyCell(),
                ),
            ],
          ),
      ],
    );
  }

  /// نوار روز — فقط از داده‌ی واقعی بازه‌ها (S-4): پر = هر پنج بازه
  /// گرفته‌شده؛ آزاد = دست‌کم یک بازه‌ی آزاد؛ بقیه خنثی (`.bar` طرح)
  _DayBarState _barStateOf(int day) {
    if (!hasData || isDayClosed(day)) return _DayBarState.none;
    var free = 0;
    var taken = 0;
    for (final slot in AppointmentContract.slotLabels.values) {
      switch (slotStateFor(day, slot)) {
        case SlotState.free:
          free++;
        case SlotState.taken:
          taken++;
        case SlotState.past:
          break;
      }
    }
    if (taken == AppointmentContract.slotLabels.length) {
      return _DayBarState.booked;
    }
    if (free > 0) return _DayBarState.free;
    return _DayBarState.none;
  }
}

/// حالت نوار روز — عین `.bar` / `.bar.booked` / `.bar.free` طرح
enum _DayBarState { none, booked, free }

final class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) => const AspectRatio(
        aspectRatio: 1,
        child: SizedBox.shrink(),
      );
}

/// خانه‌ی یک روز — کلاس `.day` طرح: مربع گرد ۸، شماره ۱۳px، نوار ۴px
/// (امروز = لبه‌ی data و شماره‌ی ۶۰۰؛ انتخاب = زمینه‌ی active خنثی)
final class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isClosed,
    required this.barState,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final bool isClosed;
  final _DayBarState barState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = isClosed && !isSelected;
    final numColor = disabled
        ? DadgarTokens.textFaint.withValues(alpha: 0.45)
        : isToday
            ? DadgarTokens.primary
            : DadgarTokens.textPrimary;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: isSelected ? DadgarTokens.pillNeutralBg : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isToday
                ? const BorderSide(color: DadgarTokens.primary)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disabled ? null : onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  JalaliCalendar.toPersianDigits(day),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                    color: numColor,
                  ),
                ),
                const SizedBox(height: 4),
                // نوار امضایی — عرض ۷۰٪، ارتفاع ۴، گوشه‌ی ۲
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: switch (barState) {
                        _DayBarState.booked => DadgarTokens.primary,
                        _DayBarState.free => DadgarTokens.pillPositiveBg,
                        _DayBarState.none => DadgarTokens.rowRule,
                      },
                      border: barState == _DayBarState.free
                          ? Border.all(
                              color: DadgarTokens.pillPositiveInk,
                              width: 0.8,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// بازه‌های روز انتخاب‌شده — پنل با چیپ‌های kit (`.chips` طرح)
final class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.day,
    required this.selectedSlot,
    required this.slotStateFor,
    required this.onSelect,
  });

  final int day;
  final String? selectedSlot;
  final SlotState Function(int, String) slotStateFor;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final dateLabel = JalaliCalendar.formatLong(
      AppointmentContract.jalaliOfDay(day),
    );
    return DadgarPanel(
      head: 'بازه‌های $dateLabel',
      trailing: const DadgarPill('آزاد', variant: DadgarPillVariant.positive),
      child: Wrap(
        spacing: DadgarTokens.s8,
        runSpacing: DadgarTokens.s8,
        children: [
          for (final slot in AppointmentContract.slotLabels.values)
            switch (slotStateFor(day, slot)) {
              SlotState.free => DadgarChip(
                  slot,
                  selected: slot == selectedSlot,
                  onTap: () => onSelect(slot),
                ),
              SlotState.taken => DadgarChip('$slot (پر)', selected: false),
              SlotState.past => DadgarChip('$slot (گذشته)', selected: false),
            },
        ],
      ),
    );
  }
}

/// نوع ملاقات — همان سه مقدار قرارداد سرور
final class _KindSection extends StatelessWidget {
  const _KindSection({required this.selectedKind, required this.onSelect});

  final String selectedKind;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return DadgarPanel(
      head: 'نوع ملاقات',
      child: Wrap(
        spacing: DadgarTokens.s8,
        runSpacing: DadgarTokens.s8,
        children: [
          for (final kind in AppointmentContract.kinds)
            DadgarChip(
              kind,
              selected: kind == selectedKind,
              onTap: () => onSelect(kind),
            ),
        ],
      ),
    );
  }
}

/// دکمه‌ی رزرو — فعال فقط با بازه‌ی آزاد؛ برچسب عین bAppt طرح
final class _BookButton extends ConsumerWidget {
  const _BookButton({required this.day});

  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(appointmentsControllerProvider);
    final slot = ui.selectedSlot;
    final canBook = slot != null &&
        slot.isNotEmpty &&
        ui.slotStateFor(day, slot) == SlotState.free &&
        !ui.busy;
    final dateLabel = JalaliCalendar.formatLong(
      AppointmentContract.jalaliOfDay(day),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DadgarPrimaryButton(
          slot != null && slot.isNotEmpty
              ? 'ثبت نوبت — $dateLabel · ساعت $slot'
              : 'ثبت نوبت',
          onPressed: canBook
              ? () => ref.read(appointmentsControllerProvider.notifier).book()
              : null,
        ),
        if (slot == null || slot.isEmpty) ...[
          const SizedBox(height: DadgarTokens.s8),
          const Text(
            'ابتدا یک ساعت آزاد را انتخاب کنید.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: DadgarTokens.textFaint),
          ),
        ],
      ],
    );
  }
}
