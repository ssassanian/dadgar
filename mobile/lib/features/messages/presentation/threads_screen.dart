/// صفحه‌ی گفتگوهای پرونده — M5 (DOC-04 §۱۱ ردیف M5)
///
/// آینه‌ی GET /api/threads سرور: فقط پرونده‌های دارای وکیلِ تخصیص‌یافته
/// (assigned/running/done) با گزیده‌ی آخرین پیام (۸۰ نویسه از سرور).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/jalali.dart';
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
      appBar: AppBar(title: const Text('گفتگو با وکیل')),
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
                '${JalaliCalendar.toPersianDigits(ui.rows.length)} گفتگو',
                style: const TextStyle(
                  fontSize: 12,
                  color: DadgarTokens.textSecondary,
                ),
              ),
            );
          }
          return _ThreadCard(row: ui.rows[index - 1]);
        },
      ),
    );
  }
}

/// کارت گفتگو — عنوان پرونده + گزیده‌ی آخرین پیام + تاریخ
final class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.row});

  final Thread row;

  @override
  Widget build(BuildContext context) {
    final last = JalaliCalendar.fromEpochSeconds(row.lastAt);
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
        onTap: () => context.go('/threads/${row.caseId}'),
        child: Padding(
          padding: const EdgeInsets.all(DadgarTokens.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.forum_outlined,
                    size: 18,
                    color: DadgarTokens.primary,
                  ),
                  const SizedBox(width: DadgarTokens.s8),
                  Expanded(
                    child: Text(
                      row.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DadgarTokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    JalaliCalendar.formatNumeric(last),
                    style: const TextStyle(
                      fontSize: 11,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DadgarTokens.s4),
              Text(
                row.lastExcerpt.isEmpty
                    ? 'هنوز پیامی ردوبدل نشده است'
                    : (row.lastMine ? 'شما: ' : '') + row.lastExcerpt,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: DadgarTokens.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
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
