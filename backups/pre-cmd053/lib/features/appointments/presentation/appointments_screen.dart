/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی نوبت‌دهی «دادگر S» — تب «نوبت» پوسته‌ی پنج‌تبی (DsTopBar درون
/// بدنه، بدون AppBar مستقل؛ هم‌سو با نسل قبل). رفتار عین نسل قبل
/// پابرجاست: تقویم شمسی نیتیو با آفست هفتگی، پنج بازه‌ی ثابت روزانه‌ی
/// قرارداد، قواعد «گذشته/پر» هم‌ساز سرور، رزرو/لغو با همان مسیرها و
/// همان پیام‌ها. فقط پوسته‌ی بصری با کیت نسل S (Ds) از نو ساخته شده است:
/// روزها کارتِ گرد با نوار امضایی، بازه‌ها چیپ قرصی، و همه‌جا دارک‌مودآگاه.
///
/// صداقت داده (S-4): نوار امضایی روز فقط وقتی معنا دارد که فهرست نوبت‌ها
/// رسیده باشد (با 401 همگی خنثی‌اند)؛ یادداشت پایین صفحه وضعیت واقعی
/// اتصال زنده را بدون ادعا نشان می‌دهد. عنوان صفحه دقیقاً «نوبت‌دهی»
/// می‌ماند (آزمون router_test ردیف ۴ به آن وابسته است).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../application/appointments_controller.dart';
import '../data/appointments_contract.dart';

/// نئوترال‌های تم برای صفحه — رنگ فقط از Ds؛ تفسیر روشن/تاریک از
/// Theme.of(context).brightness (قاعده‌ی الزام CMD-051)
extension _Sx on BuildContext {
  bool get isLight => Theme.of(this).brightness == Brightness.light;
  Color get ink => isLight ? Ds.ink : Ds.inkDark;
  Color get inkSoft => isLight ? Ds.inkSoft : Ds.inkSoftDark;
  Color get inkFaint => isLight ? Ds.inkFaint : Ds.inkFaintDark;
  Color get line => isLight ? Ds.line : Ds.lineDark;
  Color get wash => isLight ? Ds.wash : Ds.washDark;
  Color get accent => isLight ? Ds.primary : Ds.cyan;
  Color get onAccent => isLight ? Ds.onPrimary : Ds.bgDark;
  Color get danger => isLight ? Ds.error : Ds.rose;
  Color get success => isLight ? Ds.green : Ds.mint;
}

/// صفحه‌ی نوبت‌دهی — تب سوم پوسته
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
          backgroundColor: isError ? context.danger : context.success,
          behavior: SnackBarBehavior.floating,
        ));
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Ds.s16),
              child: DsTopBar('نوبت‌دهی', subtitle: 'رزرو ملاقات با وکیل'),
            ),
            Expanded(
              child: switch (ui.status) {
                LoadStatus.loading => const Center(child: DsRing(size: 30)),
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

/// وضعیت خطا — صادقانه با تلاش دوباره (متن عین نسل قبل)
final class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Ds.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DsEmptyState(
            icon: Icons.cloud_off_outlined,
            title: message,
            actionLabel: 'تلاش دوباره',
            onAction: onRetry,
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
    final inMonth =
        ui.todayDay >= 1 && ui.todayDay <= AppointmentContract.monthDays;
    final todayText = inMonth
        ? 'امروز: ${JalaliCalendar.toPersianDigits(ui.todayDay)} '
            '${JalaliCalendar.monthNames[AppointmentContract.contractMonth - 1]}'
        : 'خارج از ماه قرارداد';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Ds.s16, Ds.s4, Ds.s16, Ds.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── پنل تقویم — کارت نسل S با سربرگ ماه و قرص «امروز» ──
          DsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        monthLabel,
                        style: TextStyle(
                          fontFamily: Ds.fontFamily,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: context.ink,
                        ),
                      ),
                    ),
                    DsPill(
                      todayText,
                      tone: inMonth ? DsPillTone.info : DsPillTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: Ds.s12),
                const _WeekDayRow(),
                const SizedBox(height: Ds.s4),
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
          if (selectedDay != null) ...[
            const SizedBox(height: Ds.s12),
            _SlotSection(
              day: selectedDay,
              selectedSlot: ui.selectedSlot,
              slotStateFor: ui.slotStateFor,
              onSelect: controller.selectSlot,
            ),
            const SizedBox(height: Ds.s12),
            _KindSection(
              selectedKind: ui.selectedKind,
              onSelect: controller.selectKind,
            ),
            const SizedBox(height: Ds.s16),
            _BookButton(day: selectedDay),
          ],
          const SizedBox(height: Ds.s16),
          DsButton(
            'نوبت‌های من',
            icon: Icons.event_note_outlined,
            tone: DsButtonTone.outline,
            expand: true,
            onPressed: () => context.push('/appointments/mine'),
          ),
          const SizedBox(height: Ds.s12),
          const _HonestNote(),
        ],
      ),
    );
  }
}

/// ردیف نام روزهای هفته — شنبه تا جمعه (برچسب ریز ۱۱٫۵، عین DsText.micro)
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
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.inkFaint,
              ),
            ),
          ),
      ],
    );
  }
}

/// شبکه‌ی روزهای ماه — آفست هفتگی نیتیو از تقویم جلالی؛ ردیف‌های ۵۲dp
/// (هدف لمس عمودی ≥۴۸) با خانه‌های کارتِ گرد نسل S
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
    final rows = (firstWeekIndex + monthDays + 6) ~/ 7;
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          SizedBox(
            height: 52,
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _cellOf(r * 7 + c, firstWeekIndex)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cellOf(int index, int firstWeekIndex) {
    final day = index - firstWeekIndex + 1;
    if (day < 1 || day > AppointmentContract.monthDays) {
      return const SizedBox.shrink();
    }
    return _DayCell(
      day: day,
      isToday: day == todayDay,
      isSelected: day == selectedDay,
      isClosed: isDayClosed(day),
      barState: _barStateOf(day),
      onTap: () => onSelect(day),
    );
  }

  /// نوار امضایی روز — فقط از داده‌ی واقعی بازه‌ها (S-4):
  /// پر = هر پنج بازه گرفته‌شده؛ آزاد = دست‌کم یک بازه‌ی آزاد
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

/// حالت نوار امضایی روز — آزاد/پر/خنثی (فقط از داده‌ی واقعی)
enum _DayBarState { none, booked, free }

/// خانه‌ی یک روز — کارت گردِ ۱۴ نسل S: انتخاب = قرص پرِ accent،
/// امروز = لبه‌ی accent؛ نوار امضایی ۴px زیر رقم فارسی روز
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
    final accent = context.accent;
    final numColor = disabled
        ? context.inkFaint
        : isSelected
            ? context.onAccent
            : isToday
                ? accent
                : context.ink;
    final barColor = switch (barState) {
      _DayBarState.booked => accent,
      _DayBarState.free => context.success,
      _DayBarState.none => context.line,
    };
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: isSelected ? accent : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isToday && !isSelected
              ? BorderSide(color: accent, width: 1.4)
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
                  fontFamily: Ds.fontFamily,
                  fontSize: 13.5,
                  height: 1.2,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: numColor,
                ),
              ),
              const SizedBox(height: 4),
              // نوار امضایی نسل S — عرض ۵۶٪، ارتفاع ۴، گوشه‌ی ۲
              FractionallySizedBox(
                widthFactor: 0.56,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بازه‌های روز انتخاب‌شده — کارت نسل S با چیپ‌های قرصی
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
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'بازه‌های $dateLabel',
                  style: TextStyle(
                    fontFamily: Ds.fontFamily,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
              ),
              const DsPill('آزاد', tone: DsPillTone.success),
            ],
          ),
          const SizedBox(height: Ds.s12),
          Wrap(
            spacing: Ds.s8,
            runSpacing: Ds.s8,
            children: [
              for (final slot in AppointmentContract.slotLabels.values)
                switch (slotStateFor(day, slot)) {
                  SlotState.free => _SelectChip(
                      label: slot,
                      selected: slot == selectedSlot,
                      onTap: () => onSelect(slot),
                    ),
                  SlotState.taken => _SelectChip.taken('$slot (پر)'),
                  SlotState.past => _SelectChip.past('$slot (گذشته)'),
                },
            ],
          ),
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
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'نوع ملاقات',
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: context.ink,
            ),
          ),
          const SizedBox(height: Ds.s12),
          Wrap(
            spacing: Ds.s8,
            runSpacing: Ds.s8,
            children: [
              for (final kind in AppointmentContract.kinds)
                _SelectChip(
                  label: kind,
                  selected: kind == selectedKind,
                  onTap: () => onSelect(kind),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// حالت چیپ — انتخاب‌شدنی / پر (اشغال) / گذشته
enum _ChipMode { selectable, taken, past }

/// چیپ انتخاب نسل S — کیت Ds چیپ تعاملی ندارد → ویجت خصوصی همین صفحه.
/// ارتفاع ۴۸ (هدف لمس)، فرم قرصی (stadium)؛ حالت انتخاب = قرص پر accent.
final class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    this.selected = false,
    this.onTap,
  })  : _mode = _ChipMode.selectable;

  const _SelectChip.taken(this.label)
      : selected = false,
        onTap = null,
        _mode = _ChipMode.taken;

  const _SelectChip.past(this.label)
      : selected = false,
        onTap = null,
        _mode = _ChipMode.past;

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final _ChipMode _mode;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, BorderSide side) = switch (_mode) {
      _ChipMode.selectable when selected => (
          context.accent,
          context.onAccent,
          BorderSide.none,
        ),
      _ChipMode.selectable => (
          context.wash,
          context.isLight ? Ds.primaryDeep : Ds.cyan,
          BorderSide(color: context.line),
        ),
      _ChipMode.taken => (
          context.wash,
          context.inkSoft,
          BorderSide.none,
        ),
      _ChipMode.past => (
          Colors.transparent,
          context.inkFaint,
          BorderSide(color: context.line),
        ),
    };
    return Material(
      color: bg,
      shape: StadiumBorder(side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: Ds.s16,
            vertical: Ds.s12,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

/// دکمه‌ی رزرو — فعال فقط با بازه‌ی آزاد؛ برچسب عین نسل قبل
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
        DsButton(
          slot != null && slot.isNotEmpty
              ? 'ثبت نوبت — $dateLabel · ساعت $slot'
              : 'ثبت نوبت',
          onPressed: canBook
              ? () => ref.read(appointmentsControllerProvider.notifier).book()
              : null,
          expand: true,
        ),
        if (slot == null || slot.isEmpty) ...[
          const SizedBox(height: Ds.s8),
          Text(
            'ابتدا یک ساعت آزاد را انتخاب کنید.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 12,
              color: context.inkFaint,
            ),
          ),
        ],
      ],
    );
  }
}

/// یادداشت وضعیت — متن عین نسل قبل (S-4: بدون ادعای اتصال زنده)
final class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Ds.s12),
      decoration: BoxDecoration(
        color: context.wash,
        borderRadius: BorderRadius.circular(Ds.radiusField),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: context.accent),
          const SizedBox(width: Ds.s8),
          Expanded(
            child: Text(
              'تقویم و بازه‌ها از سرور دادگر می‌آید (همان API سایت) — اتصال زنده '
              'پس از حکم مدیر بر D-6 فعال می‌شود؛ کد موبایل آماده است.',
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12,
                height: 1.7,
                color: context.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
