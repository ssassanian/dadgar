import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../design/tokens.dart';

/// قفل اپ — وقتی کاربر قفل بیومتریک را فعال کرده باشد (DOC-04 §۸)
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

final class _LockScreenState extends ConsumerState<LockScreen> {
  bool _checking = false;

  Future<void> _unlock() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final biometric = ref.read(biometricAuthProvider);
      final ok = await biometric.authenticate(
        reason: 'برای بازکردن دادگر احراز هویت کنید',
      );
      if (!mounted) return;
      if (ok) {
        ref.read(appLockControllerProvider.notifier).unlock();
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('احراز هویت بیومتریک انجام نشد'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _signOutInstead() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DadgarTokens.s24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline,
                    size: 64, color: DadgarTokens.primary),
                const SizedBox(height: DadgarTokens.s16),
                const Text(
                  'دادگر قفل است',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: DadgarTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: DadgarTokens.s8),
                const Text(
                  'برای ادامه، هویت خود را تایید کنید',
                  style: TextStyle(
                    fontSize: 13,
                    color: DadgarTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: DadgarTokens.s24),
                FilledButton.icon(
                  onPressed: _checking ? null : _unlock,
                  style: FilledButton.styleFrom(
                    backgroundColor: DadgarTokens.primary,
                    foregroundColor: DadgarTokens.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DadgarTokens.s24,
                      vertical: DadgarTokens.s16,
                    ),
                  ),
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DadgarTokens.onPrimary,
                          ),
                        )
                      : const Icon(Icons.fingerprint),
                  label: const Text('بازکردن با بیومتریک'),
                ),
                const SizedBox(height: DadgarTokens.s12),
                TextButton(
                  onPressed:
                      _checking ? null : () => _signOutInstead(),
                  child: const Text('خروج از حساب و ورود با رمز'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
