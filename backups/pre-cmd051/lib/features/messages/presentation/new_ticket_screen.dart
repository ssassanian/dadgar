/// صفحه‌ی ثبت تیکت جدید — M5 (DOC-04 §۱۱ ردیف M5)
///
/// فرم چهارتایی آینه‌ی POST /api/tickets سرور: موضوع (۳..۱۲۰)، بخش
/// (پنج‌گانه)، اولویت (سه‌گانه)، متن (۳..۳۰۰۰) — اعتبارسنجی سمت کاربر
/// با همان پیام‌های آینه‌ای، و ۴۲۹ سقف نرخ با پیام عین سرور.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _formKey = GlobalKey<FormState>();
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

    return Scaffold(
      appBar: AppBar(title: const Text('تیکت جدید')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DadgarTokens.s16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subject,
                maxLength: MessagesContract.subjectMax,
                decoration: const InputDecoration(
                  labelText: 'موضوع',
                  hintText: 'خلاصه‌ی موضوع در یک خط',
                  border: OutlineInputBorder(),
                ),
                onChanged: controller.setSubject,
              ),
              const SizedBox(height: DadgarTokens.s12),
              DropdownButtonFormField<String>(
                initialValue: ui.dept.isEmpty ? null : ui.dept,
                decoration: const InputDecoration(
                  labelText: 'بخش',
                  border: OutlineInputBorder(),
                ),
                items: MessagesContract.tkDepts
                    .map(
                      (d) => DropdownMenuItem(value: d, child: Text(d)),
                    )
                    .toList(),
                onChanged: (v) => controller.setDept(v ?? ''),
              ),
              const SizedBox(height: DadgarTokens.s12),
              DropdownButtonFormField<String>(
                initialValue: ui.priority.isEmpty ? null : ui.priority,
                decoration: const InputDecoration(
                  labelText: 'اولویت',
                  border: OutlineInputBorder(),
                ),
                items: MessagesContract.tkPris
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p)),
                    )
                    .toList(),
                onChanged: (v) => controller.setPriority(v ?? ''),
              ),
              const SizedBox(height: DadgarTokens.s12),
              TextFormField(
                controller: _body,
                maxLength: MessagesContract.ticketBodyMax,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'متن تیکت',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: controller.setBody,
              ),
              const SizedBox(height: DadgarTokens.s16),
              if (ui.message != null) ...[
                Text(
                  ui.message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.8,
                    color: ui.isError
                        ? DadgarTokens.error
                        : DadgarTokens.accent,
                  ),
                ),
                const SizedBox(height: DadgarTokens.s12),
              ],
              FilledButton.icon(
                onPressed: ui.busy ? null : _submit,
                icon: ui.busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
                label: const Text('ثبت تیکت'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
