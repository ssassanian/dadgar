import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/tokens.dart';
import '../application/appointments_controller.dart';
import '../domain/appointment.dart';

/// صفحه‌ی «نوبت‌های من» — M3
///
/// فهرست نوبت‌های نشست جاری از GET /api/appointments (سرور بر اساس نقش
/// فیلتر می‌کند) + لغو با PATCH {status: canceled} — قواعد دسترسی با سرور.
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
          backgroundColor:
              next.isError ? DadgarTokens.error : DadgarTokens.accent,
          behavior: SnackBarBehavior.floating,
        ));
    });

    return Scaffold(
      appBar: AppBar(title: const Text('نوبت‌های من')),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(
            child: CircularProgressIndicator(color: DadgarTokens.primary),
          ),
        LoadStatus.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(DadgarTokens.s24),
              child: Text(
                ui.message ?? 'دریافت اطلاعات ناموفق بود',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 2),
              ),
            ),
          ),
        LoadStatus.ready => ui.rows.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                color: DadgarTokens.primary,
                onRefresh: () =>
                    ref.read(appointmentsControllerProvider.notifier).reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(DadgarTokens.s16),
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

final class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy_outlined,
              size: 48, color: DadgarTokens.textSecondary),
          const SizedBox(height: DadgarTokens.s12),
          const Text(
            'هنوز نوبتی ثبت نکرده‌اید',
            style: TextStyle(fontSize: 14, color: DadgarTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// کارت یک نوبت — تاریخ بلند شمسی + بازه + نوع + وضعیت + لغو
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

    return Container(
      margin: const EdgeInsets.only(bottom: DadgarTokens.s12),
      padding: const EdgeInsets.all(DadgarTokens.s16),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 18, color: DadgarTokens.primary),
              const SizedBox(width: DadgarTokens.s8),
              Expanded(
                child: Text(
                  '$weekDay، ${JalaliCalendar.formatLong(date)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DadgarTokens.textPrimary,
                  ),
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: DadgarTokens.s8),
          Text(
            'ساعت ${appointment.slot} · ملاقات ${appointment.kind}'
            '${appointment.clientName != null ? ' · موکل: ${appointment.clientName}' : ''}',
            style: const TextStyle(
              fontSize: 13,
              color: DadgarTokens.textSecondary,
            ),
          ),
          if (cancellable) ...[
            const SizedBox(height: DadgarTokens.s12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('لغو نوبت'),
                      content: const Text(
                        'این نوبت لغو شود؟ این اقدام قابل بازگشت نیست.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('انصراف'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text(
                            'لغو نوبت',
                            style: TextStyle(color: DadgarTokens.error),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) onCancel();
                },
                icon: const Icon(Icons.close, size: 18),
                label: const Text('لغو نوبت'),
                style: TextButton.styleFrom(
                  foregroundColor: DadgarTokens.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// نشان وضعیت — رنگ‌بندی D-3
final class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AppointmentStatus.confirmed => DadgarTokens.accent,
      AppointmentStatus.booked => DadgarTokens.primary,
      AppointmentStatus.canceled => DadgarTokens.error,
      _ => DadgarTokens.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DadgarTokens.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.labelFa,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}
