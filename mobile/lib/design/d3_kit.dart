/// جعبه‌ابزار D-3 دادگر — ترجمه‌ی وفادار `mobile/design-preview/app.css`
/// (CMD-045؛ طرح تاییدشده‌ی CMD-037/041 — گالری `design-preview`)
///
/// دامنه: فقط داخل اپ موبایل (`lib/`) — صفر فایل مشترک با وب (ماده ۹).
/// هر ویجت با کلاس هم‌نام CSS ردیف‌بندی شده است؛ صفر رنگ/فونت خارج از
/// پالت D-3. قواعد خود طرح از تولد رعایت می‌شود (CMD-042 F4/F5):
/// لمس ≥۴۸dp و برچسب ≥۱۲sp.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// کارت/پنل — کلاس `.panel`: سطح سفید، لبه‌ی کاغذی، شعاع ۱۲
final class DadgarPanel extends StatelessWidget {
  const DadgarPanel({
    super.key,
    required this.child,
    this.head,
    this.trailing,
    this.padding = const EdgeInsets.all(DadgarTokens.s16),
  });

  /// سربرگ پنل — متن ۱۵px/۶۰۰ (کلاس `.panel-head h2`)
  final String? head;

  /// دنباله‌ی سربرگ — قرص/لینک (سمت مقابل عنوان)
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: DadgarTokens.surface,
        borderRadius: BorderRadius.circular(DadgarTokens.radius),
        border: Border.all(color: DadgarTokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (head != null)
            Padding(
              padding: const EdgeInsets.only(bottom: DadgarTokens.s12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      head!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: DadgarTokens.textPrimary,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// قرص وضعیت — کلاس `.pill` (ارتفاع ۲۲، قطر کامل، ۱۱px/۵۰۰)
enum DadgarPillVariant { neutral, data, positive }

final class DadgarPill extends StatelessWidget {
  const DadgarPill(this.label, {super.key, this.variant = DadgarPillVariant.neutral});

  final String label;
  final DadgarPillVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = switch (variant) {
      DadgarPillVariant.neutral => (DadgarTokens.pillNeutralBg, DadgarTokens.pillNeutralInk),
      DadgarPillVariant.data => (DadgarTokens.pillDataBg, DadgarTokens.primary),
      DadgarPillVariant.positive => (DadgarTokens.pillPositiveBg, DadgarTokens.pillPositiveInk),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: ink,
          height: 1,
        ),
      ),
    );
  }
}

/// چیپ فیلتر — کلاس `.chip` با تصحیح F4: لمس ≥۴۸dp (طرح خودش ≥۴۴ خواسته بود)
final class DadgarChip extends StatelessWidget {
  const DadgarChip(
    this.label, {
    super.key,
    required this.selected,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// حالت ناتوان (بازه‌ی پر/گذشته) — متن کم‌رنگ، بدون تپ (CMD-046)
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? DadgarTokens.textPrimary : DadgarTokens.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? DadgarTokens.textPrimary : DadgarTokens.control,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 40,
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                height: 1,
                color: !enabled
                    ? DadgarTokens.textSecondary.withValues(alpha: 0.5)
                    : selected
                        ? DadgarTokens.surface
                        : DadgarTokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ردیف دوخطی — کلاس `.row` (کمینه ۶۴، خط ردیف بین ردیف‌ها)
///
/// `title` = `.r-t1` (۱۴px/۶۰۰ با سه‌نقطه)، `subtitle` = `.r-t2`
/// (۱۲٫۵px ثانویه با سه‌نقطه)، `side` = `.r-side` (معمولاً قرص)،
/// و فلش برگشت RTL هنگام `onTap`.
final class DadgarListRow extends StatelessWidget {
  const DadgarListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.side,
    this.onTap,
    this.minHeight = 64,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final Widget? side;
  final VoidCallback? onTap;
  final double minHeight;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: DadgarTokens.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: DadgarTokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (side != null) ...[
              const SizedBox(width: 12),
              side!,
            ],
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_left, size: 18, color: DadgarTokens.textFaint),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// جداکننده‌ی ردیف‌ها — خط `--rule` (فراخوان بین ردیف‌ها می‌گذارد)
final class DadgarRowRule extends StatelessWidget {
  const DadgarRowRule({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: DadgarTokens.rowRule);
  }
}

/// ردیف کلید-مقدار — کلاس `.kv` (کلید ۱۳px ثانویه، مقدار ۱۳٫۵px)
final class DadgarKvRow extends StatelessWidget {
  const DadgarKvRow(this.keyLabel, this.value, {super.key});

  final String keyLabel;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            keyLabel,
            style: const TextStyle(
              fontSize: 13,
              color: DadgarTokens.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: DadgarTokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// جداکننده‌ی kv — خط `--rule`
final class DadgarKvRule extends StatelessWidget {
  const DadgarKvRule({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: DadgarTokens.rowRule);
  }
}

/// دکمه‌ی شبح تمام‌عرض — کلاس `.btn.ghost.full` (لمس ۴۴+)
final class DadgarGhostButton extends StatelessWidget {
  const DadgarGhostButton(
    this.label, {
    super.key,
    this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// حالت مخرب (خروج/حذف) — لبه و متن قرمز D-3 (CMD-046)
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DadgarTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: destructive ? DadgarTokens.error : DadgarTokens.control,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: destructive ? DadgarTokens.error : DadgarTokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// دکمه‌ی اصلی تمام‌عرض — کلاس `.btn.full` (نزدیک‌سیاه، لمس ۴۴+)
final class DadgarPrimaryButton extends StatelessWidget {
  const DadgarPrimaryButton(this.label, {super.key, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null
          ? DadgarTokens.control
          : DadgarTokens.textPrimary,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: DadgarTokens.surface,
            ),
          ),
        ),
      ),
    );
  }
}

/// وضعیت خالی صادقانه — کلاس `.empty` (کادر خط‌چین، متن ۱۳px ثانویه)
final class DadgarEmptyBox extends StatelessWidget {
  const DadgarEmptyBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: DadgarTokens.control),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          height: 1.8,
          color: DadgarTokens.textSecondary,
        ),
      ),
    );
  }
}

/// لینک کارت — کلاس `.card-link` (۱۲px ثانویه با فلش RTL)
final class DadgarCardLink extends StatelessWidget {
  const DadgarCardLink(this.label, {super.key, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: DadgarTokens.textSecondary,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_left, size: 12, color: DadgarTokens.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// نوار بالای صفحه — کلاس `.topbar` (۴۸px، عنوان ۱۶/۶۰۰ + زیرنویس ۱۱ روشن)
final class DadgarTopBar extends StatelessWidget {
  const DadgarTopBar({super.key, required this.title, this.subtitle, this.leading});

  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (leading != null) leading!,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: DadgarTokens.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: DadgarTokens.textFaint,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// جعبه‌ی پیام وکیل — کلاس `.lw-msg` (زمینه‌ی raised، ۱۲٫۵px)
final class DadgarLawyerMessage extends StatelessWidget {
  const DadgarLawyerMessage({super.key, required this.body, this.meta});

  final String body;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DadgarTokens.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '«$body»',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.9,
              color: DadgarTokens.textPrimary,
            ),
          ),
          if (meta != null && meta!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                meta!,
                style: const TextStyle(
                  fontSize: 11,
                  color: DadgarTokens.textFaint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
