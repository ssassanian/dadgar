import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../design/tokens.dart';
import '../auth/application/auth_controller.dart';

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
                        'نسخه M1 فاز ۱ — اسکلت احراز هویت، خانه و پروفایل',
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
