import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// صفحه‌ی نمونه‌ی M0 — اسکلت + پالت نهایی D-3 (سرمه‌ای؛ تایید مدیر 2026-10-29)
/// این صفحه پس از شروع M1 با صفحه‌ی خانه‌ی واقعی جایگزین می‌شود.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دادگر'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DadgarTokens.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gavel, size: 64, color: DadgarTokens.primary),
              const SizedBox(height: DadgarTokens.s16),
              const Text(
                'نسخه M0 — اسکلت معماری Flutter',
                style: TextStyle(
                  fontSize: 16,
                  color: DadgarTokens.textSecondary,
                ),
              ),
              const SizedBox(height: DadgarTokens.s8),
              const Text(
                'مرجع الزامی: DOC-04 نسخه 2.0 — تایید مدیر 2026-10-29',
                style: TextStyle(
                  fontSize: 12,
                  color: DadgarTokens.textSecondary,
                ),
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
    );
  }
}

class _PaletteCard extends StatelessWidget {
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
        border: Border.all(color: DadgarTokens.textSecondary.withValues(alpha: 0.2)),
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
