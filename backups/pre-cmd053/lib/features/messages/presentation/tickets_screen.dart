/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی تیکت‌های پشتیبانی — M5 (DOC-04 §۱۱ ردیف M5).
///
/// بازطراحی موبایل‌بومی با کیت «دادگر S»: سربرگ DsTopBar با شمارنده به‌عنوان
/// زیرنویس، کارت‌های DsCard با قرص وضعیت DsPill، حالت خالی/خطای صادقانه با
/// DsEmptyState و بارگذاری با DsRing. رفتار عین قدیم: مسیرها ('/tickets/new'
/// و '/tickets/:id')، pull-to-refresh، شمارنده‌ی فارسی و برچسب‌های وضعیت
/// TK_ST سرور. FAB قدیمی به دکمه‌ی سطح‌بالای فهرست + اقدام حالت خالی منتقل شد.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../application/tickets_controller.dart';
import '../domain/ticket_models.dart';

/// نگاشت وضعیت تیکت به تُن قرص نسل S — باز = جریان، بررسی = هشدار،
/// پاسخ داده‌شده = موفقیت، بسته = خنثی
DsPillTone _statusTone(String status) => switch (status) {
      'open' => DsPillTone.info,
      'review' => DsPillTone.warn,
      'answered' => DsPillTone.success,
      'closed' => DsPillTone.neutral,
      _ => DsPillTone.info,
    };

/// صفحه‌ی تیکت‌های من
class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(ticketsControllerProvider);
    final controller = ref.read(ticketsControllerProvider.notifier);

    return Scaffold(
      appBar: DsTopBar(
        'تیکت‌های پشتیبانی',
        subtitle: ui.status == LoadStatus.ready
            ? '${JalaliCalendar.toPersianDigits(ui.rows.length)} تیکت'
            : null,
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const _LoadingPane(),
        LoadStatus.error => DsEmptyState(
            icon: Icons.cloud_off_outlined,
            title: ui.message ?? 'خطای نامشخص',
            actionLabel: 'تلاش دوباره',
            onAction: controller.reload,
          ),
        LoadStatus.ready when ui.rows.isEmpty => DsEmptyState(
            icon: Icons.support_agent_outlined,
            title: 'هنوز تیکتی ثبت نکرده‌اید',
            actionLabel: 'تیکت جدید',
            onAction: () => context.go('/tickets/new'),
          ),
        LoadStatus.ready => _TicketsList(ui: ui),
      },
    );
  }
}

/// فهرست تیکت‌ها — اقدام «تیکت جدید» بالای فهرست + pull-to-refresh
final class _TicketsList extends ConsumerWidget {
  const _TicketsList({required this.ui});

  final TicketsUi ui;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(ticketsControllerProvider.notifier);
    final light = Theme.of(context).brightness == Brightness.light;
    return RefreshIndicator(
      onRefresh: controller.reload,
      color: light ? Ds.primary : Ds.cyan,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Ds.s16, Ds.s16, Ds.s16, Ds.s32),
        itemCount: ui.rows.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: Ds.s12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return DsButton(
              'تیکت جدید',
              icon: Icons.support_agent_outlined,
              tone: DsButtonTone.tonal,
              expand: true,
              onPressed: () => context.go('/tickets/new'),
            );
          }
          return _TicketCard(row: ui.rows[index - 1]);
        },
      ),
    );
  }
}

/// کارت تیکت نسل S — قرص وضعیت/شناسه، موضوع، بخش/شمار پیام/تاریخ
final class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.row});

  final TicketSummary row;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final faint = light ? Ds.inkFaint : Ds.inkFaintDark;
    final caption = DsText.caption.copyWith(
      color: light ? Ds.inkSoft : Ds.inkSoftDark,
    );
    final updated = JalaliCalendar.fromEpochSeconds(row.updatedAt);
    return DsCard(
      onTap: () => context.go('/tickets/${row.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsPill(row.statusValue.labelFa, tone: _statusTone(row.status)),
              const Spacer(),
              Text(
                'تیکت ${JalaliCalendar.toPersianDigits(row.id)}',
                style: DsText.micro.copyWith(color: faint),
              ),
            ],
          ),
          const SizedBox(height: Ds.s8),
          Text(
            row.subject,
            style: DsText.headline.copyWith(
              color: light ? Ds.ink : Ds.inkDark,
            ),
          ),
          const SizedBox(height: Ds.s4),
          Row(
            children: [
              if (row.dept.isNotEmpty) ...[
                Text(row.dept, style: caption),
                const SizedBox(width: Ds.s8),
                Text('•', style: TextStyle(color: faint)),
                const SizedBox(width: Ds.s8),
              ],
              Text(
                '${JalaliCalendar.toPersianDigits(row.msgCount)} پیام',
                style: caption,
              ),
              const Spacer(),
              Text(
                JalaliCalendar.formatNumeric(updated),
                style: DsText.caption.copyWith(color: faint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// بارگذاری — حلقه‌ی نسل S (بی‌پایان؛ در تست‌ها فقط pump ثابت)
final class _LoadingPane extends StatelessWidget {
  const _LoadingPane();

  @override
  Widget build(BuildContext context) {
    return const Center(child: DsRing(size: 28));
  }
}
