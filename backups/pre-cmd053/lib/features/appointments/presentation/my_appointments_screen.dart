/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی «نوبت‌های من» — فهرست نوبت‌های نشست جاری از GET /api/appointments
/// (سرور بر اساس نقش فیلتر می‌کند) + لغو با PATCH {status: canceled} —
/// قواعد دسترسی با سرور. رفتار عین نسل قبل: همان سه حالت صادقانه
/// (بارگذاری/خطا/خالی)، کشیدن برای بازیابی، تأیید لغو با همان متن‌ها.
/// پوسته‌ی بصری نو با کیت نسل S: DsTopBar، کارت Ds با جدول کلید/مقدار
/// و قرص وضعیت، تأیید لغو در شیت پایین نسل S (showDsSheet).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../application/appointments_controller.dart';
import '../domain/appointment.dart';

/// نئوترال‌های تم برای صفحه — رنگ فقط از Ds؛ تفسیر روشن/تاریک از
/// Theme.of(context).brightness (قاعده‌ی الزام CMD-051)
extension _Sx on BuildContext {
  bool get isLight => Theme.of(this).brightness == Brightness.light;
  Color get ink => isLight ? Ds.ink : Ds.inkDark;
  Color get inkFaint => isLight ? Ds.inkFaint : Ds.inkFaintDark;
  Color get accent => isLight ? Ds.primary : Ds.cyan;
  Color get danger => isLight ? Ds.error : Ds.rose;
  Color get success => isLight ? Ds.green : Ds.mint;
}

/// صفحه‌ی «نوبت‌های من» — مسیر ثانویه‌ی /appointments/mine
class MyAppointmentsScreen extends ConsumerWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(appointmentsControllerProvider);
    ref.listen(appointmentsControllerProvider, (previous, next) {
      final message = next.message;
      if (message == null || message.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: next.isError ? context.danger : context.success,
          behavior: SnackBarBehavior.floating,
        ));
    });

    return Scaffold(
      appBar: DsTopBar('نوبت‌های من', showBack: true),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(child: DsRing(size: 30)),
        LoadStatus.error => _ErrorPane(
            message: ui.message ?? 'دریافت اطلاعات ناموفق بود',
          ),
        LoadStatus.ready when ui.rows.isEmpty => const _EmptyPane(),
        LoadStatus.ready => RefreshIndicator(
            color: context.accent,
            onRefresh: () => ref
                .read(appointmentsControllerProvider.notifier)
                .reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(Ds.s16),
              itemCount: ui.rows.length,
              itemBuilder: (context, index) => _AppointmentCard(
                appointment: ui.rows[index],
                busy: ui.busy,
                onCancel: () => ref
                    .read(appointmentsControllerProvider.notifier)
                    .cancel(ui.rows[index].id),
              ),
            ),
          ),
      },
    );
  }
}

/// وضعیت خطا — پیام صادقانه، بدون ادعا (عین نسل قبل: بدون دکمه‌ی retry)
final class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Ds.s24),
        child: DsEmptyState(
          icon: Icons.cloud_off_outlined,
          title: message,
        ),
      ),
    );
  }
}

/// حالت خالی — عین متن نسل قبل
final class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return const DsEmptyState(
      icon: Icons.event_busy_outlined,
      title: 'هنوز نوبتی ثبت نکرده‌اید',
    );
  }
}

/// کارت یک نوبت — تاریخ بلند شمسی + قرص وضعیت + جدول کلید/مقدار + لغو
final class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.busy,
    required this.onCancel,
  });

  final Appointment appointment;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final date = JalaliCalendar.fromEpochSeconds(appointment.startsAt);
    final weekDay = JalaliCalendar.weekDayNames[
        JalaliCalendar.weekIndexOf(date)];
    final status = appointment.statusValue;
    final cancellable = status != AppointmentStatus.canceled && !busy;

    return DsCard(
      margin: const EdgeInsets.only(bottom: Ds.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: context.accent),
              const SizedBox(width: Ds.s8),
              Expanded(
                child: Text(
                  '$weekDay، ${JalaliCalendar.formatLong(date)}',
                  style: TextStyle(
                    fontFamily: Ds.fontFamily,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
              ),
              DsPill(status.labelFa, tone: _toneOf(status)),
            ],
          ),
          const SizedBox(height: Ds.s4),
          DsKvRow('ساعت', appointment.slot),
          if (appointment.clientName == null)
            DsKvRow('ملاقات', appointment.kind, divider: false)
          else ...[
            DsKvRow('ملاقات', appointment.kind),
            DsKvRow('موکل', appointment.clientName!, divider: false),
          ],
          if (cancellable) ...[
            const SizedBox(height: Ds.s8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _GhostDangerButton(
                label: 'لغو نوبت',
                icon: Icons.close,
                onPressed: () => _confirmCancel(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// تأیید لغو — شیت پایین نسل S با متن‌های عین نسل قبل
  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDsSheet<bool>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          Ds.s16,
          Ds.s4,
          Ds.s16,
          Ds.s16 + MediaQuery.paddingOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'لغو نوبت',
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.ink,
              ),
            ),
            const SizedBox(height: Ds.s8),
            Text(
              'این نوبت لغو شود؟ این اقدام قابل بازگشت نیست.',
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 14,
                height: 1.7,
                color: context.inkFaint,
              ),
            ),
            const SizedBox(height: Ds.s16),
            Row(
              children: [
                Expanded(
                  child: DsButton(
                    'انصراف',
                    tone: DsButtonTone.ghost,
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                  ),
                ),
                Expanded(
                  child: DsButton(
                    'لغو نوبت',
                    tone: DsButtonTone.danger,
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) onCancel();
  }
}

/// تُن قرص وضعیت — نگاشت وضعیت‌های سرور روی تُن‌های نسل S
DsPillTone _toneOf(AppointmentStatus status) => switch (status) {
      AppointmentStatus.confirmed => DsPillTone.success,
      AppointmentStatus.booked => DsPillTone.info,
      AppointmentStatus.canceled => DsPillTone.danger,
      _ => DsPillTone.neutral,
    };

/// دکمه‌ی شبح خطا — کیت Ds تُن ghost خطر ندارد → ویجت خصوصی همین صفحه
/// (هدف لمس ≥۴۸)
final class _GhostDangerButton extends StatelessWidget {
  const _GhostDangerButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: context.danger,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: Ds.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
