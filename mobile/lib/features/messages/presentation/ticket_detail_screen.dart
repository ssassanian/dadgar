/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی گفتگوی یک تیکت — M5 (DOC-04 §۱۱ ردیف M5).
///
/// آینه‌ی GET /api/tickets/:id سرور: پیام‌ها با DsBubble بر پایه‌ی `mine`
/// سرور (خودم = tint آبی)، پاسخ با POST replies، تیکت بسته با پیام عین
/// سرور غیرفعال می‌شود و وضعیت پس از هر پاسخ با بازخوانی تازه می‌شود.
/// نسل S: سربرگ DsCard با قرص وضعیت DsPill و ردیف‌های DsKvRow، حباب‌ها
/// با برچسب نقشِ فرستنده روی حباب طرف مقابل.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../application/tickets_controller.dart';
import '../data/messages_contract.dart';
import '../domain/ticket_models.dart';

/// صفحه‌ی جزئیات تیکت
class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() =>
      _TicketDetailScreenState();
}

final class _TicketDetailScreenState
    extends ConsumerState<TicketDetailScreen> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final controller =
        ref.read(ticketDetailProvider(widget.ticketId).notifier);
    final ok = await controller.sendReply(_reply.text);
    if (ok && mounted) _reply.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(ticketDetailProvider(widget.ticketId));
    final controller =
        ref.read(ticketDetailProvider(widget.ticketId).notifier);

    return Scaffold(
      appBar: const DsTopBar('گفتگوی تیکت', showBack: true),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(child: DsRing(size: 28)),
        LoadStatus.error => DsEmptyState(
            icon: Icons.cloud_off_outlined,
            title: ui.message ?? 'خطای نامشخص',
            actionLabel: 'تلاش دوباره',
            onAction: controller.reload,
          ),
        LoadStatus.ready => _Conversation(
            ui: ui,
            replyController: _reply,
            onSend: _send,
          ),
      },
    );
  }
}

/// گفتگوی تیکت — سربرگ + حباب‌ها + کامپوزر پاسخ
final class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.ui,
    required this.replyController,
    required this.onSend,
  });

  final TicketDetailUi ui;
  final TextEditingController replyController;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final detail = ui.detail!;
    return Column(
      children: [
        _TicketHeader(detail: detail),
        Expanded(
          child: detail.messages.isEmpty
              ? const DsEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'هنوز پیامی رد و بدل نشده است',
                )
              : ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(Ds.s16),
                  itemCount: detail.messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Ds.s12),
                  // نمایش از قدیمی به جدید با reverse: آخرین لیست = قدیمی‌ترین
                  itemBuilder: (context, index) => _MessageBubble(
                    m: detail.messages[detail.messages.length - 1 - index],
                  ),
                ),
        ),
        if (ui.message != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Ds.s16,
              vertical: Ds.s4,
            ),
            child: Text(
              ui.message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12.5,
                color: ui.isError
                    ? (light ? Ds.error : Ds.rose)
                    : (light ? Ds.green : Ds.mint),
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Ds.s12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('composer-reply'),
                    controller: replyController,
                    maxLength: MessagesContract.replyBodyMax,
                    enabled: !ui.isClosed && !ui.busy,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: ui.isClosed
                          ? 'تیکت بسته است'
                          : 'پاسخ خود را بنویسید…',
                    ),
                  ),
                ),
                const SizedBox(width: Ds.s8),
                IconButton.filled(
                  onPressed: ui.isClosed || ui.busy ? null : onSend,
                  icon: ui.busy
                      ? const DsRing()
                      : const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// سربرگ تیکت نسل S — موضوع + قرص وضعیت + بخش/اولویت در DsKvRow
final class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.detail});

  final TicketDetail detail;

  DsPillTone get _tone => switch (detail.status) {
        'open' => DsPillTone.info,
        'review' => DsPillTone.warn,
        'answered' => DsPillTone.success,
        'closed' => DsPillTone.neutral,
        _ => DsPillTone.info,
      };

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return DsCard(
      margin: const EdgeInsets.fromLTRB(Ds.s16, Ds.s12, Ds.s16, Ds.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.subject,
                  style: DsText.headline.copyWith(
                    color: light ? Ds.ink : Ds.inkDark,
                  ),
                ),
              ),
              const SizedBox(width: Ds.s8),
              DsPill(detail.statusValue.labelFa, tone: _tone),
            ],
          ),
          const SizedBox(height: Ds.s4),
          DsKvRow('بخش', detail.dept.isEmpty ? '—' : detail.dept),
          DsKvRow(
            'اولویت',
            detail.priority.isEmpty ? '—' : detail.priority,
            divider: false,
          ),
        ],
      ),
    );
  }
}

/// حباب پیام تیکت — mine از سرور؛ برچسب نقش فقط روی حباب طرف مقابل.
/// DsBubble در RTL خودم را سمت چپ (tint آبی) و طرف مقابل را سطح سفید
/// می‌گذارد — عین قرارداد فارسی کد قدیم.
final class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.m});

  final TicketMessage m;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final created = JalaliCalendar.fromEpochSeconds(m.createdAt);
    return Column(
      crossAxisAlignment:
          m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!m.mine)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              MessagesContract.labelOfRole(m.role),
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: light ? Ds.primaryDeep : Ds.cyan,
              ),
            ),
          ),
        DsBubble(
          text: m.body,
          mine: m.mine,
          time: JalaliCalendar.formatNumeric(created),
        ),
      ],
    );
  }
}
