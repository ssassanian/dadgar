import 'package:flutter/material.dart';

/// توکن‌های دیزاین مستقل موبایل دادگر — بدون هیچ ارثی از وب (DOC-04 §۷)
/// پالت نهایی — انتخاب مدیر «سرمه‌ای» (2026-10-29؛ تصمیم D-3 بسته شد)
abstract final class DadgarTokens {
  // ── رنگ‌ها (پالت نهایی D-3 — مسیر سرمه‌ای) ──
  /// پس‌زمینه‌ی روشن گرم
  static const Color background = Color(0xFFFAF7F2);

  /// سطح کارت‌ها
  static const Color surface = Color(0xFFFFFFFF);

  /// آبی-سرمه‌ای حقوقی (رنگ اصلی برند)
  static const Color primary = Color(0xFF14345B);

  /// رنگ متن روی primary
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// سبز تایید (accent)
  static const Color accent = Color(0xFF2E7D32);

  /// متن اصلی
  static const Color textPrimary = Color(0xFF1A1C1E);

  /// متن ثانویه
  static const Color textSecondary = Color(0xFF5A5F66);

  /// خطا
  static const Color error = Color(0xFFB3261E);

  // ── توکن‌های سطح D-3 از `mobile/design-preview/app.css` (CMD-045 —
  //    ترجمه‌ی وفادار مقادیر پالت قفل‌شده؛ صفر رنگ خارج از پالت) ──

  /// لبه‌ی کارت روی کاغذ گرم — `--border`
  static const Color cardBorder = Color(0xFFE6DFD4);

  /// خط ردیف (یک پله روشن‌تر از لبه) — `--rule`
  static const Color rowRule = Color(0xFFF0EBE2);

  /// لبه‌ی ورودی‌ها/حالت خالی — `--control`
  static const Color control = Color(0xFFD8D0C3);

  /// چاه داخلی/پیام گفتگو — `--raised`
  static const Color raised = Color(0xFFF3EFE8);

  /// روشن‌ترین خاکستری با کنتراست ۴٫۵:۱ — `--faint`
  static const Color textFaint = Color(0xFF6B6F76);

  /// پس‌زمینه‌ی قرص خنثی — `--pill-neutral-bg`
  static const Color pillNeutralBg = Color(0xFFEFE9E0);

  /// متن قرص خنثی — `--pill-neutral-ink`
  static const Color pillNeutralInk = Color(0xFF4A4D52);

  /// پس‌زمینه‌ی قرص داده (سرمه‌ای خیلی کم‌رنگ) — `--pill-data-bg`
  static const Color pillDataBg = Color(0xFFE7ECF4);

  // ── فاصله‌ها (مقیاس ۴) ──
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;

  /// شعاع گوشه‌ها
  static const double radius = 12;

  /// فونت فارسی باندل‌شده (DOC-04 §۷) — هیچ وابستگی به وب
  static const String fontFamily = 'Vazirmatn';

  static ThemeData lightTheme() {
    final scheme = ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      error: error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        centerTitle: true,
        elevation: 0,
      ),
    );
  }
}
