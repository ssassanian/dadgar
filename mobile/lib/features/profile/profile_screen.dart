import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../design/tokens.dart';
import '../auth/application/auth_controller.dart';

/// پروفایل M1 — نشست جاری + قفل بیومتریک + خروج (DOC-04 §۸)
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('پروفایل'),
        leading: IconButton(
          tooltip: 'بازگشت',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(DadgarTokens.s16),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: DadgarTokens.primary,
            child: Text(
              username.isNotEmpty ? username.characters.first : 'د',
              style: const TextStyle(
                color: DadgarTokens.onPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: DadgarTokens.s12),
          Text(
            username,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DadgarTokens.textPrimary,
            ),
          ),
          const SizedBox(height: DadgarTokens.s4),
          const Text(
            'نشست موبایل دادگر — احراز هویت با توکن Bearer',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: DadgarTokens.textSecondary),
          ),
          const SizedBox(height: DadgarTokens.s24),
          Container(
            decoration: BoxDecoration(
              color: DadgarTokens.surface,
              borderRadius: BorderRadius.circular(DadgarTokens.radius),
              border: Border.all(
                color: DadgarTokens.textSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: SwitchListTile(
              value: lock.enabled,
              onChanged: (value) => _toggleLock(value),
              secondary: const Icon(Icons.fingerprint,
                  color: DadgarTokens.primary),
              title: const Text('قفل اپ با بیومتریک'),
              subtitle: const Text(
                'هر بار بازکردن اپ، اثر انگشت/Face خواسته می‌شود (M1)',
              ),
            ),
          ),
          const SizedBox(height: DadgarTokens.s24),
          FilledButton.tonalIcon(
            onPressed: () => _logout(),
            style: FilledButton.styleFrom(
              foregroundColor: DadgarTokens.error,
              padding: const EdgeInsets.symmetric(
                vertical: DadgarTokens.s16,
              ),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('خروج از این دستگاه'),
          ),
          const SizedBox(height: DadgarTokens.s8),
          const Text(
            '«خروج از همه‌ی دستگاه‌ها» در فازهای بعدی پروفایل کامل می‌شود',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: DadgarTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}
