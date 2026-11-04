/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی بارگذاری سند — M5 (DOC-04 §۱۱ ردیف M5) با هویت موبایل‌بومی
/// «دادگر S» (اجرای حکم CMD-050): سربرگ DsTopBar، سربرگ‌های بخش
/// DsSectionHeader و کارت‌های گرد نسل S برای مقصد/منبع/پیش‌نمایش.
///
/// منطق آپلود عین نسل قبل — جریان آینه‌ی POST /api/cases/:id/documents
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
import '../../../design/ds_kit.dart';
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
    final light = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: const DsTopBar('بارگذاری سند', showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Ds.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── مقصد — انتخاب پرونده (وقتی ازپیش‌انتخاب نیست) ──
            const DsSectionHeader('پرونده‌ی مقصد'),
            DsCard(
              child: widget.caseId == null
                  ? casesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(Ds.s12),
                        child: Center(child: DsRing()),
                      ),
                      error: (e, _) => Text(
                        'دریافت فهرست پرونده‌ها ناموفق بود — دوباره تلاش کنید',
                        style: TextStyle(
                          fontFamily: Ds.fontFamily,
                          fontSize: 13,
                          height: 1.6,
                          color: light ? Ds.error : Ds.rose,
                        ),
                      ),
                      data: (rows) {
                        if (rows.isEmpty) {
                          return const Text(
                            'برای بارگذاری سند، ابتدا یک پرونده ثبت کنید؛ '
                            'سند به پرونده گره می‌خورد.',
                            style: TextStyle(
                              fontFamily: Ds.fontFamily,
                              fontSize: 13,
                              height: 1.8,
                              color: Ds.inkSoft,
                            ),
                          );
                        }
                        return DropdownButtonFormField<int>(
                          initialValue: _caseId,
                          decoration: const InputDecoration(
                            hintText: 'انتخاب پرونده',
                          ),
                          items: rows
                              .map(
                                (r) => DropdownMenuItem<int>(
                                  value: r.id,
                                  child: Text(
                                    'پرونده ${DocumentsContract.toPersianDigits(r.id)} — '
                                    '${r.title}',
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
                        fontFamily: Ds.fontFamily,
                        fontSize: 13,
                        height: 1.6,
                        color: Ds.inkSoft,
                      ),
                    ),
            ),
            const SizedBox(height: Ds.s16),
            // ── منبع — دوربین/گالری (دکمه‌های outline نیم‌عرض) ──
            const DsSectionHeader('منبع تصویر'),
            DsCard(
              child: Row(
                children: [
                  Expanded(
                    child: DsButton(
                      'دوربین',
                      onPressed: () => _pick(ImageSource.camera),
                      tone: DsButtonTone.outline,
                      icon: Icons.photo_camera_outlined,
                    ),
                  ),
                  const SizedBox(width: Ds.s8),
                  Expanded(
                    child: DsButton(
                      'گالری',
                      onPressed: () => _pick(ImageSource.gallery),
                      tone: DsButtonTone.outline,
                      icon: Icons.photo_library_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Ds.s16),
            // ── پیش‌نمایش ──
            const DsSectionHeader('پیش‌نمایش'),
            DsCard(
              child: _picked != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _picked!.name,
                          style: TextStyle(
                            fontFamily: Ds.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                            color: light ? Ds.ink : Ds.inkDark,
                          ),
                        ),
                        const SizedBox(height: Ds.s4),
                        Text(
                          '${DocumentsContract.formatSize(_picked!.bytes.length)}'
                          ' • سقف: ۴ مگابایت',
                          style: TextStyle(
                            fontFamily: Ds.fontFamily,
                            fontSize: 12,
                            height: 1.6,
                            color: light ? Ds.inkFaint : Ds.inkFaintDark,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'تصویر مدرک را با دوربین بگیرید یا از گالری انتخاب کنید.',
                      style: TextStyle(
                        fontFamily: Ds.fontFamily,
                        fontSize: 12.5,
                        height: 1.8,
                        color: Ds.inkSoft,
                      ),
                    ),
            ),
            const SizedBox(height: Ds.s16),
            if (ui.message != null && ui.isError) ...[
              Text(
                ui.message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 13,
                  height: 1.8,
                  color: light ? Ds.error : Ds.rose,
                ),
              ),
              const SizedBox(height: Ds.s12),
            ],
            DsButton(
              ui.busy ? 'در حال بارگذاری…' : 'بارگذاری',
              onPressed:
                  (ui.busy || _picked == null || _caseId == null)
                      ? null
                      : _submit,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}
