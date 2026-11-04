import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design/tokens.dart';

/// صفحه‌ی OTP — اسکلت UI فاز M1
///
/// سرویس پیامک و مسیر OTP سمت سرور موجود وب، مبنای فاز ۲ M1 است؛
/// ارسال و تایید پس از حکم D-6 و تعیین مسیر نهایی فعال می‌شود —
/// تا آن زمان دکمه‌ها صادقانه غیرفعال‌اند (نه داده‌ی جعلی).
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

final class _OtpScreenState extends State<OtpScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ورود با OTP')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DadgarTokens.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.sms_outlined,
                      size: 56, color: DadgarTokens.primary),
                  const SizedBox(height: DadgarTokens.s16),
                  const Text(
                    'کد یک‌بارمصرف به شماره موبایل شما پیامک می‌شود',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: DadgarTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: DadgarTokens.s24),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'شماره موبایل',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: DadgarTokens.s24),
                  FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: DadgarTokens.primary,
                      padding: const EdgeInsets.symmetric(
                        vertical: DadgarTokens.s16,
                      ),
                    ),
                    child: const Text('ارسال کد (به‌زودی)'),
                  ),
                  const SizedBox(height: DadgarTokens.s16),
                  Container(
                    padding: const EdgeInsets.all(DadgarTokens.s12),
                    decoration: BoxDecoration(
                      color: DadgarTokens.surface,
                      borderRadius:
                          BorderRadius.circular(DadgarTokens.radius),
                      border: Border.all(
                        color:
                            DadgarTokens.textSecondary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Text(
                      'فعال‌سازی OTP موبایل در فاز ۲ M1 — نیازمند حکم '
                      'مدیر بر D-6 (DOC-04 §۵-۲)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: DadgarTokens.s12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('بازگشت به ورود با رمز'),
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
