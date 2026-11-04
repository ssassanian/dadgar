import 'package:flutter/material.dart';

import '../../../design/tokens.dart';

/// اسپلش «دادگر S» — تمام‌آبی برند با مونوگرام سفید (CMD-051؛ کد تازه)
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Ds.primary),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Ds.radiusCard),
                  boxShadow: Ds.cardShadow,
                ),
                child: const Text(
                  'د',
                  style: TextStyle(
                    color: Ds.primary,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: Ds.s20),
              const Text(
                'دادگر',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'همراه پرونده‌ی شما — از مشاوره تا صدور رأی',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: Ds.s32),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Ds.cyan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
