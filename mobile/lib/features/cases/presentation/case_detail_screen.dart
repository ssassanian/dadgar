/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی جزئیات پرونده — هویت بومی‌موبایلی «دادگر S»: سربرگ DsTopBar،
/// کارت «مسیر پرونده» با نوار DsJourneyBar به‌عنوان عنصر امضایی، کارت
/// «مشخصات پرونده» با DsKvRow، «گفتگو با وکیل» با DsBubble و «اسناد
/// پرونده». هیچ ارثی از نسل قبل (D-3) نیست؛ تنها رنگ‌بندی برند وب از
/// طریق توکن‌های Ds مشترک مانده است (حکم CMD-050).
///
/// صداقت داده (S-4) و نگاشت F1 (حکم مدیر — سند CMD-048):
///   * مسیر پرونده = شش مرحله‌ی حقوقی (ثبت/بررسی مدارک/طرح دعوا/جلسات/
///     صدور رأی/قطعی) با نگاشت نمایشی روی پنج وضعیت سرور — صفر DDL؛
///     جدول نگاشت در CasesContract.legalJourneyIndexFor.
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

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../../auth/application/session_controller.dart';
import '../../documents/data/documents_contract.dart';
import '../../documents/domain/document_models.dart';
import '../../messages/data/messages_contract.dart';
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

/// نگاشت F1 (حکم CMD-048): اندیس مرحله‌ی حقوقی جاری از وضعیت سرور —
/// شش برچسب حقوقی روی پنج وضعیت (حکم‌شده در CasesContract.legalJourneyIndexFor)؛
/// ناشناخته = null (نوار خنثی)
int? _journeyIndex(CaseStatus status) =>
    CasesContract.legalJourneyIndexFor(status.value);

/// صفحه‌ی جزئیات پرونده
final class CaseDetailScreen extends ConsumerWidget {
  const CaseDetailScreen({super.key, required this.caseId});

  final int caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(caseDetailProvider(caseId));

    return Scaffold(
      appBar: DsTopBar(
        'جزئیات پرونده',
        subtitle: 'پرونده ${JalaliCalendar.toPersianDigits(caseId)}',
        showBack: true,
        actions: [
          IconButton(
            tooltip: 'بارگذاری سند',
            onPressed: () => context.push('/cases/$caseId/upload'),
            icon: const Icon(Icons.upload_outlined),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: DsRing()),
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
    final light = Theme.of(context).brightness == Brightness.light;
    final created = JalaliCalendar.fromEpochSeconds(detail.createdAt);
    final updated = JalaliCalendar.fromEpochSeconds(detail.updatedAt);
    final description =
        detail.description ?? detail.excerpt ?? 'توضیحی ثبت نشده است.';
    final status = detail.statusValue;
    final active = status.value != CaseStatus.done.value;
    final journeyIdx = _journeyIndex(status);
    const journeySteps = CasesContract.legalJourney;
    final hasPrice = detail.finalPrice != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Ds.s16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── سربرگ محتوایی: عنوان درشت + قرص وضعیت ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      detail.title,
                      style: DsText.title.copyWith(
                        color: light ? Ds.ink : Ds.inkDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: Ds.s8),
                  DsPill(
                    status.labelFa,
                    tone: active ? DsPillTone.info : DsPillTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: Ds.s16),
              // ── مسیر پرونده (عنصر امضایی نسل S) — شش مرحله‌ی حقوقی ──
              // با نگاشت F1 روی پنج وضعیت سرور
              DsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CardHead(
                      'مسیر پرونده',
                      trailing: journeyIdx == null
                          ? null
                          : DsPill(
                              'مرحله‌ی ${JalaliCalendar.toPersianDigits(journeyIdx + 1)}'
                              ' از ${JalaliCalendar.toPersianDigits(journeySteps.length)}',
                              tone: DsPillTone.info,
                            ),
                    ),
                    const SizedBox(height: Ds.s12),
                    DsJourneyBar(
                      steps: journeySteps,
                      currentIndex: journeyIdx,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Ds.s12),
              // ── مشخصات پرونده — ردیف‌های kv ──
              DsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CardHead('مشخصات پرونده'),
                    const SizedBox(height: Ds.s4),
                    DsKvRow(
                      'وکیل',
                      detail.lawyerName.isEmpty
                          ? '— هنوز تخصیص نیافته'
                          : detail.lawyerName,
                    ),
                    DsKvRow('دسته', detail.category),
                    DsKvRow('وضعیت', status.labelFa),
                    DsKvRow('تاریخ ثبت', JalaliCalendar.formatLong(created)),
                    DsKvRow(
                      'آخرین به‌روزرسانی',
                      JalaliCalendar.formatLong(updated),
                      divider: !hasPrice,
                    ),
                    if (hasPrice)
                      DsKvRow(
                        'مبلغ نهایی',
                        '${JalaliCalendar.toPersianDigits(_grouped(detail.finalPrice!))} تومان',
                        divider: false,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Ds.s12),
              // ── توضیحات پرونده (حفظ قابلیت — داده‌ی واقعی مالک/مدیر) ──
              DsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CardHead('توضیحات پرونده'),
                    const SizedBox(height: Ds.s8),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: Ds.fontFamily,
                        fontSize: 13.5,
                        height: 1.9,
                        color: light ? Ds.ink : Ds.inkDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Ds.s12),
              // ── گفتگو با وکیل — قاعده‌ی سرور: فقط پرونده‌ی دارای وکیل ──
              DsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CardHead('گفتگو با وکیل'),
                    const SizedBox(height: Ds.s12),
                    if (_chatAllowed(status))
                      _ChatSection(caseId: detail.id)
                    else
                      const _NoteRow(
                        icon: Icons.lock_outline,
                        label: MessagesContract.chatNotActiveMessage,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Ds.s12),
              // ── اسناد پرونده — پالایش فهرست واقعی اسناد ──
              DsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CardHead(
                      'اسناد پرونده',
                      trailing: TextButton(
                        onPressed: () => context.push('/documents'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Ds.s8,
                          ),
                          minimumSize: const Size(48, 48),
                        ),
                        child: Text(
                          'همه‌ی اسناد گاوصندوق',
                          style: TextStyle(
                            fontFamily: Ds.fontFamily,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: light ? Ds.primary : Ds.cyan,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Ds.s4),
                    _DocsSection(caseId: detail.id),
                  ],
                ),
              ),
              const SizedBox(height: Ds.s12),
              // رزرو نوبت — F7 (حکم CMD-048): روی پرونده‌ی بسته CTA مرده
              // نمی‌ماند؛ یادداشت صادقانه جایگزین است.
              if (active)
                DsButton(
                  'رزرو نوبت با وکیل',
                  onPressed: () => context.go('/appointments'),
                  tone: DsButtonTone.outline,
                  expand: true,
                )
              else
                const _NoteRow(
                  icon: Icons.event_busy,
                  label:
                      'این پرونده بسته شده است — رزرو نوبت برای پرونده‌های فعال است.',
                ),
              const SizedBox(height: Ds.s12),
              if (isAdmin)
                _AdminActionsSection(detail: detail)
              else
                const _NoteRow(
                  icon: Icons.sync_alt,
                  label: 'پیشنهاد وکیل و گذار وضعیت: پس از اتصال زنده (D-6)',
                ),
              const SizedBox(height: Ds.s24),
            ],
          ),
        ),
      ),
    );
  }
}

/// سربرگ کارت — عنوان درشت + اقدام اختیاری (ویجت خصوصی مشترک کارت‌های
/// این صفحه؛ DsSectionHeader فضای عمودی بیشتری برای بدنه‌ی کارت دارد)
final class _CardHead extends StatelessWidget {
  const _CardHead(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: light ? Ds.ink : Ds.inkDark,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// یادداشت وضعیت — ردیف tint wash با آیکون؛ جایگزین چیپ فاز نسل قبل
final class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Ds.s12, vertical: 10),
      decoration: BoxDecoration(
        color: light ? Ds.wash : Ds.washDark,
        borderRadius: BorderRadius.circular(Ds.radiusField),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: light ? Ds.primaryDeep : Ds.cyan),
          const SizedBox(width: Ds.s8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12.5,
                height: 1.6,
                color: light ? Ds.inkSoft : Ds.inkSoftDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بخش گفتگو — آخرین پیام واقعی + دکمه‌ی ورود به گفتگو
final class _ChatSection extends ConsumerWidget {
  const _ChatSection({required this.caseId});

  final int caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(caseChatSnipProvider(caseId));
    final light = Theme.of(context).brightness == Brightness.light;

    final button = Padding(
      padding: const EdgeInsets.only(top: Ds.s12),
      child: DsButton(
        'گفتگو با وکیل',
        onPressed: () => context.push('/threads/$caseId'),
        expand: true,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (chat) {
          AsyncLoading() => const Center(
              child: Padding(
                padding: EdgeInsets.all(Ds.s8),
                child: DsRing(),
              ),
            ),
          AsyncError() =>
            const _NoteRow(icon: Icons.forum_outlined, label: 'گفتگو در دسترس نیست.'),
          AsyncValue(:final value?) when value.isNotEmpty => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsBubble(text: value.last.body, mine: value.last.mine),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Ds.s4),
                  child: Text(
                    MessagesContract.labelOfRole(value.last.role),
                    style: TextStyle(
                      fontFamily: Ds.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: light ? Ds.inkFaint : Ds.inkFaintDark,
                    ),
                  ),
                ),
              ],
            ),
          AsyncValue() => const _NoteRow(
              icon: Icons.forum_outlined,
              label: 'گفتگویی در این پرونده ثبت نشده است.',
            ),
        },
        button,
      ],
    );
  }
}

/// بخش اسناد — حداکثر دو سند آخر + لینک گاوصندوق در سربرگ کارت
final class _DocsSection extends ConsumerWidget {
  const _DocsSection({required this.caseId});

  final int caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(caseDocsSnipProvider(caseId));

    return switch (docs) {
      AsyncLoading() => const Center(
          child: Padding(padding: EdgeInsets.all(Ds.s8), child: DsRing()),
        ),
      AsyncError() => const _NoteRow(
          icon: Icons.folder_off_outlined,
          label: 'فهرست اسناد در دسترس نیست.',
        ),
      AsyncValue(:final value?) when value.isEmpty => const _NoteRow(
          icon: Icons.description_outlined,
          label: 'سندی برای این پرونده بارگذاری نشده است.',
        ),
      AsyncValue(:final value?) => Column(
          children: [
            for (var i = 0; i < value.length && i < 2; i++) ...[
              if (i > 0) const SizedBox(height: Ds.s8),
              DsTile(
                title: value[i].name,
                subtitle:
                    '${DocumentsContract.formatSize(value[i].size)} · ${JalaliCalendar.formatNumeric(JalaliCalendar.fromEpochSeconds(value[i].createdAt))}',
                trailing: DsPill(
                  value[i].shared
                      ? DocumentsContract.sharedLabel
                      : DocumentsContract.privateLabel,
                  tone: value[i].shared ? DsPillTone.info : DsPillTone.warn,
                ),
              ),
            ],
          ],
        ),
    };
  }
}

/// جداکننده‌ی هزارگان برای مبلغ — بدون وابستگی به intl
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
    final light = Theme.of(context).brightness == Brightness.light;

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
    final locked =
        status.value == 'assigned' || status.value == 'running' ||
            status.value == 'done';

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHead('اقدامات مدیر'),
          const SizedBox(height: Ds.s12),
          if (detail.proposals.isEmpty &&
              (status.value == 'waiting' || status.value == 'proposing'))
            Text(
              'هنوز پیشنهادی ثبت نشده است.',
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12.5,
                color: light ? Ds.inkSoft : Ds.inkSoftDark,
              ),
            ),
          for (final p in detail.proposals)
            Padding(
              padding: const EdgeInsets.only(bottom: Ds.s8),
              child: _ProposalCard(
                proposal: p,
                locked: locked,
                busy: busy,
                onAccept: () => _confirm(
                  context,
                  title: 'تایید پیشنهاد',
                  body:
                      'پیشنهاد ${p.lawyerName} به مبلغ ${JalaliCalendar.toPersianDigits(_grouped(p.amount))} تومان تایید شود؟ بقیه‌ی پیشنهادها رد و وکیل تخصیص می‌یابد.',
                  confirmLabel: 'تایید و تخصیص',
                  onOk: () => controller.acceptProposal(p.id),
                ),
              ),
            ),
          if (status.value == 'assigned')
            DsButton(
              'شروع اجرا',
              onPressed: busy
                  ? null
                  : () => _confirm(
                        context,
                        title: 'شروع اجرا',
                        body: 'وضعیت پرونده به «در حال انجام» تغییر کند؟',
                        confirmLabel: 'شروع اجرا',
                        onOk: () => controller.setStatus('running'),
                      ),
              icon: Icons.play_arrow_outlined,
              expand: true,
            )
          else if (status.value == 'running')
            DsButton(
              'بستن پرونده',
              onPressed: busy
                  ? null
                  : () => _confirm(
                        context,
                        title: 'بستن پرونده',
                        body:
                            'پرونده بسته شود؟ این گذار پایانی است و بازگشت‌پذیر نیست.',
                        confirmLabel: 'بستن پرونده',
                        onOk: () => controller.setStatus('done'),
                      ),
              tone: DsButtonTone.outline,
              icon: Icons.check_outlined,
              expand: true,
            )
          else if (status.value == 'done')
            const _NoteRow(
              icon: Icons.lock_outline,
              label: 'این پرونده بسته شده است و قابل تغییر نیست.',
            ),
        ],
      ),
    );
  }
}

/// کارت پیشنهاد وکیل — tint wash گرد با ردیف نام/وضعیت و مبلغ و مدت
final class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.locked,
    required this.busy,
    required this.onAccept,
  });

  final Proposal proposal;
  final bool locked;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final p = proposal;
    final statusColor = switch (p.status) {
      'accepted' => light ? Ds.green : Ds.mint,
      'rejected' => light ? Ds.error : Ds.rose,
      _ => light ? Ds.inkSoft : Ds.inkSoftDark,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Ds.s12),
      decoration: BoxDecoration(
        color: light ? Ds.wash : Ds.washDark,
        borderRadius: BorderRadius.circular(Ds.radiusField),
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
                  style: TextStyle(
                    fontFamily: Ds.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: light ? Ds.ink : Ds.inkDark,
                  ),
                ),
              ),
              Text(
                p.statusLabelFa,
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${JalaliCalendar.toPersianDigits(_grouped(p.amount))} تومان • '
            '${JalaliCalendar.toPersianDigits(p.days)} روز',
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 12.5,
              color: light ? Ds.inkSoft : Ds.inkSoftDark,
            ),
          ),
          if (p.note.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              p.note,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12.5,
                height: 1.7,
                color: light ? Ds.inkSoft : Ds.inkSoftDark,
              ),
            ),
          ],
          if (p.status == 'pending' && !locked) ...[
            const SizedBox(height: Ds.s8),
            DsButton(
              'تایید پیشنهاد',
              onPressed: busy ? null : onAccept,
              icon: Icons.check_circle_outline,
              expand: true,
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
    return DsEmptyState(
      icon: Icons.cloud_off_outlined,
      title: message,
      actionLabel: 'تلاش دوباره',
      onAction: onRetry,
    );
  }
}
