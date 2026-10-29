/// صفحه‌ی چت یک پرونده — M5 (DOC-04 §۱۱ ردیف M5)
///
/// آینه‌ی GET/POST /api/messages سرور: پیام‌ها با حباب mine، ارسال با
/// اعتبارسنجی ۱..۲۰۰۰ و تازه‌سازی پس از موفقیت. خطای «گفتگو فعال نیست»
/// و سقف نرخ عین سرور نمایش داده می‌شود.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/jalali.dart';
import '../../../design/tokens.dart';
import '../application/chat_controller.dart';
import '../application/tickets_controller.dart' show LoadStatus;
import '../data/messages_contract.dart';
import '../domain/chat_models.dart';

/// صفحه‌ی چت پرونده
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.caseId});

  final int caseId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

final class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final controller = ref.read(chatProvider(widget.caseId).notifier);
    final ok = await controller.send(_input.text);
    if (ok && mounted) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(chatProvider(widget.caseId));
    final controller = ref.read(chatProvider(widget.caseId).notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('گفتگوی پرونده')),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        LoadStatus.error => _ErrorPane(
            message: ui.message ?? 'خطای نامشخص',
            onRetry: controller.reload,
          ),
        LoadStatus.ready => _Thread(ui: ui, input: _input, onSend: _send),
      },
    );
  }
}

final class _Thread extends StatelessWidget {
  const _Thread({required this.ui, required this.input, required this.onSend});

  final ChatUi ui;
  final TextEditingController input;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final env = ui.envelope!;
    return Column(
      children: [
        // سربرگ پرونده — از سربرگ سرور (case.title/status)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(DadgarTokens.s12),
          color: DadgarTokens.surface,
          child: Text(
            env.caseTitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DadgarTokens.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: env.rows.isEmpty
              ? const Center(
                  child: Text(
                    'اولین پیام را بنویسید',
                    style: TextStyle(
                      fontSize: 13,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(DadgarTokens.s16),
                  itemCount: env.rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: DadgarTokens.s8),
                  itemBuilder: (context, index) =>
                      _Bubble(m: env.rows[env.rows.length - 1 - index]),
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
                    controller: input,
                    maxLength: MessagesContract.chatBodyMax,
                    enabled: !ui.busy,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: 'پیام خود را بنویسید…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: DadgarTokens.s8),
                IconButton.filled(
                  onPressed: ui.busy ? null : onSend,
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

/// حباب پیام چت — mine از سرور
final class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});

  final ChatMessage m;

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
                color: m.mine
                    ? DadgarTokens.onPrimary
                    : DadgarTokens.textPrimary,
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
