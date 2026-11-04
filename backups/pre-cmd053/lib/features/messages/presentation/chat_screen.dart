/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی چت یک پرونده — M5 (DOC-04 §۱۱ ردیف M5).
///
/// آینه‌ی GET/POST /api/messages سرور: پیام‌ها با DsBubble بر پایه‌ی `mine`
/// سرور (خودم = tint آبی سمت چپ در RTL — عین قرارداد فارسی کد قدیم)،
/// ارسال با اعتبارسنجی ۱..۲۰۰۰ و تازه‌سازی پس از موفقیت. خطای «گفتگو فعال
/// نیست» و سقف نرخ عین سرور نمایش داده می‌شود.
///
/// F6 (باز — حکم مدیر): نقد بازرسی CMD-042 به سمت حباب در *پروتوتایپ* بود
/// (خودم=راست، خلاف قرارداد فارسی). کد معیار است: خودم=چپ — دست نمی‌خورد.
/// DsBubble همین قرارداد را در RTL پیاده می‌کند.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
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
    final caseTitle = ui.status == LoadStatus.ready
        ? ui.envelope!.caseTitle
        : 'گفتگوی پرونده';

    return Scaffold(
      appBar: DsTopBar(
        _oneLine(caseTitle),
        subtitle: 'گفتگو',
        showBack: true,
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(child: DsRing(size: 28)),
        LoadStatus.error => DsEmptyState(
            icon: Icons.cloud_off_outlined,
            title: ui.message ?? 'خطای نامشخص',
            actionLabel: 'تلاش دوباره',
            onAction: controller.reload,
          ),
        LoadStatus.ready => _Thread(ui: ui, input: _input, onSend: _send),
      },
    );
  }
}

/// برش یک‌خطی عنوان سربرگ — معادل maxLines:1 + ellipsis عنوان قدیم
/// (DsTopBar سطر واحد را خودش برش نمی‌زند؛ عنوان پرونده از کاربر می‌آید)
String _oneLine(String title) =>
    title.length <= 30 ? title : '${title.substring(0, 30)}…';

/// رشته‌ی چت نسل S — حباب‌ها + پیام وضعیت + کامپوزر
final class _Thread extends StatelessWidget {
  const _Thread({
    required this.ui,
    required this.input,
    required this.onSend,
  });

  final ChatUi ui;
  final TextEditingController input;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final env = ui.envelope!;
    return Column(
      children: [
        Expanded(
          child: env.rows.isEmpty
              ? const DsEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'گفتگویی ثبت نشده — اولین پیام را بفرستید.',
                )
              : ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(Ds.s16),
                  itemCount: env.rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Ds.s12),
                  // نمایش از قدیمی به جدید با reverse: آخرین لیست = قدیمی‌ترین
                  itemBuilder: (context, index) =>
                      _MessageBubble(m: env.rows[env.rows.length - 1 - index]),
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
        // کامپوزر نسل S — نوار سطح با خط بالایی + دکمه‌ی ارسال پرِ آبی
        SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: light ? Ds.line : Ds.lineDark),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(Ds.s12, Ds.s8, Ds.s12, Ds.s12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('composer-chat'),
                    controller: input,
                    maxLength: MessagesContract.chatBodyMax,
                    enabled: !ui.busy,
                    decoration: const InputDecoration(
                      hintText: 'پیام…',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: Ds.s8),
                IconButton.filled(
                  onPressed: ui.busy ? null : onSend,
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

/// حباب پیام چت نسل S — mine از سرور؛ برچسب نقش فقط روی حباب طرف مقابل
final class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.m});

  final ChatMessage m;

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
