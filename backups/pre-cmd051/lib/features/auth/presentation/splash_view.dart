import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// اسپلش کوتاه هنگام بازیابی نشست از ذخیره‌ی امن
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gavel, size: 64, color: DadgarTokens.primary),
            const SizedBox(height: DadgarTokens.s16),
            const Text(
              'دادگر',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: DadgarTokens.primary,
              ),
            ),
            const SizedBox(height: DadgarTokens.s24),
            const CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
