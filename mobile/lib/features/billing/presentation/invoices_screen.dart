/// صفحه‌ی «صورتحساب‌ها و پرداخت» مشتری — M4 (DOC-04 §۱۱ ردیف M4)
///
/// آینه‌ی صفحه‌ی cBill وب (CMD-005): ستون‌های فاکتور/تاریخ/مبلغ/وضعیت به‌شکل
/// کارت، خالی صادقانه با عین متن وب، دکمه‌ی «پرداخت آنلاین» با پیام صادقانه‌ی
/// درگاه (تصمیم باز CMD-005 — هیچ پرداخت جعلی ثبت نمی‌شود) و pull-to-refresh.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/tokens.dart';
import '../application/billing_controller.dart';
import '../data/billing_contract.dart';
import '../domain/invoice_models.dart';

/// صفحه‌ی فاکتورهای من
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(billingControllerProvider);
    final controller = ref.read(billingControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('صورتحساب‌ها و پرداخت')),
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

/// فهرست کارت فاکتورها — pull-to-refresh (پاسخ تخت سرور، بدون صفحه‌بندی)
final class _InvoicesList extends ConsumerWidget {
  const _InvoicesList({required this.ui});

  final BillingUi ui;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(billingControllerProvider.notifier);
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
          if (index == 0) return _SummaryBar(ui: ui);
          return _InvoiceCard(row: ui.rows[index - 1]);
        },
      ),
    );
  }
}

/// نوار خلاصه — «۳ فاکتور • ۱ در انتظار» با ارقام فارسی
final class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.ui});

  final BillingUi ui;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '${BillingContract.toPersianDigits(ui.rows.length)} فاکتور',
    ];
    if (ui.pendingCount > 0) {
      parts.add(
        '${BillingContract.toPersianDigits(ui.pendingCount)} در انتظار',
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: DadgarTokens.s4),
      child: Text(
        parts.join(' • '),
        style: const TextStyle(
          fontSize: 12,
          color: DadgarTokens.textSecondary,
        ),
      ),
    );
  }
}

/// کارت فاکتور — شماره/تاریخ شمسی/مبلغ/وضعیت (همان ستون‌های وب)
/// + دکمه‌ی «پرداخت آنلاین» صادقانه برای وضعیت «در انتظار»
final class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.row});

  final Invoice row;

  Color get _statusColor => switch (row.status) {
        'paid' => DadgarTokens.accent,
        'pending' => DadgarTokens.primary,
        _ => DadgarTokens.textSecondary,
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
                  'فاکتور ${BillingContract.toPersianDigits(row.id)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: DadgarTokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DadgarTokens.s8),
            Text(
              BillingContract.formatToman(row.amount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DadgarTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DadgarTokens.s4),
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 14,
                  color: DadgarTokens.textSecondary,
                ),
                const SizedBox(width: DadgarTokens.s4),
                Text(
                  JalaliCalendar.formatNumeric(created),
                  style: const TextStyle(
                    fontSize: 12,
                    color: DadgarTokens.textSecondary,
                  ),
                ),
                if (row.paidAt != null) ...[
                  const SizedBox(width: DadgarTokens.s8),
                  const Text('•',
                      style: TextStyle(color: DadgarTokens.textSecondary)),
                  const SizedBox(width: DadgarTokens.s8),
                  Text(
                    'پرداخت: ${JalaliCalendar.formatNumeric(JalaliCalendar.fromEpochSeconds(row.paidAt!))}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: DadgarTokens.accent,
                    ),
                  ),
                ],
              ],
            ),
            if (row.statusValue == InvoiceStatus.pending) ...[
              const SizedBox(height: DadgarTokens.s8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'درگاه پرداخت هنوز متصل نشده است؛ '
                        'پس از تصمیم مدیر فعال می‌شود.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                  icon: const Icon(Icons.payment_outlined, size: 18),
                  label: const Text('پرداخت آنلاین'),
                ),
              ),
            ],
          ],
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
