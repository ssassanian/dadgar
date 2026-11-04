/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی گفتگوهای پرونده — M5 (DOC-04 §۱۱ ردیف M5).
///
/// آینه‌ی GET /api/threads سرور: فقط پرونده‌های دارای وکیلِ تخصیص‌یافته
/// (assigned/running/done) با گزیده‌ی آخرین پیام (۸۰ نویسه از سرور) و
/// پیشوند «شما:» برای پیام خودی. نسل S: سربرگ DsTopBar با شمارنده،
/// ردیف‌های DsTile با تاریخ شمسی و حالت خالی/خطای صادقانه DsEmptyState.
///
/// صداقت داده (S-4): نشان «خوانده‌نشده» در مدل Thread سرور نیست → بدون
/// نقطه‌ی جعلی.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../application/chat_controller.dart';
import '../application/tickets_controller.dart' show LoadStatus;
import '../domain/chat_models.dart';

/// صفحه‌ی گفتگوها
class ThreadsScreen extends ConsumerWidget {
  const ThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(threadsControllerProvider);
    final controller = ref.read(threadsControllerProvider.notifier);

    return Scaffold(
      appBar: DsTopBar(
        'پیام‌ها',
        subtitle: ui.status == LoadStatus.ready
            ? '${JalaliCalendar.toPersianDigits(ui.rows.length)} گفتگو'
            : 'گفتگوهای پرونده‌ها',
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(child: DsRing(size: 28)),
        LoadStatus.error => DsEmptyState(
            icon: Icons.cloud_off_outlined,
            title: ui.message ?? 'خطای نامشخص',
            actionLabel: 'تلاش دوباره',
            onAction: controller.reload,
          ),
        LoadStatus.ready when ui.rows.isEmpty => const DsEmptyState(
            icon: Icons.forum_outlined,
            title: 'هنوز گفتگویی فعال نیست',
            hint: 'گفتگوی هر پرونده پس از تخصیص وکیل باز می‌شود.',
          ),
        LoadStatus.ready => _ThreadsList(ui: ui),
      },
    );
  }
}

/// فهرست گفتگوها — pull-to-refresh + راهنمای پایین فهرست
final class _ThreadsList extends ConsumerWidget {
  const _ThreadsList({required this.ui});

  final ThreadsUi ui;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(threadsControllerProvider.notifier);
    final light = Theme.of(context).brightness == Brightness.light;
    return RefreshIndicator(
      onRefresh: controller.reload,
      color: light ? Ds.primary : Ds.cyan,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Ds.s16, Ds.s12, Ds.s16, Ds.s32),
        itemCount: ui.rows.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: Ds.s8),
        itemBuilder: (context, index) {
          if (index == ui.rows.length) {
            return Padding(
              padding: const EdgeInsets.only(top: Ds.s12),
              child: Text(
                'با بازکردن هر گفتگو، پیام‌های پرونده در گفتگو نشان داده می‌شود.',
                textAlign: TextAlign.center,
                style: DsText.caption.copyWith(
                  color: light ? Ds.inkFaint : Ds.inkFaintDark,
                ),
              ),
            );
          }
          return _ThreadRow(row: ui.rows[index]);
        },
      ),
    );
  }
}

/// ردیف گفتگو نسل S — عنوان پرونده + گزیده‌ی آخرین پیام + تاریخ شمسی
final class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.row});

  final Thread row;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final faint = light ? Ds.inkFaint : Ds.inkFaintDark;
    final last = JalaliCalendar.fromEpochSeconds(row.lastAt);
    return DsTile(
      title: row.title,
      subtitle: row.lastExcerpt.isEmpty
          ? 'هنوز پیامی رد و بدل نشده است'
          : (row.lastMine ? 'شما: ' : '') + row.lastExcerpt,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            JalaliCalendar.formatNumeric(last),
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 11.5,
              color: faint,
            ),
          ),
          Icon(Icons.chevron_left, size: 20, color: faint),
        ],
      ),
      onTap: () => context.push('/threads/${row.caseId}'),
    );
  }
}
