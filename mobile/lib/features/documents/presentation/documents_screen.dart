/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی «گاوصندوق اسناد» مشتری — M5 (DOC-04 §۱۱ ردیف M5) با هویت
/// موبایل‌بومی «دادگر S» (اجرای حکم CMD-050؛ تنها پالت برند وب مشترک):
/// سربرگ DsTopBar با شمارنده/زیرنویس محرمانگی، یادداشت صادقانه‌ی
/// رمزنگاری روی tint آبی، کارت‌های گرد سند با قرص دسترسی (استنتاج
/// سرور: اشتراک با وکیل / محرمانه — برچسب نمایشی «جدید» اتخاذ
/// نمی‌شود S-4) و شیت پایین نسل S برای دانلود/حذف. صفر عنصر بصری از
/// نسل قبل (کاغذ گرم/سرمه‌ای D-3) باقی نمانده است.
///
/// منطق M5 عین نسل قبل: دانلود بایت‌به‌بایت با ذخیره در پوشه‌ی اسناد
/// اپ (docSaver تزریق‌شده §۹)، حذف فقط اسناد خود با دیالوگ تأیید،
/// آپلود از دوربین/گالری (سقف ۴ مگابایت — DOC_MAX) و پیام‌های
/// SnackBar و حالت‌های صادقانه بدون تغییر. یادداشت رمزنگاری عین
/// حقیقت سرور است: name_enc/file با AES-256-GCM ذخیره می‌شود
/// (web.js §documents).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../application/documents_controller.dart';
import '../data/documents_contract.dart';
import '../domain/document_models.dart';

/// صفحه‌ی اسناد من
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(documentsControllerProvider);
    final controller = ref.read(documentsControllerProvider.notifier);

    return Scaffold(
      appBar: DsTopBar(
        'گاوصندوق اسناد',
        showBack: true,
        subtitle: ui.status == LoadStatus.ready
            ? '${JalaliCalendar.toPersianDigits(ui.rows.length)} سند'
            : 'محرمانه — فقط شما و وکیل پرونده',
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(child: DsRing(size: 28)),
        LoadStatus.error => _ErrorPane(
            message: ui.message ?? 'خطای نامشخص',
            onRetry: controller.reload,
          ),
        LoadStatus.ready when ui.rows.isEmpty => const _EmptyPane(),
        LoadStatus.ready => _DocsList(ui: ui),
      },
    );
  }
}

/// فهرست آماده — یادداشت صادقانه + کارت سندها + اقدام آپلود
final class _DocsList extends ConsumerWidget {
  const _DocsList({required this.ui});

  final DocumentsUi ui;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(documentsControllerProvider.notifier);
    return RefreshIndicator(
      onRefresh: controller.reload,
      child: Stack(
        children: [
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Ds.s16, Ds.s8, Ds.s16, Ds.s32),
            children: [
              // یادداشت صادقانه — عین حقیقت سرور (AES-256-GCM)
              const _HonestNote(),
              const SizedBox(height: Ds.s12),
              for (var i = 0; i < ui.rows.length; i++) ...[
                if (i > 0) const SizedBox(height: Ds.s8),
                _DocRow(row: ui.rows[i]),
              ],
              const SizedBox(height: Ds.s12),
              DsButton(
                'آپلود سند جدید',
                onPressed: () => context.push('/documents/upload'),
                tone: DsButtonTone.outline,
                expand: true,
              ),
            ],
          ),
          if (ui.message != null)
            Positioned(
              left: Ds.s16,
              right: Ds.s16,
              bottom: 16,
              child: _MessageBar(ui: ui),
            ),
        ],
      ),
    );
  }
}

/// یادداشت صادقانه‌ی رمزنگاری — قاب tint آبی با آیکون قفل (نسل S)
final class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Ds.s12, vertical: 10),
      decoration: BoxDecoration(
        color: light ? Ds.wash : Ds.washDark,
        borderRadius: BorderRadius.circular(Ds.radiusField),
        border: Border.all(color: light ? Ds.line : Ds.lineDark),
      ),
      child: Row(
        children: [
          Icon(
            Icons.enhanced_encryption_outlined,
            size: 18,
            color: light ? Ds.primaryDeep : Ds.cyan,
          ),
          const SizedBox(width: Ds.s8),
          Expanded(
            child: Text(
              'اسناد با رمزنگاری ذخیره می‌شوند و هر دانلود، '
              'بایت‌به‌بایت ثبت می‌شود.',
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12,
                height: 1.6,
                color: light ? Ds.inkSoft : Ds.inkSoftDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ردیف سند — کارت گرد نسل S: نام/پرونده/اندازه/تاریخ + قرص دسترسی؛
/// تپ → شیت عملیات (دانلود/حذف فقط اسناد خودی)
final class _DocRow extends ConsumerWidget {
  const _DocRow({required this.row});

  final DocSummary row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final light = Theme.of(context).brightness == Brightness.light;
    final created = JalaliCalendar.fromEpochSeconds(row.createdAt);
    return DsCard(
      onTap: () => _showActions(context, ref),
      padding: const EdgeInsets.all(Ds.s12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: light ? Ds.wash : Ds.washDark,
              borderRadius: BorderRadius.circular(Ds.radiusField),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 21,
              color: light ? Ds.primary : Ds.cyan,
            ),
          ),
          const SizedBox(width: Ds.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Ds.fontFamily,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: light ? Ds.ink : Ds.inkDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.caseTitle.isEmpty ? '—' : row.caseTitle}'
                  ' • ${DocumentsContract.formatSize(row.size)}'
                  ' • ${JalaliCalendar.formatNumeric(created)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Ds.fontFamily,
                    fontSize: 12,
                    height: 1.5,
                    color: light ? Ds.inkFaint : Ds.inkFaintDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Ds.s8),
          DsPill(
            row.shared
                ? DocumentsContract.sharedLabel
                : DocumentsContract.privateLabel,
            tone: row.shared ? DsPillTone.info : DsPillTone.neutral,
          ),
        ],
      ),
    );
  }

  /// شیت عملیات نسل S — دانلود (M5) و حذف فقط اسناد خود
  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final ui = ref.read(documentsControllerProvider);
    final controller = ref.read(documentsControllerProvider.notifier);
    final light = Theme.of(context).brightness == Brightness.light;
    await showDsSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Ds.s16, Ds.s8, Ds.s16, Ds.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                  color: light ? Ds.ink : Ds.inkDark,
                ),
              ),
              const SizedBox(height: Ds.s12),
              DsButton(
                'دانلود',
                tone: DsButtonTone.outline,
                icon: Icons.download_outlined,
                onPressed: ui.busy
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        final path = await controller.download(row);
                        if (path != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('سند در پوشه‌ی اسناد اپ ذخیره شد'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
              ),
              if (row.mine) ...[
                const SizedBox(height: Ds.s8),
                DsButton(
                  'حذف',
                  tone: DsButtonTone.danger,
                  icon: Icons.delete_outline,
                  onPressed: ui.busy
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          final ok = await _confirmDelete(context);
                          if (ok) await controller.remove(row);
                        },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final light = Theme.of(context).brightness == Brightness.light;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف سند'),
        content: const Text('این سند برای همیشه حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  light ? Ds.error : Ds.rose,
              foregroundColor: Ds.onPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// نوار پیام وضعیت — خطا (رز) / موفقیت (سبز) با رنگ‌های نسل S
final class _MessageBar extends StatelessWidget {
  const _MessageBar({required this.ui});

  final DocumentsUi ui;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final tone = ui.isError
        ? (light ? Ds.error : Ds.rose)
        : (light ? Ds.green : Ds.mint);
    return Container(
      padding: const EdgeInsets.all(Ds.s12),
      decoration: BoxDecoration(
        color: light ? Ds.surface : Ds.surfaceDark,
        borderRadius: BorderRadius.circular(Ds.radiusField),
        border: Border.all(color: tone),
      ),
      child: Text(
        ui.message!,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: Ds.fontFamily,
          fontSize: 12.5,
          height: 1.6,
          color: tone,
        ),
      ),
    );
  }
}

/// خالی صادقانه — DsEmptyState نسل S
final class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Ds.s24),
        child: DsEmptyState(
          icon: Icons.folder_shared_outlined,
          title: 'هنوز سندی بارگذاری نشده است',
          hint: 'اسناد پرونده‌های شما (و مدارک وکیل) اینجا دیده می‌شود.',
          actionLabel: 'آپلود سند جدید',
          onAction: () => context.push('/documents/upload'),
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
        padding: const EdgeInsets.all(Ds.s24),
        child: DsEmptyState(
          icon: Icons.cloud_off_outlined,
          title: message,
          actionLabel: 'تلاش دوباره',
          onAction: onRetry,
        ),
      ),
    );
  }
}
