/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// پروفایل M1 — تب پوسته با هویت موبایل‌بومی «دادگر S» (اجرای حکم
/// CMD-050؛ تنها پالت برند وب مشترک): سربرگ DsTopBar، کارت حساب
/// (آواتار حرف اول در tint آبی + نام کاربری + قرص «حساب فعال» از
/// وضعیت Authenticated واقعی) و بخش امنیت با ردیف DsTile و سوییچ
/// بیومتریک (M1) و دکمه‌ی خروج مخرب. صفر عنصر بصری نسل قبل باقی نمانده.
///
/// صداقت داده (S-4): «تغییر رمز عبور» و «دستگاه‌های من» طرح بدون API/داده
/// در قرارداد موبایل نیستند (M1 فقط بیومتریک دارد) → اضافه نمی‌شوند
/// (آفورد مرده = نقض S-4)؛ «خروج از همه‌ی دستگاه‌ها» به‌صورت یادداشت
/// صادقانه می‌ماند. نشست + قفل بیومتریک + خروج (DOC-04 §۸) عین
/// نسل قبل حفظ شده است.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../design/ds_kit.dart';
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
    final ok =
        await ref.read(appLockControllerProvider.notifier).setEnabled(value);
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
    final light = Theme.of(context).brightness == Brightness.light;
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
              backgroundColor: light ? Ds.error : Ds.rose,
              foregroundColor: Ds.onPrimary,
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
    final light = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: const DsTopBar('پروفایل', subtitle: 'حساب و امنیت'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Ds.s16, Ds.s8, Ds.s16, Ds.s32),
        children: [
          // ── کارت حساب — آواتار حرف اول + وضعیت واقعی نشست ──
          DsCard(
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: light ? Ds.wash : Ds.washDark,
                  ),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontFamily: Ds.fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: light ? Ds.primary : Ds.cyan,
                    ),
                  ),
                ),
                const SizedBox(width: Ds.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Ds.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: light ? Ds.ink : Ds.inkDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'نشست موبایل دادگر — احراز هویت با توکن Bearer',
                        style: TextStyle(
                          fontFamily: Ds.fontFamily,
                          fontSize: 12,
                          height: 1.6,
                          color: light ? Ds.inkSoft : Ds.inkSoftDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Ds.s8),
                const DsPill('حساب فعال', tone: DsPillTone.success),
              ],
            ),
          ),
          const SizedBox(height: Ds.s16),
          // ── بخش امنیت — سوییچ بیومتریک M1 روی ردیف نسل S ──
          const DsSectionHeader('امنیت'),
          DsTile(
            icon: Icons.fingerprint,
            title: 'ورود با بیومتریک',
            subtitle: 'بازکردن اپ با اثر انگشت یا چهره',
            onTap: () => _toggleLock(!lock.enabled),
            trailing: Switch(
              value: lock.enabled,
              onChanged: (value) => _toggleLock(value),
            ),
          ),
          const SizedBox(height: Ds.s24),
          DsButton(
            'خروج از این دستگاه',
            onPressed: _logout,
            tone: DsButtonTone.danger,
            expand: true,
          ),
          const SizedBox(height: Ds.s8),
          Text(
            '«خروج از همه‌ی دستگاه‌ها» در فازهای بعدی پروفایل کامل می‌شود',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 11.5,
              height: 1.6,
              color: light ? Ds.inkFaint : Ds.inkFaintDark,
            ),
          ),
        ],
      ),
    );
  }
}
