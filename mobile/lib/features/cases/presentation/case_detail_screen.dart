/// صفحه‌ی جزئیات پرونده — M2 (DOC-04 §۱۱ ردیف M2)
///
/// شکل داده همان `GET /api/cases/:id` سرور است: موکل توضیحات کامل می‌بیند،
/// وکیل/مدیر طبق نقش (S-4 — هیچ نقش جدیدی اختراع نمی‌شود). تاریخ‌ها با
/// تقویم شمسی نیتیو M3 و مبلغ با ارقام فارسی نمایش داده می‌شود.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/time/jalali.dart';
import '../../../design/tokens.dart';
import '../application/cases_controller.dart';
import '../domain/case_models.dart';

/// صفحه‌ی جزئیات پرونده
class CaseDetailScreen extends ConsumerWidget {
  const CaseDetailScreen({super.key, required this.caseId});

  final int caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(caseDetailProvider(caseId));

    return Scaffold(
      appBar: AppBar(
        title: Text('پرونده ${JalaliCalendar.toPersianDigits(caseId)}'),
        actions: [
          IconButton(
            tooltip: 'بارگذاری سند',
            onPressed: () => context.go('/cases/$caseId/upload'),
            icon: const Icon(Icons.upload_outlined),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorPane(
          message: error is ApiException
              ? error.message
              : 'خطای نامشخص در ارتباط با سرور',
          onRetry: () => ref.invalidate(caseDetailProvider(caseId)),
        ),
        data: (detail) => _DetailBody(detail: detail),
      ),
    );
  }
}

final class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final CaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final created = JalaliCalendar.fromEpochSeconds(detail.createdAt);
    final updated = JalaliCalendar.fromEpochSeconds(detail.updatedAt);
    final description =
        detail.description ?? detail.excerpt ?? 'توضیحی ثبت نشده است.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DadgarTokens.s16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // سربرگ: عنوان + وضعیت‌نشان
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DadgarTokens.s16),
              decoration: BoxDecoration(
                color: DadgarTokens.primary,
                borderRadius: BorderRadius.circular(DadgarTokens.radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.title,
                    style: const TextStyle(
                      color: DadgarTokens.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: DadgarTokens.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DadgarTokens.s8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DadgarTokens.onPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      detail.statusValue.labelFa,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: DadgarTokens.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DadgarTokens.s16),
            _InfoCard(
              rows: [
                ('دسته', detail.category),
                ('وضعیت', detail.statusValue.labelFa),
                ('تاریخ ثبت', JalaliCalendar.formatLong(created)),
                ('آخرین به‌روزرسانی', JalaliCalendar.formatLong(updated)),
                (
                  'وکیل تخصیص‌یافته',
                  detail.lawyerName.isEmpty
                      ? '— هنوز تخصیص نیافته'
                      : detail.lawyerName
                ),
                if (detail.finalPrice != null)
                  (
                    'مبلغ نهایی',
                    '${JalaliCalendar.toPersianDigits(_grouped(detail.finalPrice!))} تومان'
                  ),
              ],
            ),
            const SizedBox(height: DadgarTokens.s16),
            const Text(
              'توضیحات پرونده',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DadgarTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DadgarTokens.s8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DadgarTokens.s16),
              decoration: BoxDecoration(
                color: DadgarTokens.surface,
                borderRadius: BorderRadius.circular(DadgarTokens.radius),
                border: Border.all(
                  color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 2,
                  color: DadgarTokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: DadgarTokens.s24),
            const _PhaseChip(
              icon: Icons.sync_alt,
              label: 'پیشنهاد وکیل و گذار وضعیت: پس از اتصال زنده (D-6)',
            ),
          ],
        ),
      ),
    );
  }

  /// جداکننده‌ی هزارگان برای مبلغ — بدون وابستگی به intl
  static String _grouped(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      b.write(s[i]);
      final left = s.length - i - 1;
      if (left > 0 && left % 3 == 0) b.write(',');
    }
    return b.toString();
  }
}

/// کارت اطلاعات — ردیف‌های برچسب/مقدار
final class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DadgarTokens.s16),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DadgarTokens.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: DadgarTokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              Divider(
                height: 1,
                color: DadgarTokens.textSecondary.withValues(alpha: 0.12),
              ),
          ],
        ],
      ),
    );
  }
}

/// یادداشت وضعیت فاز — صداقت همان وب
final class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DadgarTokens.s12,
        vertical: DadgarTokens.s8,
      ),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DadgarTokens.accent),
          const SizedBox(width: DadgarTokens.s8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: DadgarTokens.textSecondary,
              ),
            ),
          ),
        ],
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
