/// صفحه‌ی «گاوصندوق اسناد» مشتری — M5 (DOC-04 §۱۱ ردیف M5)
///
/// آینه‌ی cDocs وب (CMD-008): نام/پرونده/اندازه/تاریخ + چیپ سطح دسترسی
/// (استنتاج سرور: اشتراک با وکیل / محرمانه). عملیات: دانلود بایت‌به‌بایت
/// با ذخیره در پوشه‌ی اسناد اپ، حذف فقط اسناد خود، آپلود از دوربین/گالری
/// (سقف ۴ مگابایت — آینه‌ی DOC_MAX سرور).
///
/// انتخابگر فایل (image_picker) به‌صورت تزریق‌شدنی (`docPickerProvider`)
/// جداست تا تست‌ها بدون پلتفرم کار کنند (DOC-04 §۹).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/time/jalali.dart';
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
      appBar: AppBar(title: const Text('گاوصندوق اسناد')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/documents/upload'),
        icon: const Icon(Icons.upload_outlined),
        label: const Text('بارگذاری سند'),
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
          ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              DadgarTokens.s16,
              DadgarTokens.s16,
              DadgarTokens.s16,
              96,
            ),
            itemCount: ui.rows.length + 1,
            separatorBuilder: (_, __) =>
                const SizedBox(height: DadgarTokens.s8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: DadgarTokens.s4),
                  child: Text(
                    '${JalaliCalendar.toPersianDigits(ui.rows.length)} سند',
                    style: const TextStyle(
                      fontSize: 12,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                );
              }
              return _DocCard(row: ui.rows[index - 1]);
            },
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

/// کارت سند — نام/پرونده/اندازه/تاریخ + سطح دسترسی + عملیات
final class _DocCard extends ConsumerWidget {
  const _DocCard({required this.row});

  final DocSummary row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(documentsControllerProvider);
    final controller = ref.read(documentsControllerProvider.notifier);
    final created = JalaliCalendar.fromEpochSeconds(row.createdAt);
    return Material(
      color: DadgarTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        side: BorderSide(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(DadgarTokens.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: DadgarTokens.primary,
                ),
                const SizedBox(width: DadgarTokens.s8),
                Expanded(
                  child: Text(
                    row.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DadgarTokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DadgarTokens.s8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (row.shared
                            ? DadgarTokens.primary
                            : DadgarTokens.textSecondary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    row.shared
                        ? DocumentsContract.sharedLabel
                        : DocumentsContract.privateLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: row.shared
                          ? DadgarTokens.primary
                          : DadgarTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DadgarTokens.s4),
            Text(
              '${row.caseTitle.isEmpty ? '—' : row.caseTitle}'
              ' • ${DocumentsContract.formatSize(row.size)}'
              ' • ${JalaliCalendar.formatNumeric(created)}',
              style: const TextStyle(
                fontSize: 12,
                color: DadgarTokens.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DadgarTokens.s8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: ui.busy
                      ? null
                      : () async {
                          final path =
                              await controller.download(row);
                          if (path != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('سند در پوشه‌ی اسناد اپ ذخیره شد'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('دانلود'),
                ),
                if (row.mine) ...[
                  const SizedBox(width: DadgarTokens.s8),
                  TextButton.icon(
                    onPressed: ui.busy
                        ? null
                        : () async {
                            final ok = await _confirmDelete(context);
                            if (ok) await controller.remove(row);
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: DadgarTokens.error,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('حذف'),
                  ),
                ],
              ],
            ),
          ],
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
