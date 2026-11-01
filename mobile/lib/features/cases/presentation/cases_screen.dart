/// صفحه‌ی فهرست پرونده‌های من — M2 (DOC-04 §۱۱ ردیف M2)
///
/// CMD-045 (فاز ۲): بازطراحی D-3 عین طرح تاییدشده‌ی CMD-041 (`bCases` در
/// `design-preview/prototype.html`): نوار بالای ۴۸px با شمارنده، چیپ‌های
/// «همه/در جریان/بسته» و ردیف‌های دوخطی `r-main/r-side` با قرص خنثی و فلش.
///
/// صداقت داده (S-4): قرارداد سرور پارامتر فیلتر وضعیت ندارد (فقط `page`)
/// → چیپ‌ها فقط ردیف‌های بارگذاری‌شده را صافی می‌کنند و شمارنده‌ی «در
/// جریان» تنها زمانی نمایش داده می‌شود که همه‌ی صفحات رسیده باشند.
/// ورود «ثبت پرونده جدید» طبق شات تاییدشده‌ی CMD-037 به‌صورت دکمه‌ی شبح
/// پایان فهرست حفظ شده (مسیر F3 هنوز بی‌حکم است — حذف قابلیت مجاز نبود).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/d3_kit.dart';
import '../../../design/tokens.dart';
import '../application/cases_controller.dart';
import '../domain/case_models.dart';

/// صافی فهرست — سه حالت طرح (همه/در جریان/بسته)
enum _CaseFilter { all, open, closed }

extension _CaseFilterX on _CaseFilter {
  /// برچسب عین طرح
  String get label => switch (this) {
        _CaseFilter.all => 'همه',
        _CaseFilter.open => 'در جریان',
        _CaseFilter.closed => 'بسته',
      };

  /// «در جریان» = هر وضعیت فعال سرور؛ «بسته» = فقط done
  bool matches(CaseSummary row) => switch (this) {
        _CaseFilter.all => true,
        _CaseFilter.open => row.status != CaseStatus.done.value,
        _CaseFilter.closed => row.status == CaseStatus.done.value,
      };
}

/// صفحه‌ی فهرست پرونده‌ها
final class CasesScreen extends ConsumerStatefulWidget {
  const CasesScreen({super.key});

  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

final class _CasesScreenState extends ConsumerState<CasesScreen> {
  _CaseFilter _filter = _CaseFilter.all;

  /// زیرنویس نوار بالا — فقط داده‌ی واقعی: شمار کل از سرور، شمار «در
  /// جریان» از ردیف‌های بارگذاری‌شده و فقط وقتی همه‌ی صفحات رسیده‌اند
  String _subtitle(CasesUi ui) {
    if (ui.status != LoadStatus.ready) return '';
    final total = JalaliCalendar.toPersianDigits(ui.total);
    final allLoaded = !ui.hasMore;
    if (!allLoaded) return '$total پرونده';
    final open = ui.rows.where((r) => r.status != CaseStatus.done.value).length;
    return '$total پرونده · ${JalaliCalendar.toPersianDigits(open)} در جریان';
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(casesControllerProvider);
    final controller = ref.read(casesControllerProvider.notifier);

    return Scaffold(
      backgroundColor: DadgarTokens.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DadgarTokens.s16),
              child: DadgarTopBar(
                title: 'پرونده‌ها',
                subtitle: _subtitle(ui),
              ),
            ),
            const SizedBox(height: DadgarTokens.s12),
            // چیپ‌های فیلتر — عین `.chips` طرح؛ لمس ۴۸ (F4)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: DadgarTokens.s16,
                ),
                children: [
                  for (final f in _CaseFilter.values) ...[
                    DadgarChip(
                      f.label,
                      selected: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: DadgarTokens.s4),
            Expanded(
              child: switch (ui.status) {
                LoadStatus.loading => const _SkeletonList(),
                LoadStatus.error => _ErrorPane(
                    message: ui.message ?? 'خطای نامشخص',
                    onRetry: controller.reload,
                  ),
                LoadStatus.ready when ui.rows.isEmpty => _EmptyPane(
                    onCreate: () => context.push('/cases/new'),
                  ),
                LoadStatus.ready => _CasesList(ui: ui, filter: _filter),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// فهرست + صفحه‌بندی بی‌نهایت روی نزدیکی به انتهای اسکرول
final class _CasesList extends ConsumerStatefulWidget {
  const _CasesList({required this.ui, required this.filter});

  final CasesUi ui;
  final _CaseFilter filter;

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
    final ui = widget.ui;
    final visible = ui.rows.where(widget.filter.matches).toList();

    return RefreshIndicator(
      onRefresh: ref.read(casesControllerProvider.notifier).reload,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          DadgarTokens.s16,
          DadgarTokens.s8,
          DadgarTokens.s16,
          DadgarTokens.s32,
        ),
        children: [
          if (visible.isEmpty)
            // حالت خالی صادقانه‌ی طرح — عین رشته‌ی `bCases`
            const DadgarEmptyBox('پرونده‌ای در این وضعیت ندارید.')
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: DadgarTokens.surface,
                borderRadius: BorderRadius.circular(DadgarTokens.radius),
                border: Border.all(color: DadgarTokens.cardBorder),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const DadgarRowRule(),
                    DadgarListRow(
                      title:
                          'پرونده ${JalaliCalendar.toPersianDigits(visible[i].id)} · ${visible[i].title}',
                      subtitle: _subtitleOf(visible[i]),
                      side: DadgarPill(visible[i].statusValue.labelFa),
                      showChevron: true,
                      onTap: () => context.push('/cases/${visible[i].id}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: DadgarTokens.s12),
          // ورود «ثبت پرونده جدید» — حفظ قابلیت M2 طبق شات تاییدشده‌ی CMD-037
          DadgarGhostButton(
            'ثبت پرونده جدید',
            onPressed: () => context.push('/cases/new'),
          ),
          if (ui.loadingMore)
            const Padding(
              padding: EdgeInsets.all(DadgarTokens.s12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (!ui.hasMore && ui.rows.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: DadgarTokens.s8),
              child: Center(
                child: Text(
                  'پرونده‌ی بیشتری نیست',
                  style: TextStyle(
                    fontSize: 12,
                    color: DadgarTokens.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// خط دوم ردیف — داده‌ی واقعی سرور: وکیل (اگر تخصیص یافته) یا دسته،
  /// همراه تاریخ ثبت شمسی
  String _subtitleOf(CaseSummary row) {
    final base = row.lawyerName.isNotEmpty ? row.lawyerName : row.category;
    final created = JalaliCalendar.fromEpochSeconds(row.createdAt);
    return '$base · ${JalaliCalendar.formatNumeric(created)}';
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
          border: Border.all(color: DadgarTokens.cardBorder),
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
            DadgarGhostButton('ثبت پرونده جدید', onPressed: onCreate),
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
