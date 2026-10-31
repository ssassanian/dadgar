import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../design/tokens.dart';
import '../auth/application/auth_controller.dart';
import '../auth/application/session_controller.dart';

/// صفحه‌ی خانه M1 — خوش‌آمد نشست + وضعیت فاز + پیش‌نمایش پالت D-3
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider);
    final username = switch (status) {
      Authenticated(:final username) => username,
      _ => 'کاربر دادگر',
    };
    // M6 (CMD-028) — کشف نقش نشست: کارت پنل مدیریت فقط برای مدیر
    final meAsync = ref.watch(sessionMeProvider);
    final isAdmin = meAsync.value?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('دادگر'),
        actions: [
          IconButton(
            tooltip: 'پروفایل',
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DadgarTokens.s24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(DadgarTokens.s16),
                  decoration: BoxDecoration(
                    color: DadgarTokens.primary,
                    borderRadius:
                        BorderRadius.circular(DadgarTokens.radius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سلام، $username',
                        style: const TextStyle(
                          color: DadgarTokens.onPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: DadgarTokens.s8),
                      const Text(
                        'نسخه M6 — پنل مدیریتی، PDF فاکتور و اسکلت درگاه (CMD-028)',
                        style: TextStyle(
                          color: DadgarTokens.onPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DadgarTokens.s16),
                _StatusChip(
                  icon: Icons.verified_user_outlined,
                  label: 'توکن در Keystore/Keychain ذخیره می‌شود (§۸)',
                ),
                const SizedBox(height: DadgarTokens.s8),
                const _StatusChip(
                  icon: Icons.sync_alt,
                  label: 'اتصال زنده به سرور: در انتظار حکم D-6',
                ),
                const SizedBox(height: DadgarTokens.s16),
                _ActionCard(
                  icon: Icons.folder_outlined,
                  title: 'پرونده‌های من',
                  subtitle: 'فهرست و جزئیات پرونده‌ها (M2)',
                  onTap: () => context.go('/cases'),
                ),
                const SizedBox(height: DadgarTokens.s8),
                _ActionCard(
                  icon: Icons.post_add_outlined,
                  title: 'ثبت پرونده جدید',
                  subtitle: 'دسته، عنوان و توضیحات (M2)',
                  onTap: () => context.go('/cases/new'),
                ),
                const SizedBox(height: DadgarTokens.s8),
                _ActionCard(
                  icon: Icons.calendar_month,
                  title: 'رزرو نوبت',
                  subtitle: 'تقویم شمسی + بازه‌های آزاد (M3)',
                  onTap: () => context.go('/appointments'),
                ),
                const SizedBox(height: DadgarTokens.s8),
                _ActionCard(
                  icon: Icons.event_note_outlined,
                  title: 'نوبت‌های من',
                  subtitle: 'وضعیت نوبت‌ها و لغو (M3)',
                  onTap: () => context.go('/appointments/mine'),
                ),
                const SizedBox(height: DadgarTokens.s8),
                _ActionCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'صورتحساب‌ها و پرداخت',
                  subtitle: 'فاکتورهای من، مبلغ و وضعیت (M4)',
                  onTap: () => context.go('/invoices'),
                ),
                const SizedBox(height: DadgarTokens.s8),
                if (isAdmin) ...[
                  _ActionCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'پنل مدیریت مالی',
                    subtitle: 'صدور فاکتور، ثبت پرداخت و بازکردن (M6)',
                    onTap: () => context.go('/admin/billing'),
                  ),
                  const SizedBox(height: DadgarTokens.s8),
                ],
                _ActionCard(
                  icon: Icons.support_agent_outlined,
                  title: 'تیکت‌های پشتیبانی',
                  subtitle: 'ثبت تیکت و پیگیری پاسخ (M5)',
                  onTap: () => context.go('/tickets'),
                ),
                const SizedBox(height: DadgarTokens.s8),
                _ActionCard(
                  icon: Icons.forum_outlined,
                  title: 'گفتگو با وکیل',
                  subtitle: 'گفتگوی پرونده‌های تخصیص‌یافته (M5)',
                  onTap: () => context.go('/threads'),
                ),
                const SizedBox(height: DadgarTokens.s8),
                _ActionCard(
                  icon: Icons.folder_shared_outlined,
                  title: 'گاوصندوق اسناد',
                  subtitle: 'بارگذاری از دوربین، دانلود و حذف (M5)',
                  onTap: () => context.go('/documents'),
                ),
                const SizedBox(height: DadgarTokens.s24),
                _PaletteCard(
                  label: 'سرمه‌ای حقوقی (primary)',
                  hex: '#14345B',
                  color: DadgarTokens.primary,
                  onColor: DadgarTokens.onPrimary,
                ),
                const SizedBox(height: DadgarTokens.s12),
                _PaletteCard(
                  label: 'روشن گرم (background)',
                  hex: '#FAF7F2',
                  color: DadgarTokens.background,
                  onColor: DadgarTokens.textPrimary,
                ),
                const SizedBox(height: DadgarTokens.s12),
                _PaletteCard(
                  label: 'سبز تایید (accent)',
                  hex: '#2E7D32',
                  color: DadgarTokens.accent,
                  onColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DadgarTokens.s12,
        vertical: DadgarTokens.s8,
      ),
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DadgarTokens.accent),
          const SizedBox(width: DadgarTokens.s8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: DadgarTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// کارت اقدام خانه — ورود به ماژول‌ها (M3: نوبت‌دهی)
final class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DadgarTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        side: BorderSide(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DadgarTokens.s16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: DadgarTokens.primary),
              const SizedBox(width: DadgarTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DadgarTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left,
                size: 20,
                color: DadgarTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.label,
    required this.hex,
    required this.color,
    required this.onColor,
  });

  final String label;
  final String hex;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DadgarTokens.s16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(
          color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: onColor, fontWeight: FontWeight.w500),
          ),
          Text(
            hex,
            style: TextStyle(color: onColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
