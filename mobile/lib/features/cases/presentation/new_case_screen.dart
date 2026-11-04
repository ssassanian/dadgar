/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// فرم ثبت پرونده جدید با هویت بومی‌موبایلی «دادگر S»: سربرگ DsTopBar،
/// چیپ‌های دسته‌بندی tint برند با هدف لمس ۴۸dp، فیلدهای DsTextField و
/// جعبه‌ی پیام tint رنگی. هیچ ارثی از نسل قبل (D-3) نیست.
///
/// فرم سه‌فیلدی دقیقاً قرارداد POST /api/cases سرور: دسته از شش مقدار
/// ثابت، عنوان ۵..۱۲۰، توضیحات اختیاری ≤۵۰۰۰. اعتبارسنجی سمت کاربر
/// آینه‌ی سرور است (CasesContract.validateTitle/validateDescription) و
/// پیام‌های خطا (۴۲۹ سقف نرخ، ۴۰۱ تا حکم D-6) عیناً نمایش داده می‌شوند.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../data/cases_contract.dart';

/// صفحه‌ی ثبت پرونده
final class NewCaseScreen extends ConsumerStatefulWidget {
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
    final light = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: const DsTopBar('ثبت پرونده جدید', showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Ds.s16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'دسته‌بندی پرونده',
                    style: TextStyle(
                      fontFamily: Ds.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: light ? Ds.ink : Ds.inkDark,
                    ),
                  ),
                  const SizedBox(height: Ds.s8),
                  // شش دسته‌ی ثابت سرور — ترتیب هم‌سان `CATS`
                  Wrap(
                    spacing: Ds.s8,
                    runSpacing: Ds.s8,
                    children: [
                      for (final cat in CasesContract.cats)
                        _CatChip(
                          label: cat,
                          selected: ui.category == cat,
                          onSelected: () => controller.setCategory(cat),
                        ),
                    ],
                  ),
                  const SizedBox(height: Ds.s16),
                  DsTextField(
                    controller: _title,
                    label: 'عنوان پرونده',
                    hint: 'مثلاً: اختلاف بر سر مبیع قرارداد خرید',
                    textInputAction: TextInputAction.next,
                    // پیام قرارداد با رقم فارسی — رفتار قدیم حفظ شود
                    validator: (v) {
                      final e = CasesContract.validateTitle(v ?? '');
                      return e == null ? null : JalaliCalendar.toPersianDigits(e);
                    },
                  ),
                  const SizedBox(height: Ds.s8),
                  DsTextField(
                    controller: _description,
                    label: 'توضیحات (اختیاری)',
                    hint: 'شرح ماجرا، تاریخ‌ها و مدارک مرتبط',
                    maxLines: 6,
                  ),
                  const SizedBox(height: Ds.s16),
                  if (ui.message != null) ...[
                    _MessageBox(text: ui.message!, danger: ui.isError),
                    const SizedBox(height: Ds.s16),
                  ],
                  _SubmitButton(busy: ui.busy, onPressed: _submit),
                  const SizedBox(height: Ds.s12),
                  Text(
                    'سقف سرور: ۵ پرونده در هر ساعت — پرونده‌ی ثبت‌شده با '
                    'وضعیت «در انتظار بررسی» آغاز می‌شود.',
                    style: TextStyle(
                      fontFamily: Ds.fontFamily,
                      fontSize: 12,
                      height: 1.8,
                      color: light ? Ds.inkFaint : Ds.inkFaintDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// چیپ دسته‌بندی — قرص انتخاب‌شدنی با tint برند؛ هدف لمس ≥۴۸ (ویجت
/// خصوصی: کیت قرص انتخاب‌شدنی ندارد)
final class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(Ds.radiusChip),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: Ds.s16,
            vertical: Ds.s12,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? (light ? Ds.primary : Ds.primaryDeep)
                : (light ? Ds.wash : Ds.washDark),
            borderRadius: BorderRadius.circular(Ds.radiusChip),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (light ? Ds.line : Ds.lineDark),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? Ds.onPrimary
                  : (light ? Ds.inkSoft : Ds.inkSoftDark),
            ),
          ),
        ),
      ),
    );
  }
}

/// جعبه‌ی پیام — موفقیت سبز / خطا رز، هر دو tint لنگرهای پالت
final class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, required this.danger});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final fg = danger
        ? (light ? Ds.error : Ds.rose)
        : (light ? Ds.green : Ds.mint);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Ds.s12),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Ds.radiusField),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: Ds.fontFamily,
          fontSize: 12.5,
          height: 1.8,
          color: fg,
        ),
      ),
    );
  }
}

/// دکمه‌ی ثبت — هنگام busy حلقه‌ی بارگذاری روی دکمه‌ی غیرفعال (همان
/// رفتار نسل قبل؛ رنگ حلقه onPrimary برند)
final class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: null,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Ds.onPrimary,
            ),
          ),
        ),
      );
    }
    return DsButton(
      'ثبت پرونده',
      onPressed: onPressed,
      expand: true,
    );
  }
}
