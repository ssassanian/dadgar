/// صفحه‌ی فهرست پرونده‌های من — M2 (DOC-04 §۱۱ ردیف M2)
///
/// الگوی «لیست-کارت» §۷: کارت به‌جای جدول، pull-to-refresh، خالی صادقانه،
/// صفحه‌بندی روی اسکرول (CASES_PER=10 سرور) و وضعیت‌نشان رنگی D-3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/tokens.dart';
import '../application/cases_controller.dart';
import '../domain/case_models.dart';

/// صفحه‌ی فهرست پرونده‌ها
class CasesScreen extends ConsumerWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(casesControllerProvider);
    final controller = ref.read(casesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('پرونده‌های من')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/cases/new'),
        icon: const Icon(Icons.post_add_outlined),
        label: const Text('ثبت پرونده جدید'),
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const _SkeletonList(),
        LoadStatus.error => _ErrorPane(
            message: ui.message ?? 'خطای نامشخص',
            onRetry: controller.reload,
          ),
        LoadStatus.ready when ui.rows.isEmpty => _EmptyPane(
            onCreate: () => context.go('/cases/new'),
          ),
        LoadStatus.ready => _CasesList(ui: ui),
      },
    );
  }
}

/// فهرست + صفحه‌بندی بی‌نهایت روی نزدیکی به انتهای اسکرول
final class _CasesList extends ConsumerStatefulWidget {
  const _CasesList({required this.ui});

  final CasesUi ui;

  @override
  ConsumerState<_CasesList> createState() => _CasesListState();
}

final class _CasesListState extends ConsumerState<_CasesList> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final nearEnd = _scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 240;
    if (nearEnd) {
      ref.read(casesControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(casesControllerProvider);
    final controller = ref.read(casesControllerProvider.notifier);
    final items = ui.rows.length + (ui.loadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          DadgarTokens.s16,
          DadgarTokens.s16,
          DadgarTokens.s16,
          DadgarTokens.s32,
        ),
        itemCount: items + 1,
        separatorBuilder: (_, __) => const SizedBox(height: DadgarTokens.s8),
        itemBuilder: (context, index) {
          if (index == 0) return _TotalBar(total: ui.total);
          final rowIndex = index - 1;
          if (rowIndex >= ui.rows.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(DadgarTokens.s12),
                child: ui.loadingMore
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Text(
                        ui.hasMore ? '' : 'پرونده‌ی بیشتری نیست',
                        style: const TextStyle(
                          fontSize: 12,
                          color: DadgarTokens.textSecondary,
                        ),
                      ),
              ),
            );
          }
          return _CaseCard(row: ui.rows[rowIndex]);
        },
      ),
    );
  }
}

/// نوار شمارنده — «۳ پرونده» با ارقام فارسی
final class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DadgarTokens.s4),
      child: Text(
        '${JalaliCalendar.toPersianDigits(total)} پرونده',
        style: const TextStyle(
          fontSize: 12,
          color: DadgarTokens.textSecondary,
        ),
      ),
    );
  }
}

/// کارت پرونده — شماره/عنوان/دسته/وضعیت/تاریخ (همان ستون‌های وب)
final class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.row});

  final CaseSummary row;

  Color get _statusColor => switch (row.status) {
        'done' => DadgarTokens.accent,
        'running' => DadgarTokens.accent,
        'waiting' => DadgarTokens.textSecondary,
        _ => DadgarTokens.primary,
      };

  @override
  Widget build(BuildContext context) {
    final created = JalaliCalendar.fromEpochSeconds(row.createdAt);
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
        onTap: () => context.go('/cases/${row.id}'),
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
                    'پرونده ${JalaliCalendar.toPersianDigits(row.id)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DadgarTokens.s8),
              Text(
                row.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DadgarTokens.textPrimary,
                ),
              ),
              const SizedBox(height: DadgarTokens.s4),
              Row(
                children: [
                  Text(
                    row.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: DadgarTokens.s8),
                  const Text('•',
                      style: TextStyle(color: DadgarTokens.textSecondary)),
                  const SizedBox(width: DadgarTokens.s8),
                  Text(
                    JalaliCalendar.formatNumeric(created),
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

/// اسکلت بارگذاری — پیش از رسیدن داده (§۷)
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

/// خالی صادقانه — «هنوز پرونده‌ای ثبت نکرده‌اید» (بدون داده‌ی جعلی)
final class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DadgarTokens.s24),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 48,
              color: DadgarTokens.textSecondary,
            ),
            const SizedBox(height: DadgarTokens.s12),
            const Text(
              'هنوز پرونده‌ای ثبت نکرده‌اید',
              style: TextStyle(
                fontSize: 14,
                color: DadgarTokens.textSecondary,
              ),
            ),
            const SizedBox(height: DadgarTokens.s16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.post_add_outlined, size: 18),
              label: const Text('ثبت پرونده جدید'),
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
