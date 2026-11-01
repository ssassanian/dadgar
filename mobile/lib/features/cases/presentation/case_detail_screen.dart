/// صفحه‌ی جزئیات پرونده — M2 (DOC-04 §۱۱ ردیف M2)
///
/// CMD-045 (فاز ۲): بازطراحی D-3 عین طرح تاییدشده‌ی CMD-041 (`bDetail` در
/// `design-preview/prototype.html`): سربرگ عنوان+قرص، پنل «مسیر پرونده» با
/// عنصر امضایی، «مشخصات پرونده» با ردیف‌های kv، «گفتگو با وکیل»، «اسناد
/// پرونده» و دکمه‌ی شبح «رزرو نوبت با وکیل».
///
/// صداقت داده (S-4) و نگاشت F1 بدون حدس:
///   * مسیر پرونده = پنج وضعیت واقعی قرارداد سرور (waiting→done) —
///     شش مرحله‌ی حقوقی پروتوتایپ فقط با حکم مدیر/افزوده‌ی سرور (D-6).
///   * «گفتگو» فقط برای پرونده‌های دارای وکیل (assigned/running/done)
///     طبق قاعده‌ی سرور؛ بقیه پیام عین سرور می‌بینند
///     (MessagesContract.chatNotActiveMessage) و هیچ فراخوانی زده نمی‌شود.
///   * «اسناد پرونده» = پالایش فهرست واقعی `GET /api/documents` بر caseId.
///
/// اقدامات مدیر (M6/CMD-028) با همان منطق و رشته‌های سرور حفظ شده است.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/time/jalali.dart';
import '../../../design/d3_kit.dart';
import '../../../design/journey_bar.dart';
import '../../../design/tokens.dart';
import '../../auth/application/session_controller.dart';
import '../../documents/data/documents_contract.dart';
import '../../documents/data/documents_repository.dart';
import '../../documents/domain/document_models.dart';
import '../../messages/data/messages_contract.dart';
import '../../messages/data/messages_repository.dart';
import '../../messages/domain/chat_models.dart';
import '../application/cases_controller.dart';
import '../data/cases_contract.dart';
import '../domain/case_models.dart';

/// آخرین پیام‌های گفتگوی پرونده — فقط برای پرونده‌ی دارای وکیل تماشا می‌شود
///
/// خطا عمداً بلند می‌شود تا AsyncValue تصمیم رندر را بگیرد (پیام صادقانه)،
/// دکمه‌ی ورود به گفتگو همیشه حاضر است و خود صفحه‌ی چت خطا را زنده نشان
/// می‌دهد. `retry: null` — همان استدلال caseDetailProvider: خطای ۴xx
/// (۴۰۴/گفتگوی غیرفعال) وضعیت دائمی است و تکرارش معنا ندارد (Riverpod 3).
final caseChatSnipProvider =
    FutureProvider.family<List<ChatMessage>, int>(
  (ref, caseId) async {
    final repo = ref.watch(messagesRepositoryProvider);
    final envelope = await repo.fetchMessages(caseId: caseId);
    return envelope.rows;
  },
  retry: (retryCount, error) => null,
);

/// اسناد یک پرونده — پالایش فهرست واقعی اسناد بر شناسه‌ی پرونده
final caseDocsSnipProvider =
    FutureProvider.family<List<DocSummary>, int>(
  (ref, caseId) async {
    final repo = ref.watch(documentsRepositoryProvider);
    final all = await repo.fetchDocuments();
    return all.where((d) => d.caseId == caseId).toList(growable: false);
  },
  retry: (retryCount, error) => null,
);

/// پرونده‌ی دارای وکیل — قاعده‌ی سرور برای فعال‌بودن گفتگو
bool _chatAllowed(CaseStatus status) => switch (status.value) {
      'assigned' || 'running' || 'done' => true,
      _ => false,
    };

/// اندیس مرحله در چرخه‌ی پنج‌وضعیتی سرور — ناشناخته = null (نوار خنثی)
int? _journeyIndex(CaseStatus status) => switch (status.value) {
      'waiting' => 0,
      'proposing' => 1,
      'assigned' => 2,
      'running' => 3,
      'done' => 4,
      _ => null,
    };

/// صفحه‌ی جزئیات پرونده
final class CaseDetailScreen extends ConsumerWidget {
  const CaseDetailScreen({super.key, required this.caseId});

  final int caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(caseDetailProvider(caseId));

    return Scaffold(
      backgroundColor: DadgarTokens.background,
      appBar: AppBar(
        // نوار بالای طرح: کاغذ گرم، متن مرکب، زیرنویس پرونده
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
              'جزئیات پرونده',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: DadgarTokens.textPrimary,
              ),
            ),
            Text(
              'پرونده ${JalaliCalendar.toPersianDigits(caseId)}',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: DadgarTokens.textFaint,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'بارگذاری سند',
            onPressed: () => context.push('/cases/$caseId/upload'),
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
    final status = detail.statusValue;
    final active = status.value != CaseStatus.done.value;
    final journeyIdx = _journeyIndex(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DadgarTokens.s16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── سربرگ طرح (d-head): عنوان ۲۲px + قرص وضعیت ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    detail.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: DadgarTokens.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: DadgarTokens.s8),
                DadgarPill(
                  status.labelFa,
                  variant: active
                      ? DadgarPillVariant.data
                      : DadgarPillVariant.neutral,
                ),
              ],
            ),
            const SizedBox(height: DadgarTokens.s12),
            // ── پنل مسیر پرونده (عنصر امضایی) — پنج وضعیت واقعی سرور ──
            DadgarPanel(
              head: 'مسیر پرونده',
              trailing: journeyIdx == null
                  ? null
                  : DadgarPill(
                      'مرحله‌ی ${JalaliCalendar.toPersianDigits(journeyIdx + 1)} از ${JalaliCalendar.toPersianDigits(CasesContract.statusLabels.length)}',
                      variant: DadgarPillVariant.data,
                    ),
              child: DadgarJourneyBar(
                steps: CasesContract.statusLabels.values.toList(growable: false),
                current: journeyIdx,
              ),
            ),
            const SizedBox(height: DadgarTokens.s12),
            // ── مشخصات پرونده — ردیف‌های kv عین طرح ──
            DadgarPanel(
              head: 'مشخصات پرونده',
              child: Column(
                children: [
                  _kv('وکیل',
                      detail.lawyerName.isEmpty ? '— هنوز تخصیص نیافته' : detail.lawyerName),
                  const DadgarKvRule(),
                  _kv('دسته', detail.category),
                  const DadgarKvRule(),
                  _kv('وضعیت', status.labelFa),
                  const DadgarKvRule(),
                  _kv('تاریخ ثبت', JalaliCalendar.formatLong(created)),
                  const DadgarKvRule(),
                  _kv('آخرین به‌روزرسانی', JalaliCalendar.formatLong(updated)),
                  if (detail.finalPrice != null) ...[
                    const DadgarKvRule(),
                    _kv(
                      'مبلغ نهایی',
                      '${JalaliCalendar.toPersianDigits(_grouped(detail.finalPrice!))} تومان',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: DadgarTokens.s12),
            // ── توضیحات پرونده (حفظ قابلیت — داده‌ی واقعی مالک/مدیر) ──
            DadgarPanel(
              head: 'توضیحات پرونده',
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 2,
                  color: DadgarTokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: DadgarTokens.s12),
            // ── گفتگو با وکیل — قاعده‌ی سرور: فقط پرونده‌ی دارای وکیل ──
            if (_chatAllowed(status))
              DadgarPanel(
                head: 'گفتگو با وکیل',
                child: _ChatSection(caseId: detail.id),
              )
            else
              DadgarPanel(
                head: 'گفتگو با وکیل',
                child: DadgarEmptyBox(MessagesContract.chatNotActiveMessage),
              ),
            const SizedBox(height: DadgarTokens.s12),
            // ── اسناد پرونده — پالایش فهرست واقعی اسناد ──
            DadgarPanel(
              head: 'اسناد پرونده',
              trailing: DadgarCardLink(
                'همه‌ی اسناد گاوصندوق',
                onTap: () => context.push('/documents'),
              ),
              child: _DocsSection(caseId: detail.id),
            ),
            const SizedBox(height: DadgarTokens.s12),
            // رزرو نوبت = فعال‌سازی تب نوبت (عین یال طرح)
            DadgarGhostButton(
              'رزرو نوبت با وکیل',
              onPressed: () => context.go('/appointments'),
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

  /// یک ردیف kv — کلید ثانویه/مقدار اصلی
  Widget _kv(String k, String v) => DadgarKvRow(k, v);

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

/// بخش گفتگو — آخرین پیام واقعی + دکمه‌ی ورود به گفتگو
final class _ChatSection extends ConsumerWidget {
  const _ChatSection({required this.caseId});

  final int caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(caseChatSnipProvider(caseId));

    final button = Padding(
      padding: const EdgeInsets.only(top: DadgarTokens.s12),
      child: DadgarPrimaryButton(
        'گفتگو با وکیل',
        onPressed: () => context.push('/threads/$caseId'),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (chat) {
          AsyncLoading() => const Center(
              child: Padding(
                padding: EdgeInsets.all(DadgarTokens.s8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          AsyncError() => const DadgarEmptyBox('گفتگو در دسترس نیست.'),
          AsyncValue(:final value?) when value.isNotEmpty => DadgarLawyerMessage(
              body: value.last.body,
              meta: MessagesContract.labelOfRole(value.last.role),
            ),
          AsyncValue() => const DadgarEmptyBox(
              'گفتگویی در این پرونده ثبت نشده است.',
            ),
        },
        button,
      ],
    );
  }
}

/// بخش اسناد — حداکثر دو سند آخر + لینک گاوصندوق در سربرگ پنل
final class _DocsSection extends ConsumerWidget {
  const _DocsSection({required this.caseId});

  final int caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(caseDocsSnipProvider(caseId));

    return switch (docs) {
      AsyncLoading() => const Center(
          child: Padding(
            padding: EdgeInsets.all(DadgarTokens.s8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      AsyncError() =>
        const DadgarEmptyBox('فهرست اسناد در دسترس نیست.'),
      AsyncValue(:final value?) when value.isEmpty => const DadgarEmptyBox(
          'سندی برای این پرونده بارگذاری نشده است.',
        ),
      AsyncValue(:final value?) => Column(
          children: [
            for (var i = 0; i < value.length && i < 2; i++) ...[
              if (i > 0) const DadgarRowRule(),
              DadgarListRow(
                title: value[i].name,
                subtitle:
                    '${DocumentsContract.formatSize(value[i].size)} · ${JalaliCalendar.formatNumeric(JalaliCalendar.fromEpochSeconds(value[i].createdAt))}',
                side: DadgarPill(
                  value[i].shared
                      ? DocumentsContract.sharedLabel
                      : DocumentsContract.privateLabel,
                ),
                minHeight: 56,
              ),
            ],
          ],
        ),
    };
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
        border: Border.all(color: DadgarTokens.cardBorder),
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
    return DadgarPanel(
      head: 'اقدامات مدیر',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  border: Border.all(color: DadgarTokens.cardBorder),
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
            DadgarGhostButton('تلاش دوباره', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
