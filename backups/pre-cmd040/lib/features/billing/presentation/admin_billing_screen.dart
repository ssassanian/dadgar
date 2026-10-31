/// صفحه‌ی «مدیریت مالی» موبایل — M6 (CMD-028)
///
/// حکم مدیر: پنل مدیریتی موبایل = مالی + اقدامات پرونده. این صفحه آینه‌ی
/// بخش مالیِ همان قرارداد CMD-005 است که از قبل روی سرور بوده:
///   فهرست همه‌ی فاکتورها با نام مشتری/وکیل (payload مدیر)
///   صدور فاکتور دستی (مشتری + مبلغ — case_id اختیاری و در این نسخه خالی)
///   ثبت پرداخت (pending → paid) و بازکردن (paid → pending)
///
/// ورود فقط برای نقش مدیر معنا دارد؛ نقش از GET /api/me کشف می‌شود و کارت
/// آن فقط به مدیر نشان داده می‌شود (home_screen). قانون‌گذاری نهایی سمت
/// سرور است — ROLE('admin') هر تلاش نقش دیگر را 403 می‌کند و پیام عین
/// سرور نمایش داده می‌شود.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/tokens.dart';
import '../application/billing_controller.dart';
import '../data/billing_contract.dart';
import '../domain/invoice_models.dart';

/// صفحه‌ی مدیریت مالی (فقط مدیر)
class AdminBillingScreen extends ConsumerWidget {
  const AdminBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(billingControllerProvider);
    final controller = ref.read(billingControllerProvider.notifier);

    // پیام‌های عملیات (صدور/ثبت پرداخت/بازکردن) — SnackBar یکدست.
    // خطای بارگذاری اولیه در error-pane رندر می‌شود؛ SnackBar تکراری نمی‌خواهد.
    ref.listen<BillingUi>(billingControllerProvider, (prev, next) {
      if (next.status == LoadStatus.error) return;
      final msg = next.message;
      if (msg != null && msg.isNotEmpty && prev?.message != msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت مالی')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-issue-invoice',
        onPressed: ui.busy ? null : () => _showIssueDialog(context, ref),
        icon: const Icon(Icons.post_add_outlined),
        label: const Text('صدور فاکتور'),
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(child: CircularProgressIndicator()),
        LoadStatus.error => Center(
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
                    ui.message ?? 'خطای نامشخص',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.8,
                      color: DadgarTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: DadgarTokens.s16),
                  OutlinedButton.icon(
                    onPressed: controller.reload,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('تلاش دوباره'),
                  ),
                ],
              ),
            ),
          ),
        LoadStatus.ready when ui.rows.isEmpty => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DadgarTokens.s24),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: DadgarTokens.textSecondary,
                  ),
                  const SizedBox(height: DadgarTokens.s12),
                  const Text(
                    BillingContract.emptyMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        LoadStatus.ready => RefreshIndicator(
            onRefresh: controller.reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                DadgarTokens.s16,
                DadgarTokens.s16,
                DadgarTokens.s16,
                DadgarTokens.s32,
              ),
              itemCount: ui.rows.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: DadgarTokens.s8),
              itemBuilder: (context, index) =>
                  _AdminInvoiceCard(row: ui.rows[index]),
            ),
          ),
      },
    );
  }

  Future<void> _showIssueDialog(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _IssueInvoiceSheet(),
    );
  }
}

/// کارت فاکتور مدیریتی — نام مشتری/وکیل + اقدامات وضعیت
final class _AdminInvoiceCard extends ConsumerWidget {
  const _AdminInvoiceCard({required this.row});

  final Invoice row;

  Color get _statusColor => switch (row.status) {
        'paid' => DadgarTokens.accent,
        'pending' => DadgarTokens.primary,
        _ => DadgarTokens.textSecondary,
      };

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final controller = ref.read(billingControllerProvider.notifier);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.setInvoiceStatus(
        id: row.id,
        status: row.status == 'pending' ? 'paid' : 'pending',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(billingControllerProvider);
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DadgarTokens.s8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    row.statusValue.labelFa,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'فاکتور ${BillingContract.toPersianDigits(row.id)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: DadgarTokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DadgarTokens.s8),
            Text(
              row.clientName.isEmpty ? 'بدون نام مشتری' : row.clientName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DadgarTokens.textPrimary,
              ),
            ),
            if (row.lawyerName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'وکیل پرونده: ${row.lawyerName}',
                style: const TextStyle(
                  fontSize: 12,
                  color: DadgarTokens.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: DadgarTokens.s8),
            Text(
              BillingContract.formatToman(row.amount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DadgarTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DadgarTokens.s4),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 14,
                  color: DadgarTokens.textSecondary,
                ),
                const SizedBox(width: DadgarTokens.s4),
                Text(
                  JalaliCalendar.formatNumeric(created),
                  style: const TextStyle(
                    fontSize: 12,
                    color: DadgarTokens.textSecondary,
                  ),
                ),
                if (row.paidAt != null) ...[
                  const SizedBox(width: DadgarTokens.s8),
                  Text(
                    'پرداخت: ${JalaliCalendar.formatNumeric(JalaliCalendar.fromEpochSeconds(row.paidAt!))}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: DadgarTokens.accent,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: DadgarTokens.s8),
            Row(
              children: [
                if (row.statusValue == InvoiceStatus.pending)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: ui.busy
                          ? null
                          : () => _confirm(
                                context,
                                ref,
                                title: 'ثبت پرداخت',
                                body:
                                    'پرداخت فاکتور ${BillingContract.toPersianDigits(row.id)} به مبلغ ${BillingContract.formatToman(row.amount)} ثبت شود؟',
                                confirmLabel: 'ثبت پرداخت',
                              ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('ثبت پرداخت'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: ui.busy
                          ? null
                          : () => _confirm(
                                context,
                                ref,
                                title: 'بازکردن فاکتور',
                                body:
                                    'فاکتور ${BillingContract.toPersianDigits(row.id)} بازگشایی شود (به «در انتظار» برمی‌گردد)؟',
                                confirmLabel: 'بازکردن',
                              ),
                      icon: const Icon(Icons.replay_outlined, size: 18),
                      label: const Text('بازکردن'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// فرم صدور فاکتور دستی — مشتری + مبلغ (آینه‌ی فرم وب CMD-005؛
/// اتصال پرونده اختیاری است و در این نسخه ثبت نمی‌شود)
final class _IssueInvoiceSheet extends ConsumerStatefulWidget {
  const _IssueInvoiceSheet();

  @override
  ConsumerState<_IssueInvoiceSheet> createState() => _IssueInvoiceSheetState();
}

final class _IssueInvoiceSheetState extends ConsumerState<_IssueInvoiceSheet> {
  int? _clientId;
  final _amountController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final clientError =
        _clientId == null ? 'مشتری را انتخاب کنید' : null;
    final amountError = BillingContract.validateIssueAmount(
      _amountController.text,
    );
    if (clientError != null || amountError != null) {
      setState(() => _error = clientError ?? amountError);
      return;
    }
    final amount = int.parse(
      BillingContract.toEnglishDigits(_amountController.text),
    );
    final id = await ref
        .read(billingControllerProvider.notifier)
        .issueInvoice(clientId: _clientId!, amount: amount);
    if (!mounted) return;
    if (id != null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error =
          ref.read(billingControllerProvider).message ?? 'صدور ناموفق بود');
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(billingClientsProvider);
    final clients = clientsAsync.value ?? const <MinUser>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DadgarTokens.s16,
        DadgarTokens.s16,
        DadgarTokens.s16,
        MediaQuery.of(context).viewInsets.bottom + DadgarTokens.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'صدور فاکتور دستی',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DadgarTokens.textPrimary,
            ),
          ),
          const SizedBox(height: DadgarTokens.s4),
          const Text(
            'مشتری و مبلغ را وارد کنید (مبلغ: ۱٬۰۰۰ تا ۱۰ میلیارد تومان).',
            style: TextStyle(
              fontSize: 12,
              color: DadgarTokens.textSecondary,
            ),
          ),
          const SizedBox(height: DadgarTokens.s12),
          if (clientsAsync.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (clients.isEmpty)
            const Text(
              'فهرست مشتریان در دسترس نیست.',
              style: TextStyle(
                fontSize: 12,
                color: DadgarTokens.error,
              ),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _clientId,
              decoration: const InputDecoration(
                labelText: 'مشتری',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in clients)
                  DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(c.name.isEmpty
                        ? BillingContract.toPersianDigits(c.id)
                        : c.name),
                  ),
              ],
              onChanged: (v) => setState(() {
                _clientId = v;
                _error = null;
              }),
            ),
          const SizedBox(height: DadgarTokens.s12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'مبلغ (تومان)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) ...[
            const SizedBox(height: DadgarTokens.s8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                color: DadgarTokens.error,
              ),
            ),
          ],
          const SizedBox(height: DadgarTokens.s16),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.post_add_outlined, size: 18),
            label: const Text('صدور فاکتور'),
          ),
        ],
      ),
    );
  }
}
