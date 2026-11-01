/// پروفایل M1 — تب پوسته (بدون AppBar؛ نوار بالای طرح)
///
/// CMD-046 (فاز ۳): بازطراحی D-3 عین طرح تاییدشده‌ی CMD-041 (`bProfile` در
/// `design-preview/prototype.html`): کارت حساب (آواتار حرف اول + نام کاربری
/// + قرص «حساب فعال» از وضعیت Authenticated واقعی) و پنل امنیت با سوییچ
/// بیومتریک (M1) و خروج.
///
/// صداقت داده (S-4): «تغییر رمز عبور» و «دستگاه‌های من» طرح بدون API/داده
/// در قرارداد موبایل نیستند (M1 فقط بیومتریک دارد) → اضافه نمی‌شوند
/// (آفورد مرده = نقض S-4)؛ «خروج از همه‌ی دستگاه‌ها» به‌صورت یادداشت
/// صادقانه می‌ماند. نشست + قفل بیومتریک + خروج (DOC-04 §۸) حفظ شده است.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../design/d3_kit.dart';
import '../../design/tokens.dart';
import '../auth/application/auth_controller.dart';

/// پروفایل — حساب و امنیت
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

final class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _toggleLock(bool value) async {
    final ok = await ref.read(appLockControllerProvider.notifier).setEnabled(value);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('این دستگاه از بیومتریک پشتیبانی نمی‌کند'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خروج از حساب'),
        content: const Text('توکن این دستگاه ابطال و نشست پاک می‌شود.'),
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
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    ref.read(appLockControllerProvider.notifier).reset();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authControllerProvider);
    final lock = ref.watch(appLockControllerProvider);
    final username = switch (status) {
      Authenticated(:final username) => username,
      _ => 'کاربر دادگر',
    };
    final initial = username.isNotEmpty ? username.characters.first : 'د';

    return Scaffold(
      backgroundColor: DadgarTokens.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            DadgarTokens.s16,
            DadgarTokens.s12,
            DadgarTokens.s16,
            DadgarTokens.s32,
          ),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: DadgarTopBar(title: 'پروفایل', subtitle: 'حساب و امنیت'),
            ),
            const SizedBox(height: DadgarTokens.s12),
            // ── کارت حساب — کلاس `.lawyer` طرح ──
            DadgarPanel(
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: DadgarTokens.pillDataBg,
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: DadgarTokens.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: DadgarTokens.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: DadgarTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'نشست موبایل دادگر — احراز هویت با توکن Bearer',
                          style: TextStyle(
                            fontSize: 12,
                            color: DadgarTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DadgarTokens.s8),
                  const DadgarPill(
                    'حساب فعال',
                    variant: DadgarPillVariant.positive,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DadgarTokens.s12),
            // ── پنل امنیت — سوییچ بیومتریک M1 ──
            DadgarPanel(
              head: 'امنیت',
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                children: [
                  SwitchListTile(
                    value: lock.enabled,
                    onChanged: (value) => _toggleLock(value),
                    contentPadding: EdgeInsets.zero,
                    // رنگ فعال از ColorScheme.lightTheme (primary سرمه‌ای) می‌آید
                    secondary: const Icon(
                      Icons.fingerprint,
                      color: DadgarTokens.primary,
                    ),
                    title: const Text(
                      'ورود با بیومتریک',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: DadgarTokens.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'بازکردن اپ با اثر انگشت یا چهره',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DadgarTokens.s24),
            DadgarGhostButton(
              'خروج از این دستگاه',
              destructive: true,
              onPressed: () => _logout(),
            ),
            const SizedBox(height: DadgarTokens.s8),
            const Text(
              '«خروج از همه‌ی دستگاه‌ها» در فازهای بعدی پروفایل کامل می‌شود',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: DadgarTokens.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
