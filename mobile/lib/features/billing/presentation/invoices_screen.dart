/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی «فاکتورها» مشتری — تب فاکتور پوسته‌ی پنج‌تبی (DOC-04 §۱۱ ردیف M4).
///
/// رفتار عین نسل قبل حفظ شده است: فهرست تخت فاکتورها (قرارداد CMD-005)،
/// پنل «بدهی فعلی» از جمع واقعی فاکتورهای در انتظار، دکمه‌ی «پرداخت آنلاین»
/// با POST /api/payments/request (تا انتخاب درگاه: پیام صادقانه‌ی سرور؛
/// پس از فعال‌سازی: لانچر pay_url) و PDF هر فاکتور (M6/CMD-028).
///
/// صداقت داده (S-4): سرور «سررسید» ندارد (مدل Invoice فقط createdAt/paidAt)
/// → ردیف «صدور» برای در انتظار و «پرداخت» برای پرداخت‌شده؛ رقم قهرمان =
/// جمع واقعی فاکتورهای pending بارگذاری‌شده. صفر داده‌ی جعلی.
///
/// هویت بصری نسل S: DsTopBar/DsCard/DsPill/DsKvRow/DsButton/DsEmptyState —
/// رنگ فقط از توکن‌های Ds؛ دارک‌مود با Theme.of(context).brightness.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../application/billing_controller.dart';
import '../data/billing_contract.dart';
import '../domain/invoice_models.dart';
import '../pdf/invoice_pdf.dart';

/// تُن قرص وضعیت فاکتور — پرداخت‌شده=سبز، در انتظار=کهربایی، ناشناخته=خنثی
DsPillTone _statusTone(Invoice row) => switch (row.statusValue.value) {
      'paid' => DsPillTone.success,
      'pending' => DsPillTone.warn,
      _ => DsPillTone.neutral,
    };

/// صفحه‌ی فاکتورهای من — تب پوسته با DsTopBar نسل S
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(billingControllerProvider);
    final controller = ref.read(billingControllerProvider.notifier);

    return Scaffold(
      appBar: DsTopBar(
        'فاکتورها',
        subtitle: ui.status == LoadStatus.ready
            ? '${BillingContract.toPersianDigits(ui.rows.length)} فاکتور'
            : null,
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const _SkeletonList(),
        LoadStatus.error => _ErrorPane(
            message: ui.message ?? 'خطای نامشخص',
            onRetry: controller.reload,
          ),
        LoadStatus.ready when ui.rows.isEmpty => const _EmptyPane(),
        LoadStatus.ready => _InvoicesList(ui: ui),
      },
    );
  }
}

/// فهرست — پنل بدهی + کارت‌های فاکتور + یادداشت صادقانه‌ی درگاه
final class _InvoicesList extends ConsumerWidget {
  const _InvoicesList({required this.ui});

  final BillingUi ui;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unpaid = ui.rows
        .where((r) => r.statusValue == InvoiceStatus.pending)
        .toList(growable: false);
    final debt = unpaid.fold<int>(0, (sum, r) => sum + r.amount);

    return RefreshIndicator(
      onRefresh: ref.read(billingControllerProvider.notifier).reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Ds.s16, Ds.s12, Ds.s16, Ds.s32),
        children: [
          _DebtCard(debt: debt, unpaidCount: unpaid.length),
          const SizedBox(height: Ds.s16),
          for (final row in ui.rows) ...[
            _InvoiceCard(row: row),
            const SizedBox(height: Ds.s8),
          ],
          const SizedBox(height: Ds.s8),
          const _ZibalNote(),
        ],
      ),
    );
  }
}

/// پنل «بدهی فعلی» — رقم قهرمان از داده‌ی واقعی (S-4)
final class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.debt, required this.unpaidCount});

  final int debt;
  final int unpaidCount;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final settled = unpaidCount == 0;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بدهی فعلی',
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: light ? Ds.inkSoft : Ds.inkSoftDark,
            ),
          ),
          const SizedBox(height: Ds.s4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                BillingContract.toPersianDigits(debt),
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: light ? Ds.ink : Ds.inkDark,
                ),
              ),
              const SizedBox(width: Ds.s8),
              Text(
                'تومان',
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 13,
                  color: light ? Ds.inkSoft : Ds.inkSoftDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: Ds.s4),
          Text(
            settled
                ? 'همه‌ی فاکتورها پرداخت شده است'
                : 'از ${BillingContract.toPersianDigits(unpaidCount)}'
                    ' فاکتور پرداخت‌نشده',
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 12.5,
              fontWeight: settled ? FontWeight.w600 : FontWeight.w400,
              color: settled
                  ? (light ? Ds.green : Ds.mint)
                  : (light ? Ds.amberInk : Ds.amber),
            ),
          ),
        ],
      ),
    );
  }
}

/// کارت فاکتور — سربرگ با قرص وضعیت + ردیف‌های مبلغ/تاریخ + پرداخت یا PDF
final class _InvoiceCard extends ConsumerWidget {
  const _InvoiceCard({required this.row});

  final Invoice row;

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(billingControllerProvider.notifier);
    final result = await controller.requestPayment(row.id);
    if (!context.mounted) return;
    switch (result) {
      case PayNotConfigured(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case PayUrlReady(:final url):
        await ref.read(payUrlLauncherProvider)(url);
      case null:
        break;
    }
  }

  Future<void> _sharePdf(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final (regular, bold) = await InvoicePdf.loadFonts();
      final bytes = await InvoicePdf.build(
        invoice: row,
        regular: regular,
        bold: bold,
      );
      await ref.read(pdfShareProvider)(InvoicePdf.fileName(row), bytes);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ساخت PDF ناموفق بود — دوباره تلاش کنید.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final light = Theme.of(context).brightness == Brightness.light;
    final pending = row.statusValue == InvoiceStatus.pending;
    final created = JalaliCalendar.fromEpochSeconds(row.createdAt);
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: light ? Ds.wash : Ds.washDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 21,
                  color: light ? Ds.primary : Ds.cyan,
                ),
              ),
              const SizedBox(width: Ds.s12),
              Expanded(
                child: Text(
                  'فاکتور ${BillingContract.toPersianDigits(row.id)}',
                  style: const TextStyle(
                    fontFamily: Ds.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Ds.ink,
                  ),
                ),
              ),
              DsPill(row.statusValue.labelFa, tone: _statusTone(row)),
            ],
          ),
          const SizedBox(height: Ds.s12),
          DsKvRow('مبلغ', BillingContract.formatToman(row.amount)),
          if (pending)
            DsKvRow(
              'صدور',
              JalaliCalendar.formatNumeric(created),
              divider: false,
            )
          else
            DsKvRow(
              'پرداخت',
              JalaliCalendar.formatNumeric(
                JalaliCalendar.fromEpochSeconds(row.paidAt!),
              ),
              valueTone: light ? Ds.green : Ds.mint,
              divider: false,
            ),
          const SizedBox(height: Ds.s12),
          Row(
            children: [
              if (pending) ...[
                Expanded(
                  child: DsButton(
                    'پرداخت آنلاین',
                    onPressed: () => _pay(context, ref),
                  ),
                ),
                const SizedBox(width: Ds.s8),
              ] else
                const Spacer(),
              // M6/CMD-028 — PDF هر فاکتور (هدف لمس پیش‌فرض IconButton ≥۴۸)
              IconButton(
                tooltip: 'PDF فاکتور',
                onPressed: () => _sharePdf(context, ref),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                color: light ? Ds.inkSoft : Ds.inkSoftDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// یادداشت درگاه — عین متن نسل قبل، روی tint آبی نسل S
final class _ZibalNote extends StatelessWidget {
  const _ZibalNote();

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(Ds.s12),
      decoration: BoxDecoration(
        color: light ? Ds.wash : Ds.washDark,
        borderRadius: BorderRadius.circular(Ds.radiusField),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: light ? Ds.inkSoft : Ds.inkSoftDark,
          ),
          const SizedBox(width: Ds.s8),
          Expanded(
            child: Text(
              'پرداخت از طریق درگاه زیبال انجام می‌شود — تا اتصال زنده '
              '(D-6) هیچ پرداخت واقعی ثبت نمی‌شود.',
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12,
                height: 1.7,
                color: light ? Ds.inkSoft : Ds.inkSoftDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// اسکلت بارگذاری — ایستا (بدون انیمیشن بی‌پایان؛ پوسته/تست‌ها pumpAndSettle دارند)
final class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final line = light ? Ds.line : Ds.lineDark;
    final bone = light ? Ds.wash : Ds.washDark;
    return ListView.separated(
      padding: const EdgeInsets.all(Ds.s16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: Ds.s8),
      itemBuilder: (_, __) => Container(
        height: 92,
        padding: const EdgeInsets.all(Ds.s16),
        decoration: BoxDecoration(
          color: light ? Ds.surface : Ds.surfaceDark,
          borderRadius: BorderRadius.circular(Ds.radiusCard),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bone,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 64,
                  height: 18,
                  decoration: BoxDecoration(
                    color: bone,
                    borderRadius: BorderRadius.circular(Ds.radiusChip),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: bone,
                borderRadius: BorderRadius.circular(Ds.s4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// خالی صادقانه — عین متن وب CMD-005 (بدون داده‌ی جعلی)
final class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return DsEmptyState(
      icon: Icons.receipt_long_outlined,
      title: BillingContract.emptyMessage,
    );
  }
}

/// خطای صادقانه + تلاش دوباره — پیام عین سرور (D-6 برای ۴۰۱)
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
