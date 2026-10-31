import 'package:flutter/material.dart';

import 'tokens.dart';

/// عنصر امضایی دادگر — نوار «مسیر پرونده» (CMD-037 طراحی، CMD-040 کد)
///
/// چرخه‌ی واقعی پرونده بر پایه‌ی قرارداد سرور (CMD-003): پنج وضعیت
/// waiting → proposing → assigned → running → done. هیچ مرحله‌ای
/// جعلی «انجام‌شده» نشان داده نمی‌شود؛ تا اتصال زنده (D-6) نوار خنثی است.
class DadgarJourneyBar extends StatelessWidget {
  const DadgarJourneyBar({
    super.key,
    required this.steps,
    this.current,
  });

  /// برچسب مراحل — به ترتیب چرخه (اولین = آغاز پرونده)
  final List<String> steps;

  /// اندیس مرحله‌ی جاری — null یعنی هنوز داده‌ی واقعی در دسترس نیست
  final int? current;

  @override
  Widget build(BuildContext context) {
    final lineColor =
        DadgarTokens.textSecondary.withValues(alpha: 0.18);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      if (i > 0)
                        Expanded(
                          child: Container(height: 2, color: lineColor),
                        )
                      else
                        const Spacer(),
                      _JourneyDot(
                        reached: current != null && current! >= i,
                        current: current == i,
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(height: 2, color: lineColor),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 30,
                  child: Text(
                    steps[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: current == i
                          ? DadgarTokens.primary
                          : DadgarTokens.textSecondary,
                      fontWeight:
                          current == i ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

final class _JourneyDot extends StatelessWidget {
  const _JourneyDot({required this.reached, required this.current});

  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final border = DadgarTokens.textSecondary.withValues(alpha: 0.35);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current
            ? DadgarTokens.primary
            : reached
                ? DadgarTokens.primary.withValues(alpha: 0.35)
                : DadgarTokens.surface,
        border: Border.all(
          color: current ? DadgarTokens.primary : border,
          width: current ? 0 : 1.5,
        ),
      ),
    );
  }
}
