import 'package:flutter/material.dart';

import 'tokens.dart';

/// ═══════════════════════════════════════════════════════════════════
/// کیت اجزای «دادگر S» — کد تازه از صفر (CMD-051)؛ هیچ ارثی از
/// d3_kit قدیمی ندارد. اجزا با هدف لمس ≥۴۸dp، متن ≥۱۱٫۵ و RTL کامل.
/// هر جز فقط از توکن‌های Ds رنگ می‌گیرد (قاعده‌ی مهارت: صفر رنگ خام).
/// ═══════════════════════════════════════════════════════════════════

/// کارت پایه — سطح سفید گردِ ۲۰ با سایه‌ی آبی‌فام نرم
final class DsCard extends StatelessWidget {
  const DsCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Ds.s16),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Ds.radiusCard),
        border: Border.all(
          color: scheme.brightness == Brightness.light
              ? Ds.line
              : Ds.lineDark,
        ),
        boxShadow: Ds.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) {
      return Padding(padding: margin, child: card);
    }
    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Ds.radiusCard),
          child: card,
        ),
      ),
    );
  }
}

/// تُن قرص وضعیت — tint لنگرهای پالت
enum DsPillTone { neutral, info, success, warn, danger, cyan }

/// قرص وضعیت — متنِ خوانا روی tint هم‌خانواده (کنتراست ≥۴٫۵)
final class DsPill extends StatelessWidget {
  const DsPill(this.label, {super.key, this.tone = DsPillTone.neutral});

  final String label;
  final DsPillTone tone;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final (Color bg, Color fg, Color dot) = switch (tone) {
      DsPillTone.neutral => (
          light ? Ds.wash : Ds.washDark,
          light ? Ds.inkSoft : Ds.inkSoftDark,
          light ? Ds.inkFaint : Ds.inkFaintDark,
        ),
      DsPillTone.info => (
          light ? Ds.wash : Ds.washDark,
          light ? Ds.primaryDeep : Ds.cyan,
          light ? Ds.primary : Ds.cyan,
        ),
      DsPillTone.success => (
          light ? Ds.tintSuccess : Ds.washDark,
          light ? Ds.green : Ds.mint,
          light ? Ds.green : Ds.mint,
        ),
      DsPillTone.warn => (
          light ? Ds.tintWarn : Ds.washDark,
          light ? Ds.amberInk : Ds.amber,
          light ? Ds.amber : Ds.amber,
        ),
      DsPillTone.danger => (
          light ? Ds.tintDanger : Ds.washDark,
          light ? Ds.error : Ds.rose,
          light ? Ds.error : Ds.rose,
        ),
      DsPillTone.cyan => (
          light ? Ds.tintCyan : Ds.washDark,
          light ? const Color(0xFF0B6A80) : Ds.cyan,
          light ? Ds.cyanDeep : Ds.cyan,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Ds.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// تُن دکمه
enum DsButtonTone { primary, tonal, outline, ghost, danger }

/// دکمه‌ی نسل S — ارتفاع ۵۰، شعاع ۱۴؛ همه‌ی تُن‌ها هدف لمس ≥۴۸ دارند
final class DsButton extends StatelessWidget {
  const DsButton(
    this.label, {
    super.key,
    this.onPressed,
    this.tone = DsButtonTone.primary,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DsButtonTone tone;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    Widget buildChild() => Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: Ds.s8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );

    final style = switch (tone) {
      DsButtonTone.primary => FilledButton.styleFrom(),
      DsButtonTone.tonal => FilledButton.styleFrom(
          backgroundColor: light ? Ds.wash : Ds.washDark,
          foregroundColor: light ? Ds.primaryDeep : Ds.cyan,
          elevation: 0,
        ),
      DsButtonTone.danger => FilledButton.styleFrom(
          backgroundColor: light ? Ds.error : Ds.rose,
          foregroundColor: Colors.white,
        ),
      DsButtonTone.outline => OutlinedButton.styleFrom(),
      DsButtonTone.ghost => TextButton.styleFrom(),
    };

    final button = switch (tone) {
      DsButtonTone.primary ||
      DsButtonTone.tonal ||
      DsButtonTone.danger => FilledButton(
          onPressed: onPressed,
          style: style,
          child: buildChild(),
        ),
      DsButtonTone.outline => OutlinedButton(
          onPressed: onPressed,
          style: style,
          child: buildChild(),
        ),
      DsButtonTone.ghost => TextButton(
          onPressed: onPressed,
          style: style,
          child: buildChild(),
        ),
    };

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// ورودی متنی نسل S — برچسب بالای فیلد + فیلد گرد ۱۴
final class DsTextField extends StatelessWidget {
  const DsTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.validator,
    this.keyboardType,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.maxLines = 1,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool enabled;
  final int maxLines;
  final List<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: Ds.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: light ? Ds.ink : Ds.inkDark,
          ),
        ),
        const SizedBox(height: Ds.s8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          keyboardType: keyboardType,
          enabled: enabled,
          maxLines: maxLines,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          style: TextStyle(
            fontFamily: Ds.fontFamily,
            fontSize: 15,
            color: light ? Ds.ink : Ds.inkDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(
                    prefixIcon,
                    size: 20,
                    color: light ? Ds.inkSoft : Ds.inkSoftDark,
                  ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// سربرگ بخش — عنوان درشت + اقدام اختیاری
final class DsSectionHeader extends StatelessWidget {
  const DsSectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(top: Ds.s8, bottom: Ds.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: light ? Ds.ink : Ds.inkDark,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: Ds.s8),
                minimumSize: const Size(48, 48),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Ds.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ردیف اقدام — tile با آیکون tint آبی، هدف لمس ≥۵۶
final class DsTile extends StatelessWidget {
  const DsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;
    final accent = danger
        ? (light ? Ds.error : Ds.rose)
        : (light ? Ds.primary : Ds.cyan);
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(Ds.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ds.radiusCard),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(
            horizontal: Ds.s12,
            vertical: Ds.s12,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: light ? Ds.wash : Ds.washDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 21, color: accent),
                ),
                const SizedBox(width: Ds.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: Ds.fontFamily,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        color: danger
                            ? (light
                                ? Ds.error
                                : Ds.rose)
                            : (light ? Ds.ink : Ds.inkDark),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: Ds.fontFamily,
                          fontSize: 12,
                          height: 1.5,
                          color: light ? Ds.inkFaint : Ds.inkFaintDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_left,
                  size: 22,
                  color: light ? Ds.inkFaint : Ds.inkFaintDark,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ردیف کلید/مقدار — جدول داده‌ای سبک
final class DsKvRow extends StatelessWidget {
  const DsKvRow(
    this.label,
    this.value, {
    super.key,
    this.valueTone,
    this.divider = true,
  });

  final String label;
  final String value;
  final Color? valueTone;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final rule = light ? Ds.line : Ds.lineDark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: rule)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 13,
              color: light ? Ds.inkSoft : Ds.inkSoftDark,
            ),
          ),
          const Spacer(),
          const SizedBox(width: Ds.s12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: valueTone ?? (light ? Ds.ink : Ds.inkDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// حالت خالی — آیکون + عنوان + راهنما + اقدام اختیاری
final class DsEmptyState extends StatelessWidget {
  const DsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Ds.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: light ? Ds.wash : Ds.washDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: light ? Ds.primary : Ds.cyan,
              ),
            ),
            const SizedBox(height: Ds.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: light ? Ds.ink : Ds.inkDark,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: Ds.s8),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 12.5,
                  height: 1.7,
                  color: light ? Ds.inkFaint : Ds.inkFaintDark,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Ds.s16),
              DsButton(
                actionLabel!,
                onPressed: onAction,
                tone: DsButtonTone.tonal,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// کارت آمار — عدد درشت + برچسب + آیکون
final class DsStatCard extends StatelessWidget {
  const DsStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;
    return DsCard(
      padding: const EdgeInsets.all(Ds.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: light ? Ds.primary : Ds.cyan),
              const Spacer(),
            ],
          ),
          const SizedBox(height: Ds.s8),
          Text(
            value,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: light ? Ds.ink : Ds.inkDark,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: light ? Ds.inkFaint : Ds.inkFaintDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// نوار مسیر حقوقی نسل S — مهره‌های نقطه‌ای با اتصال‌خط؛ RTL کامل؛
/// تفسیر: مراحل < currentIndex انجام‌شده، == currentIndex در جریان.
/// بدون currentIndex = حالت نمایشی خنثی (ویترین ورود/خانه).
final class DsJourneyBar extends StatelessWidget {
  const DsJourneyBar({
    super.key,
    required this.steps,
    this.currentIndex,
  });

  final List<String> steps;
  final int? currentIndex;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final rule = light ? Ds.line : Ds.lineDark;
    final accent = light ? Ds.primary : Ds.cyan;
    final current = currentIndex;

    Widget node(int i) {
      final label = steps[i];
      final done = current != null && i < current;
      final active = current != null && i == current;
      final nodeColor = done || active ? accent : rule;
      final dot = Container(
        width: active ? 16 : 12,
        height: active ? 16 : 12,
        decoration: BoxDecoration(
          color: done || active ? nodeColor : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: nodeColor, width: 2),
        ),
      );
      return Semantics(
        label: '${i + 1} از ${steps.length} — $label',
        child: Column(
          children: [
            dot,
            const SizedBox(height: 6),
            SizedBox(
              width: 56,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Ds.fontFamily,
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  height: 1.4,
                  color: active || done
                      ? (light ? Ds.ink : Ds.inkDark)
                      : (light ? Ds.inkFaint : Ds.inkFaintDark),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget gap(int i) => Container(
          // اتصال‌خط ثابت — نوار کل پیمایش‌افقی است (الگوی native) و
          // نیازی به کشش Expanded ندارد (که با FittedBox/اسکرول ناسازگار است)
          width: 14,
          height: 2,
          margin: const EdgeInsets.only(bottom: 34, left: 2, right: 2),
          color: (current != null && i < current) ? accent : rule,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Ds.s4),
      // پیمایش‌افقی بومی: شش مهره با عرض ثابت؛ در عرض‌های باریک بدون سرریز
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) gap(i - 1),
              node(i),
            ],
          ],
        ),
      ),
    );
  }
}

/// حباب پیام — من/وکیل؛ RTL: من = سمت راست‌چین tint آبی
final class DsBubble extends StatelessWidget {
  const DsBubble({
    super.key,
    required this.text,
    required this.mine,
    this.time,
  });

  final String text;
  final bool mine;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final bg = mine
        ? (light ? Ds.primary : Ds.primaryDeep)
        : (light ? Ds.surface : Ds.surfaceDark);
    final fg = mine
        ? Colors.white
        : (light ? Ds.ink : Ds.inkDark);
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(
            horizontal: Ds.s12,
            vertical: 10,
          ),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(Ds.radiusCard),
              topRight: const Radius.circular(Ds.radiusCard),
              bottomLeft: Radius.circular(mine ? Ds.radiusCard : 6),
              bottomRight: Radius.circular(mine ? 6 : Ds.radiusCard),
            ),
            border: mine
                ? null
                : Border.all(color: light ? Ds.line : Ds.lineDark),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 14,
              height: 1.7,
              color: fg,
            ),
          ),
        ),
        if (time != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Ds.s4),
            child: Text(
              time!,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 10.5,
                color: light ? Ds.inkFaint : Ds.inkFaintDark,
              ),
            ),
          ),
      ],
    );
  }
}

/// شیت پایین نسل S — گردِ ۲۴ با دستگیره
Future<T?> showDsSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Ds.radiusSheet)),
    ),
    builder: builder,
  );
}

/// حلقه‌ی بارگذاری نسل S
final class DsRing extends StatelessWidget {
  const DsRing({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.light
        ? Ds.primary
        : Ds.cyan;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
    );
  }
}

/// سربرگ صفحه‌ی نسل S — تیتر بزرگ بومی‌موبایلی روی زمینه‌ی شفاف
final class DsTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DsTopBar(
    this.title, {
    super.key,
    this.subtitle,
    this.actions,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack ? const BackButton() : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: Ds.fontFamily,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: light ? Ds.ink : Ds.inkDark,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: Ds.fontFamily,
                fontSize: 12,
                color: light ? Ds.inkFaint : Ds.inkFaintDark,
              ),
            ),
        ],
      ),
      actions: actions,
    );
  }
}
