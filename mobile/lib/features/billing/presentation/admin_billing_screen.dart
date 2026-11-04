/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// صفحه‌ی «مدیریت مالی» موبایل — M6 (CMD-028) با هویت موبایل‌بومی نسل S.
///
/// رفتار عین نسل قبل حفظ شده است (آینه‌ی بخش مالی قرارداد CMD-005 که از
/// قبل روی سرور بوده): فهرست همه‌ی فاکتورها با نام مشتری/وکیل (payload مدیر)،
/// صدور فاکتور دستی (مشتری + مبلغ — case_id اختیاری و در این نسخه خالی)،
/// ثبت پرداخت (pending → paid) و بازکردن (paid → pending) با دیالوگ تایید.
/// پیام‌های عملیات با SnackBar یکدست؛ خطای بارگذاری اولیه در پنل خطا (S-4:
/// پیام‌ها عین سرور). ورود فقط برای مدیر معنا دارد؛ قانون‌گذاری نهایی سمت
/// سرور است — ROLE('admin') هر تلاش نقش دیگر را 403 می‌کند.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/time/jalali.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../application/billing_controller.dart';
import '../data/billing_contract.dart';
import '../domain/invoice_models.dart';

/// تُن قرص وضعیت فاکتور — پرداخت‌شده=سبز، در انتظار=کهربایی، ناشناخته=خنثی
DsPillTone _statusTone(Invoice row) => switch (row.statusValue.value) {
      'paid' => DsPillTone.success,
      'pending' => DsPillTone.warn,
      _ => DsPillTone.neutral,
    };

/// صفحه‌ی مدیریت مالی (فقط مدیر) — DsTopBar نسل S + FAB صدور
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
      appBar: const DsTopBar('مدیریت مالی', showBack: true),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin-issue-invoice',
        onPressed: ui.busy ? null : () => _showIssueSheet(context),
        backgroundColor: Ds.primary,
        foregroundColor: Ds.onPrimary,
        icon: const Icon(Icons.post_add_outlined),
        label: const Text('صدور فاکتور'),
      ),
      body: switch (ui.status) {
        LoadStatus.loading => const Center(child: DsRing(size: 28)),
        LoadStatus.error => _ErrorPane(
            message: ui.message ?? 'خطای نامشخص',
            onRetry: controller.reload,
          ),
        LoadStatus.ready when ui.rows.isEmpty => const _EmptyPane(),
        LoadStatus.ready => RefreshIndicator(
            onRefresh: controller.reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Ds.s16,
                Ds.s16,
                Ds.s16,
                Ds.s32,
              ),
              itemCount: ui.rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: Ds.s8),
              itemBuilder: (context, index) =>
                  _AdminInvoiceCard(row: ui.rows[index]),
            ),
          ),
      },
    );
  }

  Future<void> _showIssueSheet(BuildContext context) async {
    await showDsSheet<void>(
      context: context,
      builder: (_) => const _IssueInvoiceSheet(),
    );
  }
}

/// کارت فاکتور مدیریتی — قرص وضعیت + نام مشتری/وکیل + مبلغ/تاریخ + اقدام
final class _AdminInvoiceCard extends ConsumerWidget {
  const _AdminInvoiceCard({required this.row});

  final Invoice row;

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
          DsButton(
            confirmLabel,
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
    final light = Theme.of(context).brightness == Brightness.light;
    final pending = row.statusValue == InvoiceStatus.pending;
    final created = JalaliCalendar.fromEpochSeconds(row.createdAt);
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsPill(row.statusValue.labelFa, tone: _statusTone(row)),
              const Spacer(),
              Text(
                'فاکتور ${BillingContract.toPersianDigits(row.id)}',
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 12,
                  color: light ? Ds.inkFaint : Ds.inkFaintDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: Ds.s8),
          Text(
            row.clientName.isEmpty ? 'بدون نام مشتری' : row.clientName,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: light ? Ds.ink : Ds.inkDark,
            ),
          ),
          if (row.lawyerName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'وکیل پرونده: ${row.lawyerName}',
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12.5,
                color: light ? Ds.inkSoft : Ds.inkSoftDark,
              ),
            ),
          ],
          const SizedBox(height: Ds.s4),
          DsKvRow('مبلغ', BillingContract.formatToman(row.amount)),
          DsKvRow(
            'صدور',
            JalaliCalendar.formatNumeric(created),
            divider: row.paidAt != null,
          ),
          if (row.paidAt != null)
            DsKvRow(
              'پرداخت',
              JalaliCalendar.formatNumeric(
                JalaliCalendar.fromEpochSeconds(row.paidAt!),
              ),
              valueTone: light ? Ds.green : Ds.mint,
              divider: false,
            ),
          const SizedBox(height: Ds.s12),
          Row(
            children: [
              Expanded(
                child: pending
                    ? DsButton(
                        'ثبت پرداخت',
                        icon: Icons.check_circle_outline,
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
                      )
                    : DsButton(
                        'بازکردن',
                        icon: Icons.replay_outlined,
                        tone: DsButtonTone.outline,
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
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// فرم صدور فاکتور دستی — مشتری + مبلغ در شیت نسل S (آینه‌ی فرم وب
/// CMD-005؛ اتصال پرونده اختیاری است و در این نسخه ثبت نمی‌شود)
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
  void initState() {
    super.initState();
    // پاک‌شدن خطا با هر تایپ — عین رفتار onChanged نسل قبل (DsTextField
    // عضو onChanged ندارد → گوش‌دهنده به کنترلر)
    _amountController.addListener(_clearError);
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  void dispose() {
    _amountController.removeListener(_clearError);
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final clientError = _clientId == null ? 'مشتری را انتخاب کنید' : null;
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
    final light = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Ds.s16,
        0,
        Ds.s16,
        MediaQuery.of(context).viewInsets.bottom + Ds.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'صدور فاکتور دستی',
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: light ? Ds.ink : Ds.inkDark,
            ),
          ),
          const SizedBox(height: Ds.s4),
          Text(
            'مشتری و مبلغ را وارد کنید (مبلغ: ۱٬۰۰۰ تا ۱۰ میلیارد تومان).',
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 12.5,
              height: 1.7,
              color: light ? Ds.inkSoft : Ds.inkSoftDark,
            ),
          ),
          const SizedBox(height: Ds.s16),
          if (clientsAsync.isLoading)
            const Center(child: DsRing())
          else if (clients.isEmpty)
            Text(
              'فهرست مشتریان در دسترس نیست.',
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: light ? Ds.error : Ds.rose,
              ),
            )
          else
            _ClientField(
              clients: clients,
              onChanged: (v) => setState(() {
                _clientId = v;
                _error = null;
              }),
            ),
          const SizedBox(height: Ds.s16),
          DsTextField(
            controller: _amountController,
            label: 'مبلغ (تومان)',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.payments_outlined,
          ),
          if (_error != null) ...[
            const SizedBox(height: Ds.s8),
            Text(
              _error!,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: light ? Ds.error : Ds.rose,
              ),
            ),
          ],
          const SizedBox(height: Ds.s20),
          DsButton(
            'صدور فاکتور',
            icon: Icons.post_add_outlined,
            expand: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// انتخابگر مشتری — دراپ‌داون متریال با برچسب بالای فیلد (هم‌شکل DsTextField)؛
/// کیت نسل S عضو دراپ‌داون ندارد → ویجت خصوصی این صفحه.
final class _ClientField extends StatelessWidget {
  const _ClientField({required this.clients, required this.onChanged});

  final List<MinUser> clients;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مشتری',
          style: TextStyle(
            fontFamily: Ds.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: light ? Ds.ink : Ds.inkDark,
          ),
        ),
        const SizedBox(height: Ds.s8),
        DropdownButtonFormField<int>(
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'انتخاب مشتری'),
          items: [
            for (final c in clients)
              DropdownMenuItem<int>(
                value: c.id,
                child: Text(
                  c.name.isEmpty
                      ? BillingContract.toPersianDigits(c.id)
                      : c.name,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// خطای صادقانه + تلاش دوباره — پیام عین سرور (۴۰۳ نقش غیر مدیر)
final class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DsEmptyState(
      icon: Icons.cloud_off_outlined,
      title: message,
      actionLabel: 'تلاش دوباره',
      onAction: onRetry,
    );
  }
}

/// خالی صادقانه — عین متن وب CMD-005 (بدون داده‌ی جعلی)
final class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return DsEmptyState(
      icon: Icons.receipt_long_outlined,
      title: BillingContract.emptyMessage,
    );
  }
}
