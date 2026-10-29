/// صفحه‌ی ثبت پرونده جدید — M2 (DOC-04 §۱۱ ردیف M2)
///
/// فرم سه‌فیلدی دقیقاً قرارداد POST /api/cases سرور: دسته از شش مقدار ثابت،
/// عنوان ۵..۱۲۰، توضیحات اختیاری ≤۵۰۰۰. اعتبارسنجی سمت کاربر آینه‌ی سرور
/// است و پیام‌های خطا (۴۲۹ سقف نرخ، ۴۰۱ تا حکم D-6) عیناً نمایش داده می‌شوند.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../design/tokens.dart';
import '../data/cases_contract.dart';

/// صفحه‌ی ثبت پرونده
class NewCaseScreen extends ConsumerStatefulWidget {
  const NewCaseScreen({super.key});

  @override
  ConsumerState<NewCaseScreen> createState() => _NewCaseScreenState();
}

final class _NewCaseScreenState extends ConsumerState<NewCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(createCaseControllerProvider.notifier);
    controller
      ..setTitle(_title.text)
      ..setDescription(_description.text);
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final id = await controller.submit();
    if (id != null && mounted) {
      // ثبت موفق → رفتن به جزئیات پرونده‌ی جدید
      context.go('/cases/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(createCaseControllerProvider);
    final controller = ref.read(createCaseControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('ثبت پرونده جدید')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DadgarTokens.s16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'دسته‌بندی پرونده',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DadgarTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: DadgarTokens.s8),
                Wrap(
                  spacing: DadgarTokens.s8,
                  runSpacing: DadgarTokens.s8,
                  children: [
                    for (final cat in CasesContract.cats)
                      ChoiceChip(
                        label: Text(cat),
                        selected: ui.category == cat,
                        onSelected: (_) => controller.setCategory(cat),
                        selectedColor:
                            DadgarTokens.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: ui.category == cat
                              ? DadgarTokens.primary
                              : DadgarTokens.textSecondary,
                          fontWeight: ui.category == cat
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        side: BorderSide(
                          color: ui.category == cat
                              ? DadgarTokens.primary
                              : DadgarTokens.textSecondary.withValues(
                                  alpha: 0.3,
                                ),
                        ),
                        showCheckmark: false,
                      ),
                  ],
                ),
                const SizedBox(height: DadgarTokens.s16),
                TextFormField(
                  controller: _title,
                  maxLength: CasesContract.titleMax,
                  onChanged: controller.setTitle,
                  style: const TextStyle(
                    fontFamily: DadgarTokens.fontFamily,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'عنوان پرونده',
                    hintText: 'مثلاً: اختلاف بر سر مبیع قرارداد خرید',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (v) => CasesContract.validateTitle(v ?? ''),
                ),
                const SizedBox(height: DadgarTokens.s8),
                TextFormField(
                  controller: _description,
                  maxLength: CasesContract.descriptionMax,
                  maxLines: 6,
                  onChanged: controller.setDescription,
                  style: const TextStyle(
                    fontFamily: DadgarTokens.fontFamily,
                    fontSize: 14,
                    height: 1.8,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'توضیحات (اختیاری)',
                    alignLabelWithHint: true,
                    hintText: 'شرح ماجرا، تاریخ‌ها و مدارک مرتبط',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: DadgarTokens.s16),
                if (ui.message != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(DadgarTokens.s12),
                    decoration: BoxDecoration(
                      color: ui.isError
                          ? DadgarTokens.error.withValues(alpha: 0.08)
                          : DadgarTokens.accent.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(DadgarTokens.radius),
                      border: Border.all(
                        color: ui.isError
                            ? DadgarTokens.error.withValues(alpha: 0.4)
                            : DadgarTokens.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      ui.message!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.8,
                        color: ui.isError
                            ? DadgarTokens.error
                            : DadgarTokens.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: DadgarTokens.s16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: ui.busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: DadgarTokens.primary,
                      padding: const EdgeInsets.symmetric(
                        vertical: DadgarTokens.s16,
                      ),
                    ),
                    child: ui.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DadgarTokens.onPrimary,
                            ),
                          )
                        : const Text(
                            'ثبت پرونده',
                            style: TextStyle(fontSize: 14),
                          ),
                  ),
                ),
                const SizedBox(height: DadgarTokens.s12),
                const Text(
                  'سقف سرور: ۵ پرونده در هر ساعت — پرونده‌ی ثبت‌شده با '
                  'وضعیت «در انتظار بررسی» آغاز می‌شود.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.8,
                    color: DadgarTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
