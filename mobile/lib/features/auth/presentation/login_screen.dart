import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../design/tokens.dart';

/// صفحه‌ی ورود M1 — همان حساب‌های موجود وب (DOC-04 §۵-۲)
///
/// تا حکم مدیر بر D-6، سرور مسیر توکن را نمی‌شناسد (404) و پیام
/// صادقانه‌ی «در انتظار D-6» نمایش داده می‌شود — همان صداقت وب.
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.gavel,
                        size: 56, color: DadgarTokens.primary),
                    const SizedBox(height: DadgarTokens.s12),
                    const Text(
                      'ورود به دادگر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
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
                    const SizedBox(height: DadgarTokens.s24),
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
                    const SizedBox(height: DadgarTokens.s24),
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
                      onPressed: _submitting ? null : () => context.go('/otp'),
                      child: const Text('ورود با کد یک‌بارمصرف (OTP)'),
                    ),
                    const SizedBox(height: DadgarTokens.s16),
                    Container(
                      padding: const EdgeInsets.all(DadgarTokens.s12),
                      decoration: BoxDecoration(
                        color: DadgarTokens.surface,
                        borderRadius:
                            BorderRadius.circular(DadgarTokens.radius),
                        border: Border.all(
                          color: DadgarTokens.textSecondary
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text(
                        'اتصال زنده به سرور پس از حکم مدیر بر D-6 فعال '
                        'می‌شود (DOC-04 §۵) — کد موبایل آماده است.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: DadgarTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
