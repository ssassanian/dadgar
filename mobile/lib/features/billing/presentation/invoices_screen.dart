/// صفحه‌ی «فاکتورها» مشتری — تب M4 (DOC-04 §۱۱ ردیف M4)
///
/// CMD-046 (فاز ۳): بازطراحی D-3 عین طرح تاییدشده‌ی CMD-041 (`bInv` در
/// `design-preview/prototype.html`): نوار بالای ۴۸px با شمارنده، پنل
/// «بدهی فعلی» با رقم قهرمان، ردیف‌های دوخطی r-main/r-side با دکمه‌ی
/// پرداخت/قرص پرداخت‌شده و یادداشت درگاه زیبال.
///
/// صداقت داده (S-4): سرور «سررسید» ندارد (مدل Invoice فقط
/// createdAt/paidAt) → ردیف «صدور: …» و برای پرداخت‌شده «· پرداخت: …».
/// رقم قهرمان = مجموع واقعی فاکتورهای pending بارگذاری‌شده.
/// دکمه‌ی PDF (M6/CMD-028) و جریان پرداخت آنلاین (POST
/// /api/payments/request — تا انتخاب درگاه 503 با پیام صادقانه) حفظ شدند.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/d3_kit.dart';
import '../../../design/tokens.dart';
import '../application/billing_controller.dart';
import '../data/billing_contract.dart';
import '../domain/invoice_models.dart';
import '../pdf/invoice_pdf.dart';

/// صفحه‌ی فاکتورهای من — تب پوسته (بدون AppBar؛ نوار بالای طرح)
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(billingControllerProvider);
    final controller = ref.read(billingControllerProvider.notifier);

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
                title: 'فاکتورها',
                subtitle: ui.status == LoadStatus.ready
                    ? '${BillingContract.toPersianDigits(ui.rows.length)} فاکتور'
                    : null,
              ),
            ),
            Expanded(
              child: switch (ui.status) {
                LoadStatus.loading => const _SkeletonList(),
                LoadStatus.error => _ErrorPane(
                    message: ui.message ?? 'خطای نامشخص',
                    onRetry: controller.reload,
                  ),
                LoadStatus.ready when ui.rows.isEmpty => const _EmptyPane(),
                LoadStatus.ready => _InvoicesList(ui: ui),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// فهرست — پنل بدهی + پنل ردیف‌ها (عین bInv)
final class _InvoicesList extends ConsumerWidget {
  const _InvoicesList({required this.ui});

  final BillingUi ui;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unpaid = ui.rows
        .where((r) => r.statusValue == InvoiceStatus.pending)
        .toList(growable: false);
    final debt =
        unpaid.fold<int>(0, (sum, r) => sum + r.amount);

    return RefreshIndicator(
      onRefresh: ref.read(billingControllerProvider.notifier).reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          DadgarTokens.s16,
          DadgarTokens.s12,
          DadgarTokens.s16,
          DadgarTokens.s32,
        ),
        children: [
          // ── پنل «بدهی فعلی» — رقم قهرمان از داده‌ی واقعی ──
          DadgarPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'بدهی فعلی',
                  style: TextStyle(
                    fontSize: 13,
                    color: DadgarTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: DadgarTokens.s4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      BillingContract.toPersianDigits(debt),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: DadgarTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(width: DadgarTokens.s4),
                    const Text(
                      'تومان',
                      style: TextStyle(
                        fontSize: 13,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DadgarTokens.s4),
                Text(
                  unpaid.isEmpty
                      ? 'همه‌ی فاکتورها پرداخت شده است'
                      : 'از ${BillingContract.toPersianDigits(unpaid.length)}'
                          ' فاکتور پرداخت‌نشده',
                  style: const TextStyle(
                    fontSize: 12,
                    color: DadgarTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DadgarTokens.s12),
          // ── پنل ردیف‌ها — r-main/r-side عین طرح ──
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
                  _InvoiceRow(row: ui.rows[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: DadgarTokens.s12),
          const DadgarEmptyBox(
            'پرداخت از طریق درگاه زیبال انجام می‌شود — تا اتصال زنده '
            '(D-6) هیچ پرداخت واقعی ثبت نمی‌شود.',
          ),
        ],
      ),
    );
  }
}

/// ردیف فاکتور — عنوان/تاریخ + دکمه‌ی PDF (M6) + پرداخت یا قرص وضعیت
final class _InvoiceRow extends ConsumerWidget {
  const _InvoiceRow({required this.row});

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
    final created = JalaliCalendar.fromEpochSeconds(row.createdAt);
    final pending = row.statusValue == InvoiceStatus.pending;
    return DadgarListRow(
      title: 'فاکتور ${BillingContract.toPersianDigits(row.id)}',
      // خط دوم — مبلغ واقعی + تاریخ عین سرور (S-4: «سررسید» در مدل نیست)
      subtitle: pending
          ? '${BillingContract.formatToman(row.amount)}'
              ' · صدور: ${JalaliCalendar.formatNumeric(created)}'
          : '${BillingContract.formatToman(row.amount)}'
              ' · پرداخت: ${JalaliCalendar.formatNumeric(JalaliCalendar.fromEpochSeconds(row.paidAt!))}',
      side: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // M6/CMD-028 — PDF هر فاکتور (عنصر icon-btn ۴۰px خود طرح)
          IconButton(
            tooltip: 'PDF فاکتور',
            onPressed: () => _sharePdf(context, ref),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            visualDensity: VisualDensity.compact,
            color: DadgarTokens.textSecondary,
          ),
          const SizedBox(width: DadgarTokens.s4),
          pending
              ? _PayButton(onPay: () => _pay(context, ref))
              : DadgarPill(
                  row.statusValue.labelFa,
                  variant: DadgarPillVariant.positive,
                ),
        ],
      ),
      minHeight: 72,
    );
  }
}

/// دکمه‌ی کوچک پرداخت — کلاس `.btn.sm` طرح (لمس ≥۴۴ — F4)
final class _PayButton extends StatelessWidget {
  const _PayButton({required this.onPay});

  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: DadgarTokens.textPrimary,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPay,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: const Text(
              'پرداخت آنلاین',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: DadgarTokens.surface,
              ),
            ),
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
          border: Border.all(color: DadgarTokens.cardBorder),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DadgarTokens.s24),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: DadgarTokens.textSecondary,
            ),
            const SizedBox(height: DadgarTokens.s12),
            const Text(
              'هنوز فاکتوری برای شما صادر نشده است.',
              style: TextStyle(
                fontSize: 14,
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
