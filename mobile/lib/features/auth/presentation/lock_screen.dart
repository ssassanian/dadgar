import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../design/ds_kit.dart';
import '../../../design/tokens.dart';

/// قفل اپ «دادگر S» — کد تازه از صفر (CMD-051)؛ منطق عین DOC-04 §۸
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
      body: Column(
        children: [
          // ── بلوک آبی برند با قفل ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 56),
            decoration: const BoxDecoration(
              color: Ds.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(Ds.radiusSheet),
                bottomRight: Radius.circular(Ds.radiusSheet),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: Ds.s32),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: Ds.s16),
                  const Text(
                    'دادگر قفل است',
                    style: TextStyle(
                      fontFamily: Ds.fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'برای ادامه، هویت خود را تایید کنید',
                    style: TextStyle(
                      fontFamily: Ds.fontFamily,
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── برگه‌ی اقدام ──
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.brightness ==
                          Brightness.light
                      ? Ds.bg
                      : Ds.bgDark,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Ds.radiusSheet),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Ds.s24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DsButton(
                          'بازکردن با بیومتریک',
                          onPressed: _checking ? null : _unlock,
                          expand: true,
                          icon: Icons.fingerprint,
                        ),
                        const SizedBox(height: Ds.s12),
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
            ),
          ),
        ],
      ),
    );
  }
}
