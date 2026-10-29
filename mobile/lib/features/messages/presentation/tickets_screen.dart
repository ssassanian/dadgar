/// صفحه‌ی تیکت‌های پشتیبانی — M5 (DOC-04 §۱۱ ردیف M5)
///
/// الگوی «لیست-کارت» §۷: کارت به‌جای جدول، pull-to-refresh، خالی صادقانه
/// و وضعیت‌نشان رنگی D-3 — ستون‌های همان جدول وب (موضوع/بخش/وضعیت/شمار پیام).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/jalali.dart';
import '../../../design/tokens.dart';
import '../application/tickets_controller.dart';
import '../domain/ticket_models.dart';

/// صفحه‌ی تیکت‌های من
class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(ticketsControllerProvider);
    final controller = ref.read(ticketsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('تیکت‌های پشتیبانی')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/tickets/new'),
        icon: const Icon(Icons.support_agent_outlined),
        label: const Text('تیکت جدید'),
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const _SkeletonList(),
        LoadStatus.error => _ErrorPane(
            message: ui.message ?? 'خطای نامشخص',
            onRetry: controller.reload,
          ),
        LoadStatus.ready when ui.rows.isEmpty => const _EmptyPane(),
        LoadStatus.ready => _TicketsList(ui: ui),
      },
    );
  }
}

final class _TicketsList extends ConsumerWidget {
  const _TicketsList({required this.ui});

  final TicketsUi ui;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(ticketsControllerProvider.notifier);
    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          DadgarTokens.s16,
          DadgarTokens.s16,
          DadgarTokens.s16,
          DadgarTokens.s32,
        ),
        itemCount: ui.rows.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: DadgarTokens.s8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: DadgarTokens.s4),
              child: Text(
                '${JalaliCalendar.toPersianDigits(ui.rows.length)} تیکت',
                style: const TextStyle(
                  fontSize: 12,
                  color: DadgarTokens.textSecondary,
                ),
              ),
            );
          }
          return _TicketCard(row: ui.rows[index - 1]);
        },
      ),
    );
  }
}

/// کارت تیکت — موضوع/بخش/اولویت/وضعیت/شمار پیام/تاریخ
final class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.row});

  final TicketSummary row;

  Color get _statusColor => switch (row.status) {
        'closed' => DadgarTokens.accent,
        'answered' => DadgarTokens.primary,
        'open' => DadgarTokens.textSecondary,
        _ => DadgarTokens.primary,
      };

  @override
  Widget build(BuildContext context) {
    final updated = JalaliCalendar.fromEpochSeconds(row.updatedAt);
    return Material(
      color: DadgarTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        side: BorderSide(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/tickets/${row.id}'),
        child: Padding(
          padding: const EdgeInsets.all(DadgarTokens.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DadgarTokens.s8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      row.statusValue.labelFa,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'تیکت ${JalaliCalendar.toPersianDigits(row.id)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DadgarTokens.s8),
              Text(
                row.subject,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DadgarTokens.textPrimary,
                ),
              ),
              const SizedBox(height: DadgarTokens.s4),
              Row(
                children: [
                  if (row.dept.isNotEmpty) ...[
                    Text(
                      row.dept,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(width: DadgarTokens.s8),
                    const Text('•',
                        style: TextStyle(color: DadgarTokens.textSecondary)),
                    const SizedBox(width: DadgarTokens.s8),
                  ],
                  Text(
                    '${JalaliCalendar.toPersianDigits(row.msgCount)} پیام',
                    style: const TextStyle(
                      fontSize: 12,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    JalaliCalendar.formatNumeric(updated),
                    style: const TextStyle(
                      fontSize: 12,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// اسکلت بارگذاری
final class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(DadgarTokens.s16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: DadgarTokens.s8),
      itemBuilder: (_, __) => Container(
        height: 88,
        decoration: BoxDecoration(
          color: DadgarTokens.surface,
          borderRadius: BorderRadius.circular(DadgarTokens.radius),
          border: Border.all(
            color: DadgarTokens.textSecondary.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}

/// خالی صادقانه
final class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DadgarTokens.s24),
        child: Column(
          children: [
            const Icon(
              Icons.support_agent_outlined,
              size: 48,
              color: DadgarTokens.textSecondary,
            ),
            const SizedBox(height: DadgarTokens.s12),
            const Text(
              'هنوز تیکتی ثبت نکرده‌اید',
              style: TextStyle(
                fontSize: 14,
                color: DadgarTokens.textSecondary,
              ),
            ),
            const SizedBox(height: DadgarTokens.s16),
            FilledButton.icon(
              onPressed: () => context.go('/tickets/new'),
              icon: const Icon(Icons.support_agent_outlined, size: 18),
              label: const Text('تیکت جدید'),
            ),
          ],
        ),
      ),
    );
  }
}

/// خطای صادقانه + تلاش دوباره
final class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DadgarTokens.s24),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: DadgarTokens.error,
            ),
            const SizedBox(height: DadgarTokens.s12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.8,
                color: DadgarTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DadgarTokens.s16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }
}
