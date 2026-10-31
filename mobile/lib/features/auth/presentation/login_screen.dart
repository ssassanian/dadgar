import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../design/journey_bar.dart';
import '../../../design/tokens.dart';

/// صفحه‌ی ورود M7 (CMD-040) — بازطراحی تاییدشده‌ی مدیر (CMD-039):
/// «امکانات کامل باید روی داشبورد و توی صفحه‌ی ورود باشد؛ لاگین‌کردن
/// یا نکردن، تعیین‌کننده‌ی دیده‌شدن امکانات نیست.»
///
/// ترتیب: برند → شش قابلیت → نمونه‌ی مسیر پرونده (عنصر امضایی) → فرم ورود.
/// منطق احراز هویت عین M1 است؛ تا حکم مدیر بر D-6 سرور مسیر توکن را
/// نمی‌شناسد (404) و پیام صادقانه‌ی «در انتظار D-6» نمایش داده می‌شود.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

final class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).login(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) context.go('/');
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: DadgarTokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DadgarTokens.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── برند ──
                  const _BrandBlock(),
                  const SizedBox(height: DadgarTokens.s16),

                  // ── ویترین شش قابلیت (CMD-039) ──
                  const _CapabilityGrid(),
                  const SizedBox(height: DadgarTokens.s12),

                  // ── عنصر امضایی: نمونه‌ی مسیر پرونده ──
                  const _JourneyTeaser(),
                  const SizedBox(height: DadgarTokens.s16),

                  // ── فرم ورود — عین M1 ──
                  Container(
                    padding: const EdgeInsets.all(DadgarTokens.s16),
                    decoration: BoxDecoration(
                      color: DadgarTokens.surface,
                      borderRadius:
                          BorderRadius.circular(DadgarTokens.radius),
                      border: Border.all(
                        color: DadgarTokens.textSecondary
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'ورود به دادگر',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: DadgarTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: DadgarTokens.s8),
                          const Text(
                            'با همان حساب کاربری سایت دادگر وارد شوید',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: DadgarTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: DadgarTokens.s16),
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'نام کاربری',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return 'نام کاربری را وارد کنید';
                              return null;
                            },
                          ),
                          const SizedBox(height: DadgarTokens.s16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'رمز عبور',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'رمز عبور را وارد کنید';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: DadgarTokens.s16),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: DadgarTokens.primary,
                              foregroundColor: DadgarTokens.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                vertical: DadgarTokens.s16,
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: DadgarTokens.onPrimary,
                                    ),
                                  )
                                : const Text(
                                    'ورود',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                          const SizedBox(height: DadgarTokens.s12),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => context.go('/otp'),
                            child: const Text('ورود با کد یک‌بارمصرف (OTP)'),
                          ),
                          const SizedBox(height: DadgarTokens.s12),
                          const Text(
                            'اتصال زنده به سرور پس از حکم مدیر بر D-6 فعال '
                            'می‌شود (DOC-04 §۵) — کد موبایل آماده است.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: DadgarTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
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

/// برند — مونوگرام «د» + نام + وعده‌ی یک‌خطی
final class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DadgarTokens.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'د',
            style: TextStyle(
              color: DadgarTokens.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: DadgarTokens.s8),
        const Text(
          'دادگر',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: DadgarTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'همراه پرونده‌ی شما — از مشاوره تا صدور رأی',
          style: TextStyle(
            fontSize: 12.5,
            color: DadgarTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// ویترین شش قابلیت — عین ماتریس امکان CMD-039؛ هر کاشی به ماژولی
/// واقعی اپ پیوند دارد و پس از ورود در خانه عملیاتی می‌شود.
final class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid();

  static const _items = <({IconData icon, String title, String subtitle})>[
    (
      icon: Icons.folder_outlined,
      title: 'پیگیری زنده‌ی پرونده',
      subtitle: 'مسیر پنج‌مرحله‌ای، گزارش هر اقدام',
    ),
    (
      icon: Icons.chat_bubble_outline,
      title: 'گفتگو با وکیل',
      subtitle: 'پیام امن و محرمانه، پیوند با پرونده',
    ),
    (
      icon: Icons.calendar_month_outlined,
      title: 'رزرو نوبت',
      subtitle: 'تقویم شمسی، حضوری و آنلاین',
    ),
    (
      icon: Icons.verified_user_outlined,
      title: 'گاوصندوق اسناد',
      subtitle: 'بارگذاری و دانلود امن، برچسب محرمانه',
    ),
    (
      icon: Icons.receipt_long_outlined,
      title: 'فاکتور و پرداخت',
      subtitle: 'شفاف از ابتدا، اقساط مرحله‌ای',
    ),
    (
      icon: Icons.notifications_none,
      title: 'اعلان جلسات',
      subtitle: 'یادآور دادگاه و ضرب‌الاجل‌ها',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tile(({IconData icon, String title, String subtitle}) item) {
      return Container(
        padding: const EdgeInsets.all(DadgarTokens.s12),
        decoration: BoxDecoration(
          color: DadgarTokens.surface,
          borderRadius: BorderRadius.circular(DadgarTokens.radius),
          border: Border.all(
            color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: DadgarTokens.primary),
            const SizedBox(width: DadgarTokens.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: DadgarTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: DadgarTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _items.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < _items.length ? DadgarTokens.s8 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(_items[i])),
                const SizedBox(width: DadgarTokens.s8),
                Expanded(child: tile(_items[i + 1])),
              ],
            ),
          ),
      ],
    );
  }
}

/// نمونه‌ی مسیر پرونده — عنصر امضایی با برچسب صریح «نمایشی»؛
/// پنج مرحله‌ی واقعی چرخه‌ی سرور (S-4: هیچ مرحله‌ی اختراعی).
final class _JourneyTeaser extends StatelessWidget {
  const _JourneyTeaser();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DadgarTokens.s16),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'پرونده‌تان را قدم‌به‌قدم ببینید',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: DadgarTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'نمایشی — پس از ورود، وضعیت واقعی پرونده‌ی خودتان',
            style: TextStyle(
              fontSize: 11,
              color: DadgarTokens.textSecondary,
            ),
          ),
          const SizedBox(height: DadgarTokens.s12),
          const DadgarJourneyBar(
            steps: ['ثبت', 'پیشنهاد', 'تخصیص', 'در حال انجام', 'پایان'],
          ),
        ],
      ),
    );
  }
}
