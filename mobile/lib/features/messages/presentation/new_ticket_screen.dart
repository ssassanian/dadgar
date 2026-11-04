/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی ثبت تیکت جدید — M5 (DOC-04 §۱۱ ردیف M5).
///
/// فرم چهارتایی آینه‌ی POST /api/tickets سرور: موضوع (۳..۱۲۰)، بخش
/// (پنج‌گانه)، اولویت (سه‌گانه)، متن (۳..۳۰۰۰) — اعتبارسنجی سمت کاربر با
/// همان پیام‌های آینه‌ای (کنترلر)، سقف نویسه‌ی فیلدها و ۴۲۹ سقف نرخ با
/// پیام عین سرور. نسل S: فیلدهای درون DsCard، انتخاب بخش/اولویت با شیت
/// پایین (showDsSheet) به‌جای Dropdown قدیمی و ثبت با DsButton.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../application/tickets_controller.dart';
import '../data/messages_contract.dart';

/// صفحه‌ی تیکت جدید
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

final class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _subject = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(newTicketControllerProvider.notifier);
    controller.setSubject(_subject.text);
    controller.setBody(_body.text);
    final id = await controller.submit();
    if (!mounted || id == null) return;
    if (mounted) context.go('/tickets/$id');
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(newTicketControllerProvider);
    final controller = ref.read(newTicketControllerProvider.notifier);
    final light = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: const DsTopBar('تیکت جدید', showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Ds.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BoundedField(
                    key: const ValueKey('field-subject'),
                    controller: _subject,
                    label: 'موضوع',
                    hint: 'خلاصه‌ی موضوع در یک خط',
                    maxLength: MessagesContract.subjectMax,
                    onChanged: controller.setSubject,
                  ),
                  const SizedBox(height: Ds.s16),
                  _SheetPicker(
                    key: const ValueKey('picker-dept'),
                    label: 'بخش',
                    value: ui.dept,
                    options: MessagesContract.tkDepts,
                    onSelected: controller.setDept,
                  ),
                  const SizedBox(height: Ds.s16),
                  _SheetPicker(
                    key: const ValueKey('picker-priority'),
                    label: 'اولویت',
                    value: ui.priority,
                    options: MessagesContract.tkPris,
                    onSelected: controller.setPriority,
                  ),
                  const SizedBox(height: Ds.s16),
                  _BoundedField(
                    key: const ValueKey('field-body'),
                    controller: _body,
                    label: 'متن تیکت',
                    maxLength: MessagesContract.ticketBodyMax,
                    minLines: 4,
                    maxLines: 8,
                    onChanged: controller.setBody,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Ds.s16),
            if (ui.message != null) ...[
              Text(
                ui.message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 13,
                  height: 1.8,
                  color: ui.isError
                      ? (light ? Ds.error : Ds.rose)
                      : (light ? Ds.green : Ds.mint),
                ),
              ),
              const SizedBox(height: Ds.s12),
            ],
            DsButton(
              'ثبت تیکت',
              icon: Icons.send_outlined,
              expand: true,
              onPressed: ui.busy ? null : _submit,
            ),
            if (ui.busy) ...[
              const SizedBox(height: Ds.s12),
              const Center(child: DsRing()),
            ],
          ],
        ),
      ),
    );
  }
}

/// فیلد متنی با سقف نویسه — هم‌زبانِ DsTextField کیت (برچسب بالای فیلد)؛
/// چون DsTextField maxLength ندارد و سقف ۱۲۰/۳۰۰۰ سرور باید عیناً حفظ
/// شود، این ویجت خصوصی در همین صفحه ساخته شد.
final class _BoundedField extends StatelessWidget {
  const _BoundedField({
    super.key,
    required this.controller,
    required this.label,
    required this.maxLength,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final String? hint;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: Ds.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: light ? Ds.ink : Ds.inkDark,
          ),
        ),
        const SizedBox(height: Ds.s8),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            fontFamily: Ds.fontFamily,
            fontSize: 15,
            color: light ? Ds.ink : Ds.inkDark,
          ),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

/// انتخابگر شیت‌باز نسل S — جای Dropdown قدیمی؛ گزینه‌ها در showDsSheet
/// با DsTile و نشانِ انتخاب فعلی. ظاهر فیلد بسته، هم‌شکل فیلدهای کیت است.
final class _SheetPicker extends StatelessWidget {
  const _SheetPicker({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  Future<void> _open(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return showDsSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Ds.s24, 0, Ds.s24, Ds.s8),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: light ? Ds.ink : Ds.inkDark,
                ),
              ),
            ),
            // ستون ساده‌ی shrink-wrap — گزینه‌ها (۵ و ۳ تایی) همیشه در
            // شیت جا می‌شوند؛ Flexible/ListView باعث بریده‌شدن گزینه‌ی
            // آخر در لبه‌ی پایین صفحه می‌شد (کشف تست CMD-051)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in options)
                  DsTile(
                    title: option,
                    trailing: option == value
                        ? Icon(
                            Icons.check_circle,
                            size: 22,
                            color: light ? Ds.primary : Ds.cyan,
                          )
                        : null,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onSelected(option);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: Ds.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: light ? Ds.ink : Ds.inkDark,
          ),
        ),
        const SizedBox(height: Ds.s8),
        Material(
          color: light ? Ds.surface : Ds.surfaceDark,
          borderRadius: BorderRadius.circular(Ds.radiusField),
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(Ds.radiusField),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(
                horizontal: Ds.s16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Ds.radiusField),
                border: Border.all(color: light ? Ds.line : Ds.lineDark),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value.isEmpty ? 'انتخاب کنید' : value,
                      style: TextStyle(
                        fontFamily: Ds.fontFamily,
                        fontSize: 15,
                        color: value.isEmpty
                            ? (light ? Ds.inkFaint : Ds.inkFaintDark)
                            : (light ? Ds.ink : Ds.inkDark),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: light ? Ds.inkSoft : Ds.inkSoftDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
