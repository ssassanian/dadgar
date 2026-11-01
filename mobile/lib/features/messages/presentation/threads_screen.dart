/// صفحه‌ی گفتگوهای پرونده — M5 (DOC-04 §۱۱ ردیف M5)
///
/// CMD-046 (فاز ۳): بازطراحی D-3 عین طرح تاییدشده‌ی CMD-041 (`bMsgs` در
/// `design-preview/prototype.html`): AppBar کاغذی «پیام‌ها» با زیرنویس،
/// ردیف‌های دوخطی r-main/r-side (عنوان پرونده / گزیده‌ی آخرین پیام +
/// تاریخ شمسی) با فلش RTL.
///
/// آینه‌ی GET /api/threads سرور: فقط پرونده‌های دارای وکیلِ تخصیص‌یافته
/// (assigned/running/done) با گزیده‌ی آخرین پیام (۸۰ نویسه از سرور).
/// صداقت داده (S-4): نشان «خوانده‌نشده» طرح در مدل Thread سرور نیست →
/// بدون نقطه‌ی جعلی.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/jalali.dart';
import '../../../design/d3_kit.dart';
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
      backgroundColor: DadgarTokens.background,
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: DadgarTokens.background,
        foregroundColor: DadgarTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'پیام‌ها',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: DadgarTokens.textPrimary,
              ),
            ),
            Text(
              ui.status == LoadStatus.ready
                  ? '${JalaliCalendar.toPersianDigits(ui.rows.length)} گفتگو'
                  : 'گفتگوهای پرونده‌ها',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: DadgarTokens.textFaint,
              ),
            ),
          ],
        ),
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        LoadStatus.error => _ErrorPane(
            message: ui.message ?? 'خطای نامشخص',
            onRetry: controller.reload,
          ),
        LoadStatus.ready when ui.rows.isEmpty => const _EmptyPane(),
        LoadStatus.ready => _ThreadsList(ui: ui),
      },
    );
  }
}

final class _ThreadsList extends ConsumerWidget {
  const _ThreadsList({required this.ui});

  final ThreadsUi ui;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(threadsControllerProvider.notifier);
    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          DadgarTokens.s16,
          DadgarTokens.s4,
          DadgarTokens.s16,
          DadgarTokens.s32,
        ),
        children: [
          // پنل ردیف‌ها — عین `.rows` طرح با خط ردیف بین ردیف‌ها
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: DadgarTokens.surface,
              borderRadius: BorderRadius.circular(DadgarTokens.radius),
              border: Border.all(color: DadgarTokens.cardBorder),
            ),
            child: Column(
              children: [
                for (var i = 0; i < ui.rows.length; i++) ...[
                  if (i > 0) const DadgarRowRule(),
                  _ThreadRow(row: ui.rows[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: DadgarTokens.s12),
          const DadgarEmptyBox(
            'با بازکردن هر گفتگو، پیام‌های پرونده در گفتگو نشان داده می‌شود.',
          ),
        ],
      ),
    );
  }
}

/// ردیف گفتگو — عنوان پرونده + گزیده‌ی آخرین پیام + تاریخ شمسی
final class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.row});

  final Thread row;

  @override
  Widget build(BuildContext context) {
    final last = JalaliCalendar.fromEpochSeconds(row.lastAt);
    return DadgarListRow(
      title: row.title,
      subtitle: row.lastExcerpt.isEmpty
          ? 'هنوز پیامی ردوبدل نشده است'
          : (row.lastMine ? 'شما: ' : '') + row.lastExcerpt,
      side: Text(
        JalaliCalendar.formatNumeric(last),
        style: const TextStyle(
          fontSize: 11,
          color: DadgarTokens.textFaint,
        ),
      ),
      showChevron: true,
      onTap: () => context.push('/threads/${row.caseId}'),
    );
  }
}

/// خالی صادقانه — گفتگو پس از تخصیص وکیل باز می‌شود (پیام سرور)
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
              Icons.forum_outlined,
              size: 48,
              color: DadgarTokens.textSecondary,
            ),
            const SizedBox(height: DadgarTokens.s12),
            const Text(
              'هنوز گفتگویی فعال نیست',
              style: TextStyle(
                fontSize: 14,
                color: DadgarTokens.textSecondary,
              ),
            ),
            const SizedBox(height: DadgarTokens.s8),
            const Text(
              'گفتگوی هر پرونده پس از تخصیص وکیل باز می‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.8,
                color: DadgarTokens.textSecondary,
              ),
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
            DadgarGhostButton('تلاش دوباره', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
