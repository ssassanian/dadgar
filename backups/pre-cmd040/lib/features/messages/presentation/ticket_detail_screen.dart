/// صفحه‌ی گفتگوی یک تیکت — M5 (DOC-04 §۱۱ ردیف M5)
///
/// آینه‌ی GET /api/tickets/:id سرور: پیام‌ها با حباب «من/طرف» بر پایه‌ی
/// `mine` سرور، پاسخ با POST replies — تیکت بسته با پیام عین سرور
/// غیرفعال می‌شود و وضعیت پس از هر پاسخ با بازخوانی تازه می‌شود.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/jalali.dart';
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
      appBar: AppBar(title: const Text('گفتگوی تیکت')),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        LoadStatus.error => _ErrorPane(
            message: ui.message ?? 'خطای نامشخص',
            onRetry: controller.reload,
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
    final detail = ui.detail!;
    return Column(
      children: [
        _Header(detail: detail),
        Expanded(
          child: detail.messages.isEmpty
              ? const Center(
                  child: Text(
                    'هنوز پیامی ردوبدل نشده است',
                    style: TextStyle(
                      fontSize: 13,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(DadgarTokens.s16),
                  itemCount: detail.messages.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: DadgarTokens.s8),
                  // نمایش از قدیمی به جدید با reverse: آخرین لیست = قدیمی‌ترین
                  itemBuilder: (context, index) =>
                      _Bubble(m: detail.messages[detail.messages.length - 1 - index]),
                ),
        ),
        if (ui.message != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DadgarTokens.s16,
              vertical: DadgarTokens.s4,
            ),
            child: Text(
              ui.message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: ui.isError ? DadgarTokens.error : DadgarTokens.accent,
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(DadgarTokens.s12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: replyController,
                    maxLength: MessagesContract.replyBodyMax,
                    enabled: !ui.isClosed && !ui.busy,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: ui.isClosed
                          ? 'تیکت بسته است'
                          : 'پاسخ خود را بنویسید…',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: DadgarTokens.s8),
                IconButton.filled(
                  onPressed: ui.isClosed || ui.busy ? null : onSend,
                  icon: ui.busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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

/// سربرگ تیکت — موضوع + بخش/اولویت + چیپ وضعیت
final class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final TicketDetail detail;

  Color get _statusColor => switch (detail.status) {
        'closed' => DadgarTokens.accent,
        'answered' => DadgarTokens.primary,
        'open' => DadgarTokens.textSecondary,
        _ => DadgarTokens.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DadgarTokens.s12),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        border: Border(
          bottom: BorderSide(
            color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.subject,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DadgarTokens.textPrimary,
                  ),
                ),
              ),
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
                  detail.statusValue.labelFa,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DadgarTokens.s4),
          Text(
            'بخش: ${detail.dept.isEmpty ? '—' : detail.dept}'
            ' • اولویت: ${detail.priority.isEmpty ? '—' : detail.priority}',
            style: const TextStyle(
              fontSize: 12,
              color: DadgarTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// حباب پیام — mine از سرور؛ نقش فرستنده روی حباب طرف مقابل
final class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});

  final TicketMessage m;

  @override
  Widget build(BuildContext context) {
    final created = JalaliCalendar.fromEpochSeconds(m.createdAt);
    return Align(
      alignment: m.mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(DadgarTokens.s12),
        decoration: BoxDecoration(
          color: m.mine ? DadgarTokens.primary : DadgarTokens.surface,
          borderRadius: BorderRadius.circular(DadgarTokens.radius),
          border: m.mine
              ? null
              : Border.all(
                  color: DadgarTokens.textSecondary.withValues(alpha: 0.25),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!m.mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  MessagesContract.labelOfRole(m.role),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: DadgarTokens.primary,
                  ),
                ),
              ),
            Text(
              m.body,
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                color: m.mine ? DadgarTokens.onPrimary : DadgarTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              JalaliCalendar.formatNumeric(created),
              style: TextStyle(
                fontSize: 10,
                color: m.mine
                    ? DadgarTokens.onPrimary.withValues(alpha: 0.7)
                    : DadgarTokens.textSecondary,
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
