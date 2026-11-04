/// صفحه‌ی «گاوصندوق اسناد» مشتری — M5 (DOC-04 §۱۱ ردیف M5)
///
/// CMD-046 (فاز ۳): بازطراحی D-3 عین طرح تاییدشده‌ی CMD-041 (`bDocs` در
/// `design-preview/prototype.html`): AppBar کاغذی «گاوصندوق اسناد» با
/// زیرنویس محرمانگی، جعبه‌ی صادقانه‌ی رمزنگاری، ردیف‌های دوخطی با قرص
/// دسترسی و دکمه‌ی شبح «آپلود سند جدید» پایان فهرست (حذف FAB خارج از
/// زبان طرح — هم‌روال cases در CMD-045). عملیات دانلود/حذف در شیت پایین
/// (زبان شیتِ خود طرح) با حفظ کامل منطق M5.
///
/// آینه‌ی cDocs وب (CMD-008): نام/پرونده/اندازه/تاریخ + چیپ سطح دسترسی
/// (استنتاج سرور: اشتراک با وکیل / محرمانه — برچسب نمایشی «جدید» طرح
/// اتخاذ نمی‌شود S-4). دانلود بایت‌به‌بایت با ذخیره در پوشه‌ی اسناد اپ،
/// حذف فقط اسناد خود، آپلود از دوربین/گالری (سقف ۴ مگابایت — DOC_MAX).
/// یادداشت رمزنگاری عین حقیقت سرور است: name_enc/file با AES-256-GCM
/// ذخیره می‌شود (web.js §documents).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/jalali.dart';
import '../../../design/d3_kit.dart';
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
            const Text(
              'گاوصندوق اسناد',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: DadgarTokens.textPrimary,
              ),
            ),
            Text(
              ui.status == LoadStatus.ready
                  ? '${JalaliCalendar.toPersianDigits(ui.rows.length)} سند'
                  : 'محرمانه — فقط شما و وکیل پرونده',
              style: const TextStyle(
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
        LoadStatus.ready when ui.rows.isEmpty => const _EmptyPane(),
        LoadStatus.ready => _DocsList(ui: ui),
      },
    );
  }
}

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
            padding: const EdgeInsets.fromLTRB(
              DadgarTokens.s16,
              DadgarTokens.s4,
              DadgarTokens.s16,
              DadgarTokens.s32,
            ),
            children: [
              // یادداشت صادقانه — عین bDocs طرح و حقیقت سرور (AES-256-GCM)
              const DadgarEmptyBox(
                'اسناد با رمزنگاری ذخیره می‌شوند و هر دانلود، '
                'بایت‌به‌بایت ثبت می‌شود.',
              ),
              const SizedBox(height: DadgarTokens.s12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: DadgarTokens.surface,
                  borderRadius: BorderRadius.circular(DadgarTokens.radius),
                  border: Border.all(color: DadgarTokens.cardBorder),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < ui.rows.length; i++) ...[
                      if (i > 0) const DadgarRowRule(),
                      _DocRow(row: ui.rows[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: DadgarTokens.s12),
              DadgarGhostButton(
                'آپلود سند جدید',
                onPressed: () => context.push('/documents/upload'),
              ),
            ],
          ),
          if (ui.message != null)
            Positioned(
              left: DadgarTokens.s16,
              right: DadgarTokens.s16,
              bottom: 16,
              child: _MessageBar(ui: ui),
            ),
        ],
      ),
    );
  }
}

/// نوار پیام وضعیت — خطا (قرمز) / موفقیت (سبز)
final class _MessageBar extends StatelessWidget {
  const _MessageBar({required this.ui});

  final DocumentsUi ui;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DadgarTokens.s12),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: ui.isError
              ? DadgarTokens.error
              : DadgarTokens.accent.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        ui.message!,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: ui.isError ? DadgarTokens.error : DadgarTokens.accent,
        ),
      ),
    );
  }
}

/// ردیف سند — نام/پرونده/اندازه/تاریخ + قرص دسترسی؛ تپ → شیت عملیات
final class _DocRow extends ConsumerWidget {
  const _DocRow({required this.row});

  final DocSummary row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final created = JalaliCalendar.fromEpochSeconds(row.createdAt);
    return DadgarListRow(
      title: row.name,
      subtitle: '${row.caseTitle.isEmpty ? '—' : row.caseTitle}'
          ' • ${DocumentsContract.formatSize(row.size)}'
          ' • ${JalaliCalendar.formatNumeric(created)}',
      side: DadgarPill(
        row.shared ? DocumentsContract.sharedLabel : DocumentsContract.privateLabel,
        variant: row.shared ? DadgarPillVariant.data : DadgarPillVariant.neutral,
      ),
      showChevron: true,
      onTap: () => _showActions(context, ref),
    );
  }

  /// شیت عملیات — همان زبان شیتِ طرح؛ دانلود (M5) و حذف فقط اسناد خود
  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final ui = ref.read(documentsControllerProvider);
    final controller = ref.read(documentsControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: DadgarTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DadgarTokens.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DadgarTokens.textPrimary,
                ),
              ),
              const SizedBox(height: DadgarTokens.s12),
              DadgarGhostButton(
                'دانلود',
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
                const SizedBox(height: DadgarTokens.s8),
                DadgarGhostButton(
                  'حذف',
                  destructive: true,
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
              backgroundColor: DadgarTokens.error,
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

/// خالی صادقانه
final class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DadgarTokens.s24),
        child: Column(
          children: [
            const Icon(
              Icons.folder_shared_outlined,
              size: 48,
              color: DadgarTokens.textSecondary,
            ),
            const SizedBox(height: DadgarTokens.s12),
            const Text(
              'هنوز سندی بارگذاری نشده است',
              style: TextStyle(
                fontSize: 14,
                color: DadgarTokens.textSecondary,
              ),
            ),
            const SizedBox(height: DadgarTokens.s8),
            const Text(
              'اسناد پرونده‌های شما (و مدارک وکیل) اینجا دیده می‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.8,
                color: DadgarTokens.textSecondary,
              ),
            ),
            const SizedBox(height: DadgarTokens.s16),
            DadgarGhostButton(
              'آپلود سند جدید',
              onPressed: () => context.push('/documents/upload'),
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
            DadgarGhostButton('تلاش دوباره', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
