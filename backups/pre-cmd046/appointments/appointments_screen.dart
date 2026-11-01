import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/tokens.dart';
import '../application/appointments_controller.dart';
import '../data/appointments_contract.dart';

/// صفحه‌ی نوبت‌دهی M3 — تقویم شمسی نیتیو + بازه‌های ثابت قرارداد سرور
///
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
      appBar: AppBar(
        title: const Text('نوبت‌دهی'),
        actions: [
          IconButton(
            tooltip: 'نوبت‌های من',
            onPressed: () => context.go('/appointments/mine'),
            icon: const Icon(Icons.event_note_outlined),
          ),
        ],
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(
            child: CircularProgressIndicator(color: DadgarTokens.primary),
          ),
        LoadStatus.error => _ErrorPane(
            message: ui.message ?? 'دریافت اطلاعات ناموفق بود',
            onRetry: () =>
                ref.read(appointmentsControllerProvider.notifier).reload(),
          ),
        LoadStatus.ready => const _CalendarBody(),
      },
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
                  size: 48, color: DadgarTokens.textSecondary),
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
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: DadgarTokens.primary,
                  foregroundColor: DadgarTokens.onPrimary,
                ),
                child: const Text('تلاش دوباره'),
              ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DadgarTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthHeader(label: monthLabel, todayDay: ui.todayDay),
          const SizedBox(height: DadgarTokens.s12),
          const _WeekDayRow(),
          const SizedBox(height: DadgarTokens.s8),
          _DayGrid(
            selectedDay: selectedDay,
            todayDay: ui.todayDay,
            isDayClosed: ui.isDayClosed,
            onSelect: controller.selectDay,
          ),
          const SizedBox(height: DadgarTokens.s16),
          if (selectedDay != null) ...[
            _SlotSection(
              day: selectedDay,
              selectedSlot: ui.selectedSlot,
              slotStateFor: ui.slotStateFor,
              onSelect: controller.selectSlot,
            ),
            const SizedBox(height: DadgarTokens.s16),
            _KindSection(
              selectedKind: ui.selectedKind,
              onSelect: controller.selectKind,
            ),
            const SizedBox(height: DadgarTokens.s24),
            _BookButton(day: selectedDay),
          ],
          const SizedBox(height: DadgarTokens.s16),
          const _HonestNote(),
        ],
      ),
    );
  }
}

/// سربرگ ماه — «آبان ۱۴۰۵ · امروز: روز ۷»
final class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label, required this.todayDay});

  final String label;
  final int todayDay;

  @override
  Widget build(BuildContext context) {
    final inMonth = todayDay >= 1 && todayDay <= AppointmentContract.monthDays;
    final todayText = inMonth
        ? 'امروز: ${JalaliCalendar.toPersianDigits(todayDay)} '
            '${JalaliCalendar.monthNames[AppointmentContract.contractMonth - 1]}'
        : 'خارج از ماه قرارداد';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DadgarTokens.s16),
      decoration: BoxDecoration(
        color: DadgarTokens.primary,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month,
              color: DadgarTokens.onPrimary, size: 22),
          const SizedBox(width: DadgarTokens.s8),
          Text(
            label,
            style: const TextStyle(
              color: DadgarTokens.onPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            todayText,
            style: const TextStyle(
              color: DadgarTokens.onPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// ردیف نام روزهای هفته — شنبه تا جمعه
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
                color: DadgarTokens.textSecondary,
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
    required this.onSelect,
  });

  final int? selectedDay;
  final int todayDay;
  final bool Function(int) isDayClosed;
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
}

final class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) => const AspectRatio(
        aspectRatio: 1,
        child: SizedBox.shrink(),
      );
}

/// خانه‌ی یک روز — انتخاب، امروز، بسته
final class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isClosed,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final bool isClosed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = isClosed && !isSelected;
    final background = isSelected
        ? DadgarTokens.primary
        : Colors.transparent;
    final foreground = isSelected
        ? DadgarTokens.onPrimary
        : disabled
            ? DadgarTokens.textSecondary.withValues(alpha: 0.45)
            : DadgarTokens.textPrimary;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: background,
          shape: isSelected
              ? const CircleBorder()
              : CircleBorder(
                  side: isToday
                      ? const BorderSide(color: DadgarTokens.primary, width: 1.5)
                      : BorderSide.none,
                ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disabled ? null : onTap,
            child: Center(
              child: Text(
                JalaliCalendar.toPersianDigits(day),
                style: TextStyle(fontSize: 13, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بازه‌های روز انتخاب‌شده — پنج بازه‌ی ثابت قرارداد
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'بازه‌های $dateLabel',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: DadgarTokens.textPrimary,
          ),
        ),
        const SizedBox(height: DadgarTokens.s8),
        Wrap(
          spacing: DadgarTokens.s8,
          runSpacing: DadgarTokens.s8,
          children: [
            for (final slot in AppointmentContract.slotLabels.values)
              _SlotChip(
                slot: slot,
                selected: slot == selectedSlot,
                state: slotStateFor(day, slot),
                onTap: () => onSelect(slot),
              ),
          ],
        ),
      ],
    );
  }
}

final class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final String slot;
  final bool selected;
  final SlotState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final free = state == SlotState.free;
    return FilterChip(
      selected: selected && free,
      onSelected: free ? (_) => onTap() : null,
      label: Text(
        switch (state) {
          SlotState.free => slot,
          SlotState.taken => '$slot (پر)',
          SlotState.past => '$slot (گذشته)',
        },
        style: TextStyle(
          fontSize: 13,
          color: free
              ? (selected ? DadgarTokens.onPrimary : DadgarTokens.textPrimary)
              : DadgarTokens.textSecondary.withValues(alpha: 0.5),
        ),
      ),
      selectedColor: DadgarTokens.primary,
      checkmarkColor: DadgarTokens.onPrimary,
      showCheckmark: false,
      backgroundColor: DadgarTokens.surface,
      side: BorderSide(
        color: selected && free
            ? DadgarTokens.primary
            : DadgarTokens.textSecondary.withValues(alpha: 0.35),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع ملاقات',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: DadgarTokens.textPrimary,
          ),
        ),
        const SizedBox(height: DadgarTokens.s8),
        Wrap(
          spacing: DadgarTokens.s8,
          children: [
            for (final kind in AppointmentContract.kinds)
              ChoiceChip(
                label: Text(kind),
                selected: kind == selectedKind,
                onSelected: (_) => onSelect(kind),
                selectedColor: DadgarTokens.primary,
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: kind == selectedKind
                      ? DadgarTokens.onPrimary
                      : DadgarTokens.textPrimary,
                ),
                checkmarkColor: DadgarTokens.onPrimary,
                showCheckmark: false,
              ),
          ],
        ),
      ],
    );
  }
}

/// دکمه‌ی رزرو — فعال فقط با بازه‌ی آزاد
final class _BookButton extends ConsumerWidget {
  const _BookButton({required this.day});

  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(appointmentsControllerProvider);
    final canBook = ui.selectedSlot != null &&
        ui.selectedSlot != '' &&
        ui.slotStateFor(day, ui.selectedSlot!) == SlotState.free &&
        !ui.busy;
    return FilledButton(
      onPressed: canBook
          ? () => ref.read(appointmentsControllerProvider.notifier).book()
          : null,
      style: FilledButton.styleFrom(
        backgroundColor: DadgarTokens.primary,
        foregroundColor: DadgarTokens.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: DadgarTokens.s16),
      ),
      child: ui.busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: DadgarTokens.onPrimary,
              ),
            )
          : const Text('رزرو این بازه', style: TextStyle(fontSize: 16)),
    );
  }
}

/// یادآوری صادقانه — هم‌ساز با صفحه‌ی ورود
final class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DadgarTokens.s12),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.25),
        ),
      ),
      child: const Text(
        'تقویم و بازه‌ها از سرور دادگر می‌آید (همان API سایت) — اتصال زنده '
        'پس از حکم مدیر بر D-6 فعال می‌شود؛ کد موبایل آماده است.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: DadgarTokens.textSecondary),
      ),
    );
  }
}
