import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';
import '../../cases/data/cases_contract.dart';

/// صفحه‌ی ورود «دادگر S» — بازنویسی از صفر (CMD-051؛ اجرای حکم CMD-050)
///
/// حکم مدیر (CMD-039) پابرجا: «امکانات کامل باید روی داشبورد و توی
/// صفحه‌ی ورود باشد» — ویترین شش قابلیت + عنصر امضایی مسیر پرونده +
/// فرم ورود، این‌بار با هویت موبایل‌بومی نسل S (فقط پالت برند وب مشترک).
/// منطق احراز هویت عین M1 است و به مسیر زنده‌ی توکن سرور وصل است
/// (افزوده‌ی CMD-026/REL-011)؛ خطاها عین پیام سرور نمایش داده می‌شوند.
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
            padding: const EdgeInsets.all(Ds.s16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── برند نسل S ──
                  const _BrandBlock(),
                  const SizedBox(height: Ds.s20),

                  // ── ویترین شش قابلیت (CMD-039) ──
                  const _CapabilityGrid(),
                  const SizedBox(height: Ds.s16),

                  // ── عنصر امضایی: نمونه‌ی مسیر پرونده ──
                  const _JourneyTeaser(),
                  const SizedBox(height: Ds.s16),

                  // ── فرم ورود — عین M1 ──
                  DsCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'ورود به دادگر',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: Ds.fontFamily,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Ds.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'با همان حساب کاربری سایت دادگر وارد شوید',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: Ds.fontFamily,
                              fontSize: 13,
                              color: Ds.inkSoft,
                            ),
                          ),
                          const SizedBox(height: Ds.s16),
                          DsTextField(
                            controller: _usernameController,
                            label: 'نام کاربری',
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            prefixIcon: Icons.person_outline,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return 'نام کاربری را وارد کنید';
                              return null;
                            },
                          ),
                          const SizedBox(height: Ds.s16),
                          DsTextField(
                            controller: _passwordController,
                            label: 'رمز عبور',
                            obscure: _obscure,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _submit(),
                            prefixIcon: Icons.lock_outline,
                            suffix: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 21,
                                color: Ds.inkSoft,
                              ),
                              tooltip: _obscure
                                  ? 'نمایش رمز'
                                  : 'پنهان‌کردن رمز',
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'رمز عبور را وارد کنید';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: Ds.s20),
                          DsButton(
                            'ورود',
                            onPressed: _submitting ? null : _submit,
                            expand: true,
                          ),
                          if (_submitting) ...[
                            const SizedBox(height: Ds.s12),
                            const Center(child: DsRing()),
                          ],
                          const SizedBox(height: Ds.s8),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => context.go('/otp'),
                            child: const Text('ورود با کد یک‌بارمصرف (OTP)'),
                          ),
                          // F8 (حکم CMD-048): بازیابی رمز دفترمحور — صادقانه،
                          // بدون جریان نمایشی جعلی و بدون مسیر سرور جدید (S-4).
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => _showForgotSheet(context),
                            child: const Text('فراموشی رمز عبور؟'),
                          ),
                          const SizedBox(height: Ds.s4),
                          const Text(
                            'اتصال زنده به سرور — ورود با همان حساب سایت '
                            '(توکن Bearer؛ افزوده‌ی CMD-026/REL-011).',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: Ds.fontFamily,
                              fontSize: 12,
                              height: 1.7,
                              color: Ds.inkFaint,
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

/// F8 (حکم CMD-048): بازیابی رمز دفترمحور — صادقانه (S-4):
/// بدون مسیر سرور جعلی؛ تماس با شماره‌ی ثبت‌شده‌ی سایت.
void _showForgotSheet(BuildContext context) {
  showDsSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Ds.s16, 0, Ds.s16, Ds.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'بازیابی رمز عبور',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Ds.ink,
              ),
            ),
            const SizedBox(height: Ds.s8),
            const Text(
              'بازیابی رمز از طریق دفتر مؤسسه انجام می‌شود تا حساب شما امن بماند؛ '
              'با شماره‌ی ثبت‌شده‌ی حساب تماس بگیرید — پس از احراز هویت، رمز تازه صادر می‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12.5,
                height: 1.8,
                color: Ds.inkSoft,
              ),
            ),
            const SizedBox(height: Ds.s16),
            DsButton(
              'تماس با دفتر — ۰۲۱-۰۰۰۰۰۰۰۰',
              onPressed: () {
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('در اپ واقعی: تماس با دفتر مؤسسه'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
              tone: DsButtonTone.ghost,
              expand: true,
            ),
          ],
        ),
      ),
    ),
  );
}

/// برند نسل S — بلوک آبی با مونوگرام سفید (چیدمان تازه، بدون ارث وب)
final class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Ds.s20, horizontal: Ds.s16),
      decoration: BoxDecoration(
        color: Ds.primary,
        borderRadius: BorderRadius.circular(Ds.radiusSheet),
        boxShadow: Ds.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'د',
              style: TextStyle(
                color: Ds.primary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: Ds.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'دادگر',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'همراه پرونده‌ی شما — از مشاوره تا صدور رأی',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      subtitle: 'مسیر شش‌مرحله‌ای، گزارش هر اقدام',
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
        padding: const EdgeInsets.all(Ds.s12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Ds.radiusCard),
          border: Border.all(color: Ds.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Ds.wash,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: Ds.primary),
            ),
            const SizedBox(height: Ds.s8),
            Text(
              item.title,
              style: const TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Ds.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              style: const TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 11.5,
                height: 1.55,
                color: Ds.inkFaint,
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
              bottom: i + 2 < _items.length ? Ds.s8 : 0,
            ),
            // IntrinsicHeight برای هم‌ارتفاعی کاشی‌ها — چون ستون بیرونی
            // بی‌کران است (اسکرول)، stretch تنها با کراندار کردن ارتفاع مجاز است
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tile(_items[i])),
                  const SizedBox(width: Ds.s8),
                  Expanded(child: tile(_items[i + 1])),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// نمونه‌ی مسیر پرونده — عنصر امضایی با برچسب صریح «نمایشی»؛
/// شش مرحله‌ی حقوقی طرح (حکم F1 سند CMD-048).
final class _JourneyTeaser extends StatelessWidget {
  const _JourneyTeaser();

  @override
  Widget build(BuildContext context) {
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'پرونده‌تان را قدم‌به‌قدم ببینید',
                  style: TextStyle(
                    fontFamily: Ds.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Ds.ink,
                  ),
                ),
              ),
              const DsPill('نمایشی', tone: DsPillTone.cyan),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'پس از ورود، وضعیت واقعی پرونده‌ی خودتان همین‌جا دیده می‌شود',
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 11,
              height: 1.6,
              color: Ds.inkFaint,
            ),
          ),
          const SizedBox(height: Ds.s12),
          const DsJourneyBar(steps: CasesContract.legalJourney),
        ],
      ),
    );
  }
}
