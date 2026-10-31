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
import '../../auth/application/session_controller.dart';
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
        data: (detail) {
          // M6 (CMD-028): هدف کنترلر اقدامات مدیر = همین پرونده
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(caseActionsProvider.notifier).setTarget(caseId);
          });
          return _DetailBody(detail: detail);
        },
      ),
    );
  }
}

final class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final CaseDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(sessionMeProvider);
    final isAdmin = meAsync.value?.isAdmin ?? false;
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
            if (isAdmin)
              _AdminActionsSection(detail: detail)
            else
              const _PhaseChip(
                icon: Icons.sync_alt,
                label: 'پیشنهاد وکیل و گذار وضعیت: پس از اتصال زنده (D-6)',
              ),
          ],
        ),
      ),
    );
  }

  /// جداکننده‌ی هزارگان برای مبلغ — بدون وابستگی به intl (همان الگوی _grouped)
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

/// جداکننده‌ی هزارگان — در دسترس همه‌ی ویجت‌های این فایل
String _grouped(int value) {
  final s = value.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    b.write(s[i]);
    final left = s.length - i - 1;
    if (left > 0 && left % 3 == 0) b.write(',');
  }
  return b.toString();
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

/// بخش اقدامات مدیر روی پرونده — M6 (CMD-028)
///
/// حکم مدیر: «مالی + اقدامات پرونده» — این بخش همان اقدامات مجاز سرور است:
///   waiting/proposing: فهرست پیشنهادها + دکمه‌ی «تایید پیشنهاد» (اتمیک)
///   assigned: «شروع اجرا» (→ running)
///   running: «بستن پرونده» (→ done — پایانی)
///   done: یادداشت صادقانه‌ی بسته‌بودن
/// نقش‌بندی نهایی سمت سرور است؛ این UI فقط برای نقش مدیر رندر می‌شود.
final class _AdminActionsSection extends ConsumerWidget {
  const _AdminActionsSection({required this.detail});

  final CaseDetail detail;

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required VoidCallback onOk,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (ok == true) onOk();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(caseActionsProvider);
    final controller = ref.read(caseActionsProvider.notifier);
    final busy = actions.busy;

    ref.listen<CaseActionsUi>(caseActionsProvider, (prev, next) {
      final msg = next.message;
      if (msg != null && msg.isNotEmpty && prev?.message != msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final status = detail.statusValue;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اقدامات مدیر',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DadgarTokens.textPrimary,
            ),
          ),
          const SizedBox(height: DadgarTokens.s8),
          if (detail.proposals.isEmpty && (status.value == 'waiting' || status.value == 'proposing'))
            const Text(
              'هنوز پیشنهادی ثبت نشده است.',
              style: TextStyle(
                fontSize: 12,
                color: DadgarTokens.textSecondary,
              ),
            ),
          for (final p in detail.proposals)
            Padding(
              padding: const EdgeInsets.only(bottom: DadgarTokens.s8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DadgarTokens.s8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DadgarTokens.radius),
                  border: Border.all(
                    color: DadgarTokens.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.lawyerName.isEmpty
                                ? 'وکیل #${JalaliCalendar.toPersianDigits(p.id)}'
                                : p.lawyerName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: DadgarTokens.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          p.statusLabelFa,
                          style: TextStyle(
                            fontSize: 11,
                            color: p.status == 'accepted'
                                ? DadgarTokens.accent
                                : p.status == 'rejected'
                                    ? DadgarTokens.error
                                    : DadgarTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${JalaliCalendar.toPersianDigits(_grouped(p.amount))} تومان • '
                      '${JalaliCalendar.toPersianDigits(p.days)} روز',
                      style: const TextStyle(
                        fontSize: 12,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
                    if (p.note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.note,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.7,
                          color: DadgarTokens.textSecondary,
                        ),
                      ),
                    ],
                    if (p.status == 'pending' && status.value != 'assigned' && status.value != 'running' && status.value != 'done') ...[
                      const SizedBox(height: DadgarTokens.s8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => _confirm(
                                    context,
                                    title: 'تایید پیشنهاد',
                                    body:
                                        'پیشنهاد ${p.lawyerName} به مبلغ ${JalaliCalendar.toPersianDigits(_grouped(p.amount))} تومان تایید شود؟ بقیه‌ی پیشنهادها رد و وکیل تخصیص می‌یابد.',
                                    confirmLabel: 'تایید و تخصیص',
                                    onOk: () =>
                                        controller.acceptProposal(p.id),
                                  ),
                          icon: const Icon(Icons.check_circle_outline,
                              size: 18),
                          label: const Text('تایید پیشنهاد'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (status.value == 'assigned') ...[
            const SizedBox(height: DadgarTokens.s8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => _confirm(
                          context,
                          title: 'شروع اجرا',
                          body: 'وضعیت پرونده به «در حال انجام» تغییر کند؟',
                          confirmLabel: 'شروع اجرا',
                          onOk: () => controller.setStatus('running'),
                        ),
                icon: const Icon(Icons.play_arrow_outlined, size: 18),
                label: const Text('شروع اجرا'),
              ),
            ),
          ] else if (status.value == 'running') ...[
            const SizedBox(height: DadgarTokens.s8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _confirm(
                          context,
                          title: 'بستن پرونده',
                          body:
                              'پرونده بسته شود؟ این گذار پایانی است و برگشت‌پذیر نیست.',
                          confirmLabel: 'بستن پرونده',
                          onOk: () => controller.setStatus('done'),
                        ),
                icon: const Icon(Icons.check_outlined, size: 18),
                label: const Text('بستن پرونده'),
              ),
            ),
          ] else if (status.value == 'done') ...[
            const SizedBox(height: DadgarTokens.s8),
            const _PhaseChip(
              icon: Icons.lock_outline,
              label: 'این پرونده بسته شده است و قابل تغییر نیست.',
            ),
          ],
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
