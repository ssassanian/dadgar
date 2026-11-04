/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی فهرست پرونده‌های من — هویت بومی‌موبایلی «دادگر S»: سربرگ درشت
/// DsTopBar، قرص‌های فیلتر ۴۸dp با tint برند و ردیف‌های DsTile با قرص وضعیت.
/// هیچ ارثی از نسل قبل (کاغذ گرم/سرمه‌ای D-3) نیست؛ تنها رنگ‌بندی برند وب
/// از طریق توکن‌های Ds مشترک مانده است (حکم CMD-050).
///
/// صداقت داده (S-4): قرارداد سرور پارامتر فیلتر وضعیت ندارد (فقط `page`)
/// → قرص‌ها فقط ردیف‌های بارگذاری‌شده را صافی می‌کنند و شمارنده‌ی «در
/// جریان» تنها زمانی نمایش داده می‌شود که همه‌ی صفحات رسیده باشند.
/// ورود «ثبت پرونده جدید» پایان فهرست حفظ شده است (قابلیت M2، شات CMD-037).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../application/cases_controller.dart';
import '../domain/case_models.dart';

/// صافی فهرست — سه حالت (همه/در جریان/بسته)
enum _CaseFilter { all, open, closed }

extension _CaseFilterX on _CaseFilter {
  /// برچسب قرص‌ها — عین نسل قبل
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

  /// زیرنویس سربرگ — فقط داده‌ی واقعی: شمار کل از سرور، شمار «در جریان»
  /// از ردیف‌های بارگذاری‌شده و فقط وقتی همه‌ی صفحات رسیده‌اند
  String? _subtitle(CasesUi ui) {
    if (ui.status != LoadStatus.ready) return null;
    final total = JalaliCalendar.toPersianDigits(ui.total);
    final allLoaded = !ui.hasMore;
    if (!allLoaded) return '$total پرونده';
    final open =
        ui.rows.where((r) => r.status != CaseStatus.done.value).length;
    return '$total پرونده · ${JalaliCalendar.toPersianDigits(open)} در جریان';
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(casesControllerProvider);
    final controller = ref.read(casesControllerProvider.notifier);

    return Scaffold(
      appBar: DsTopBar('پرونده‌ها', subtitle: _subtitle(ui)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── قرص‌های فیلتر — هدف لمس ۴۸dp (F4) ──
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Ds.s16),
              children: [
                for (final f in _CaseFilter.values) ...[
                  _FilterPill(
                    label: f.label,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                  const SizedBox(width: Ds.s8),
                ],
              ],
            ),
          ),
          const SizedBox(height: Ds.s4),
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
    );
  }
}

/// فهرست + صفحه‌بندی بی‌نهایت روی نزدیکی به انتهای اسکرول — عین نسل قبل
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
    final light = Theme.of(context).brightness == Brightness.light;

    return RefreshIndicator(
      onRefresh: ref.read(casesControllerProvider.notifier).reload,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          Ds.s16,
          Ds.s8,
          Ds.s16,
          Ds.s32,
        ),
        children: [
          if (visible.isEmpty)
            // حالت خالی صادقانه — بدون هیچ داده‌ی جعلی (S-4)
            const DsEmptyState(
              icon: Icons.folder_off_outlined,
              title: 'پرونده‌ای در این وضعیت ندارید.',
            )
          else
            for (final row in visible) ...[
              DsTile(
                title: 'پرونده ${JalaliCalendar.toPersianDigits(row.id)}'
                    ' · ${row.title}',
                subtitle: _subtitleOf(row),
                trailing: DsPill(
                  row.statusValue.labelFa,
                  tone: row.status == CaseStatus.done.value
                      ? DsPillTone.neutral
                      : DsPillTone.info,
                ),
                onTap: () => context.push('/cases/${row.id}'),
              ),
              const SizedBox(height: Ds.s8),
            ],
          const SizedBox(height: Ds.s4),
          // ورود «ثبت پرونده جدید» — حفظ قابلیت M2 طبق شات تاییدشده‌ی CMD-037
          DsButton(
            'ثبت پرونده جدید',
            onPressed: () => context.push('/cases/new'),
            tone: DsButtonTone.ghost,
            expand: true,
          ),
          if (ui.loadingMore)
            const Padding(
              padding: EdgeInsets.all(Ds.s12),
              child: Center(child: DsRing()),
            )
          else if (!ui.hasMore && ui.rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Ds.s8),
              child: Text(
                'پرونده‌ی بیشتری نیست',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 12,
                  color: light ? Ds.inkFaint : Ds.inkFaintDark,
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

/// قرص فیلتر — انتخاب وضعیت با tint برند؛ هدف لمس ≥۴۸ (ویجت خصوصی:
/// کیت قرص انتخاب‌شدنی ندارد)
final class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final bg = selected
        ? (light ? Ds.primary : Ds.primaryDeep)
        : (light ? Ds.surface : Ds.surfaceDark);
    final fg = selected
        ? Ds.onPrimary
        : (light ? Ds.inkSoft : Ds.inkSoftDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ds.radiusChip),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: Ds.s16,
            vertical: Ds.s12,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Ds.radiusChip),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (light ? Ds.line : Ds.lineDark),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

/// اسکلت بارگذاری — پیش از رسیدن داده
final class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;
    return ListView.separated(
      padding: const EdgeInsets.all(Ds.s16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: Ds.s8),
      itemBuilder: (_, __) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(Ds.radiusCard),
          border: Border.all(color: light ? Ds.line : Ds.lineDark),
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
    return DsEmptyState(
      icon: Icons.folder_open_outlined,
      title: 'هنوز پرونده‌ای ثبت نکرده‌اید',
      actionLabel: 'ثبت پرونده جدید',
      onAction: onCreate,
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
    return DsEmptyState(
      icon: Icons.cloud_off_outlined,
      title: message,
      actionLabel: 'تلاش دوباره',
      onAction: onRetry,
    );
  }
}
