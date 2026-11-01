/// صفحه‌ی بارگذاری سند — M5 (DOC-04 §۱۱ ردیف M5)
///
/// CMD-046 (فاز ۳): آراستگی D-3 (AppBar کاغذی + پنل‌ها/دکمه‌های kit) —
/// منطق آپلود دست‌نخورده: جریان آینه‌ی POST /api/cases/:id/documents
/// سرور: انتخاب پرونده‌ی خود (از M2) → انتخاب منبع (دوربین/گالری) →
/// پیش‌نمایش نام/اندازه → ارسال با سقف ۴ مگابایت. از صفحه‌ی جزئیات
/// پرونده با پرونده‌ی ازپیش‌انتخاب‌شده هم باز می‌شود (قفل‌شده).
///
/// انتخابگر فایل (image_picker) به‌صورت تزریق‌شدنی (`docPickerProvider`)
/// جداست تا تست‌ها بدون پلتفرم کار کنند (DOC-04 §۹).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../design/d3_kit.dart';
import '../../../design/tokens.dart';
import '../../cases/domain/case_models.dart';
import '../application/documents_controller.dart';
import '../data/documents_contract.dart';
import '../domain/document_models.dart';
import 'documents_picker.dart';

/// پرونده‌های خود کاربر برای dropdown بارگذاری — صفحه‌ی نخست M2
final uploadCasesProvider = FutureProvider<List<CaseSummary>>(
  (ref) async {
    final page = await ref.watch(casesRepositoryProvider).fetchPage(page: 1);
    return page.rows;
  },
);

/// صفحه‌ی بارگذاری سند
class UploadDocScreen extends ConsumerStatefulWidget {
  const UploadDocScreen({super.key, this.caseId});

  /// پرونده‌ی ازپیش‌انتخاب — از مسیر /cases/:id/upload
  final int? caseId;

  @override
  ConsumerState<UploadDocScreen> createState() => _UploadDocScreenState();
}

final class _UploadDocScreenState extends ConsumerState<UploadDocScreen> {
  int? _caseId;
  PickedDoc? _picked;

  @override
  void initState() {
    super.initState();
    _caseId = widget.caseId;
  }

  Future<void> _pick(ImageSource source) async {
    final picker = ref.read(docPickerProvider);
    try {
      final doc = await picker(source);
      if (doc == null) return;
      setState(() => _picked = doc);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('دسترسی به دوربین/گالری ممکن نشد'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    final picked = _picked;
    final caseId = _caseId;
    if (picked == null || caseId == null) return;
    final controller = ref.read(documentsControllerProvider.notifier);
    final ok = await controller.upload(picked, caseId: caseId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سند بارگذاری شد'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(documentsControllerProvider);
    final casesAsync = ref.watch(uploadCasesProvider);

    return Scaffold(
      backgroundColor: DadgarTokens.background,
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: DadgarTokens.background,
        foregroundColor: DadgarTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'بارگذاری سند',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: DadgarTokens.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DadgarTokens.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── پنل مقصد — انتخاب پرونده (وقتی ازپیش‌انتخاب نیست) ──
            DadgarPanel(
              head: 'پرونده‌ی مقصد',
              child: widget.caseId == null
                  ? casesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(DadgarTokens.s12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => const Text(
                        'دریافت فهرست پرونده‌ها ناموفق بود — دوباره تلاش کنید',
                        style: TextStyle(
                          fontSize: 13,
                          color: DadgarTokens.error,
                        ),
                      ),
                      data: (rows) {
                        if (rows.isEmpty) {
                          return const Text(
                            'برای بارگذاری سند، ابتدا یک پرونده ثبت کنید؛ '
                            'سند به پرونده گره می‌خورد.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.8,
                              color: DadgarTokens.textSecondary,
                            ),
                          );
                        }
                        return DropdownButtonFormField<int>(
                          initialValue: _caseId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: rows
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r.id,
                                  child: Text(
                                    'پرونده ${JalaliDigits.fa(r.id)} — ${r.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _caseId = v),
                        );
                      },
                    )
                  : const Text(
                      'سند به پرونده‌ی انتخاب‌شده گره می‌خورد.',
                      style: TextStyle(
                        fontSize: 13,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(height: DadgarTokens.s12),
            // ── پنل منبع — دوربین/گالری (دکمه‌های شبح نیم‌عرض) ──
            DadgarPanel(
              head: 'منبع تصویر',
              child: Row(
                children: [
                  Expanded(
                    child: DadgarGhostButton(
                      'دوربین',
                      onPressed: () => _pick(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: DadgarTokens.s8),
                  Expanded(
                    child: DadgarGhostButton(
                      'گالری',
                      onPressed: () => _pick(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DadgarTokens.s12),
            // ── پنل پیش‌نمایش ──
            DadgarPanel(
              head: 'پیش‌نمایش',
              child: _picked != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _picked!.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: DadgarTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: DadgarTokens.s4),
                        Text(
                          '${DocumentsContract.formatSize(_picked!.bytes.length)}'
                          ' • سقف: ۴ مگابایت',
                          style: const TextStyle(
                            fontSize: 12,
                            color: DadgarTokens.textSecondary,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'تصویر مدرک را با دوربین بگیرید یا از گالری انتخاب کنید.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.8,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(height: DadgarTokens.s16),
            if (ui.message != null && ui.isError) ...[
              Text(
                ui.message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.8,
                  color: DadgarTokens.error,
                ),
              ),
              const SizedBox(height: DadgarTokens.s12),
            ],
            DadgarPrimaryButton(
              ui.busy ? 'در حال بارگذاری…' : 'بارگذاری',
              onPressed:
                  (ui.busy || _picked == null || _caseId == null)
                      ? null
                      : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// ارقام فارسی — پل کوچک به تقویم مشترک
class JalaliDigits {
  static String fa(Object v) => DocumentsContract.toPersianDigits(v);
}
