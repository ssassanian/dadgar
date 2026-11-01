/// صفحه‌ی چت یک پرونده — M5 (DOC-04 §۱۱ ردیف M5)
///
/// CMD-046 (فاز ۳): بازطراحی D-3 عین طرح تاییدشده‌ی CMD-041 (`bChat` در
/// `design-preview/prototype.html`): AppBar کاغذی با عنوان واقعی پرونده،
/// حباب‌های ۱۴px با دم (mine = ته‌رنگ data-soft، them = سطح سفید با لبه)
/// و کامپوزر ۴۴px با دکمه‌ی ارسال نزدیک‌سیاه.
///
/// آینه‌ی GET/POST /api/messages سرور: پیام‌ها با حباب mine، ارسال با
/// اعتبارسنجی ۱..۲۰۰۰ و تازه‌سازی پس از موفقیت. خطای «گفتگو فعال نیست»
/// و سقف نرخ عین سرور نمایش داده می‌شود.
///
/// F6 (باز — حکم مدیر): نقد بازرسی CMD-042 به سمت حباب در *پروتوتایپ* بود
/// (خودم=راست، خلاف قرارداد فارسی). کد معیار است: خودم=چپ — دست نمی‌خورد.
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
    final caseTitle = ui.status == LoadStatus.ready
        ? ui.envelope!.caseTitle
        : 'گفتگوی پرونده';

    return Scaffold(
      backgroundColor: DadgarTokens.background,
      appBar: AppBar(
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
            Text(
              caseTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: DadgarTokens.textPrimary,
              ),
            ),
            const Text(
              'گفتگو',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: DadgarTokens.textFaint,
              ),
            ),
          ],
        ),
      ),
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
        Expanded(
          child: env.rows.isEmpty
              ? const Center(
                  child: Text(
                    'گفتگویی ثبت نشده — اولین پیام را بفرستید.',
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
        // کامپوزر — کلاس `.composer` طرح: ورودی ۴۴px با لبه‌ی control
        // و دکمه‌ی ارسال ۴۴px نزدیک‌سیاه
        SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: DadgarTokens.surface,
              border: Border(
                top: BorderSide(color: DadgarTokens.cardBorder),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    maxLength: MessagesContract.chatBodyMax,
                    enabled: !ui.busy,
                    style: const TextStyle(
                      fontSize: 14,
                      color: DadgarTokens.textPrimary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'پیام…',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: DadgarTokens.textFaint,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: DadgarTokens.surface,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: DadgarTokens.control,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: DadgarTokens.primary,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: DadgarTokens.control,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DadgarTokens.s8),
                // دکمه‌ی ارسال — `.composer .send` طرح (۴۴px نزدیک‌سیاه)
                Material(
                  color: ui.busy
                      ? DadgarTokens.control
                      : DadgarTokens.textPrimary,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: ui.busy ? null : onSend,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.send_outlined,
                        size: 18,
                        color: DadgarTokens.surface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// حباب پیام چت — ترجمه‌ی `.msg.me`/`.msg.them` طرح: mine = ته‌رنگ
/// data-soft با دم، them = سطح سفید با لبه‌ی کارت. سمت حباب‌ها طبق
/// قرارداد فارسی (خودم=چپ) — F6 باز برای پروتوتایپ، کد دست نمی‌خورد.
final class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});

  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final created = JalaliCalendar.fromEpochSeconds(m.createdAt);
    return Align(
      alignment: m.mine ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: m.mine ? DadgarTokens.pillDataBg : DadgarTokens.surface,
            border: m.mine
                ? null
                : Border.all(color: DadgarTokens.cardBorder),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              // دم حباب — رو به سمت گوینده
              bottomLeft: Radius.circular(m.mine ? 4 : 14),
              bottomRight: Radius.circular(m.mine ? 14 : 4),
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
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.7,
                  color: DadgarTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                JalaliCalendar.formatNumeric(created),
                style: const TextStyle(
                  fontSize: 11,
                  color: DadgarTokens.textFaint,
                ),
              ),
            ],
          ),
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
