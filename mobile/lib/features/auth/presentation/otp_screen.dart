import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';

/// صفحه‌ی OTP «دادگر S» — کد تازه از صفر (CMD-051)
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
      appBar: DsTopBar('ورود با OTP', showBack: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Ds.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── هیروی شمسی فیروزه‌ای ──
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Ds.tintCyan,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sms_outlined,
                        size: 32,
                        color: Ds.cyanDeep,
                      ),
                    ),
                  ),
                  const SizedBox(height: Ds.s16),
                  const Text(
                    'کد یک‌بارمصرف به شماره موبایل شما پیامک می‌شود',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Ds.fontFamily,
                      fontSize: 15,
                      height: 1.7,
                      color: Ds.ink,
                    ),
                  ),
                  const SizedBox(height: Ds.s24),
                  DsTextField(
                    controller: _phoneController,
                    label: 'شماره موبایل',
                    hint: '۰۹۱۲ ۰۰۰ ۰۰۰۰',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                  ),
                  const SizedBox(height: Ds.s24),
                  const DsButton('ارسال کد (به‌زودی)', expand: true),
                  const SizedBox(height: Ds.s16),
                  DsCard(
                    padding: const EdgeInsets.all(Ds.s12),
                    child: Text(
                      'فعال‌سازی OTP موبایل در فاز ۲ M1 — نیازمند حکم '
                      'مدیر بر D-6 (DOC-04 §۵-۲)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: Ds.fontFamily,
                        fontSize: 12,
                        height: 1.7,
                        color: Ds.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: Ds.s12),
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
