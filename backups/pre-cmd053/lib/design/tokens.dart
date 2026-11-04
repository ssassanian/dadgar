import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════
/// توکن‌های دیزاین «دادگر S» — نسل تازه‌ی تجربه‌ی موبایل (CMD-051)
///
/// حکم مدیر (CMD-050 → اجرا در CMD-051): طراحی موبایل از صفر و
/// موبایل‌بومی؛ تنها لایه‌ی مشترک با نسخه‌ی وب «رنگ‌بندی برند» است.
/// یعنی لنگرهای رنگی زیر عین مقادیر صفحه‌ی زنده‌ی وب
/// (web/dynamic/index.html) هستند و بقیه‌ی رنگ‌ها tint/shade مستقیم
/// همین لنگرهاست — صفر رنگ از نسل قبلی (کاغذ گرم/سرمه‌ای/سبز D-3)
/// و صفر عنصر بصری وب (Lalezar/گرادیان هیرو) بازنویسی نشده است.
///
/// قواعد مهارت ui-ux-pro-max (پرس‌وجوی محصول Legal Services با
/// rtl_level=full): متن ≥۱۲، هدف لمس ≥۴۸، تم روشن+تاریک، فقط
/// فونت باندل‌شده‌ی Vazirmatn (بدون Lalezar وب).
/// ═══════════════════════════════════════════════════════════════════
abstract final class Ds {
  // ── لنگرهای پالت برند — عین وب؛ تنها لایه‌ی مشترک با وب (حکم CMD-050) ──
  /// آبی الکتریکی — `#1F4BFF` صفحه‌ی زنده‌ی وب
  static const Color primary = Color(0xFF1F4BFF);

  /// پله‌ی فشرده‌ی آبی — `#1334D0` وب
  static const Color primaryDeep = Color(0xFF1334D0);

  /// عمیق‌ترین آبی برند — `#13257F` وب
  static const Color primaryInk = Color(0xFF13257F);

  /// فیروزه‌ای — `#19E0FF` وب (روی سطوح تاریک و هایلایت)
  static const Color cyan = Color(0xFF19E0FF);

  /// فیروزه‌ای عمیق‌تر — `#19B7FF` وب (خوانا روی سطوح روشن)
  static const Color cyanDeep = Color(0xFF19B7FF);

  /// کهربایی — `#FFB547` وب
  static const Color amber = Color(0xFFFFB547);

  /// جوهر کهربایی — `#A35A00` وب (متن هشدار روی tint روشن)
  static const Color amberInk = Color(0xFFA35A00);

  /// نعنایی — `#7CF0C8` وب (tint موفقیت)
  static const Color mint = Color(0xFF7CF0C8);

  /// سبز تایید — `#0D7A52` وب
  static const Color green = Color(0xFF0D7A52);

  /// رز — `#FF5D73` وب (خطا/خطر)
  static const Color rose = Color(0xFFFF5D73);

  /// خطا — shade رز با کنتراست متن ≥۴٫۵ روی سطح روشن
  static const Color error = Color(0xFFC62F4B);

  // ── tintهای قرص وضعیت (tint مستقیم لنگرها — تنها محل مجاز رنگ خام در لایه‌ی دیزاین) ──
  static const Color tintSuccess = Color(0xFFE2F6EC);
  static const Color tintWarn = Color(0xFFFFF2DC);
  static const Color tintDanger = Color(0xFFFFE9EC);
  static const Color tintCyan = Color(0xFFE0FAFF);

  // ── نئوترال‌های تم روشن (tint لنگرها) ──

  /// زمینه‌ی سرد — `#F2F6FF` وب (`--bg`)
  static const Color bg = Color(0xFFF2F6FF);

  /// سطح کارت‌ها
  static const Color surface = Color(0xFFFFFFFF);

  /// جوهر اصلی — `#10204F` وب (`--ink`)
  static const Color ink = Color(0xFF10204F);

  /// متن ثانویه (کنتراست ≥۴٫۵ روی surface)
  static const Color inkSoft = Color(0xFF44537F);

  /// متن راهنما/میکرو
  static const Color inkFaint = Color(0xFF5F6E9B);

  /// خط و لبه — `#DBE6FF` وب
  static const Color line = Color(0xFFDBE6FF);

  /// پس‌زمینه‌ی tint آبی (قرص‌ها/کاشی‌ها)
  static const Color wash = Color(0xFFE7EEFF);

  /// متن روی primary
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── توکن‌های تم تاریک (عین توکن‌های دارک وب: #0A1130 / #E6ECFF) ──
  // (سطوح تاریک از tint لنگر سرمه‌ای وب ساخته شده‌اند؛ شفافیت‌ها در اجزا اعمال می‌شود)
  static const Color bgDark = Color(0xFF0A1130);
  static const Color surfaceDark = Color(0xFF121C4A);
  static const Color inkDark = Color(0xFFE6ECFF);
  static const Color inkSoftDark = Color(0xFFA8B4DC);
  static const Color lineDark = Color(0xFF26346E);
  static const Color washDark = Color(0xFF182459);
  static const Color inkFaintDark = Color(0xFF8894C2);

  // ── مقیاس فاصله (۴/۸dp — قاعده‌ی مهارت) ──
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  // ── شعاع گوشه‌ها (هویت گرد نسل S) ──
  static const double radiusCard = 20;
  static const double radiusField = 14;
  static const double radiusChip = 999;
  static const double radiusSheet = 24;

  /// فونت فارسی باندل‌شده — تنها فونت اپ (بدون Lalezar وب)
  static const String fontFamily = 'Vazirmatn';

  // ── سایه‌ی نرم آبی‌فام (به‌جای elevation خاکستری) ──
  static List<BoxShadow> get cardShadow => <BoxShadow>[
        BoxShadow(
          color: const Color(0xFF1F4BFF).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // ═══ تم‌ها — روشن و تاریک (قاعده‌ی مهارت: darkTheme الزامی) ═══
  static ThemeData lightTheme() => ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: primary,
          onPrimary: onPrimary,
          secondary: cyanDeep,
          onSecondary: ink,
          error: error,
          surface: surface,
          onSurface: ink,
          surfaceContainerHighest: wash,
        ),
        scaffoldBackgroundColor: bg,
        dividerColor: line,
        splashColor: primary.withValues(alpha: 0.08),
        highlightColor: primary.withValues(alpha: 0.05),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: ink,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          contentTextStyle: TextStyle(
            fontFamily: fontFamily,
            color: Color(0xFFFFFFFF),
            fontSize: 13.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surface,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(radiusSheet),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: s16,
            vertical: 14,
          ),
          border: _fieldBorder(line),
          enabledBorder: _fieldBorder(line),
          focusedBorder: _fieldBorder(cyanDeep, width: 1.6),
          errorBorder: _fieldBorder(rose),
          focusedErrorBorder: _fieldBorder(error, width: 1.6),
          labelStyle: const TextStyle(fontSize: 14, color: inkSoft),
          hintStyle: const TextStyle(fontSize: 14, color: inkFaint),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: onPrimary,
            minimumSize: const Size(64, 50),
            padding: const EdgeInsets.symmetric(horizontal: s20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusField),
            ),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size(64, 50),
            side: const BorderSide(color: primary, width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusField),
            ),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: wash,
          labelStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          shape: StadiumBorder(side: BorderSide(color: line)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
          ),
          titleTextStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      );

  static ThemeData darkTheme() => ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          onPrimary: onPrimary,
          secondary: cyan,
          onSecondary: bgDark,
          error: rose,
          surface: surfaceDark,
          onSurface: inkDark,
          surfaceContainerHighest: washDark,
        ),
        scaffoldBackgroundColor: bgDark,
        dividerColor: lineDark,
        splashColor: cyan.withValues(alpha: 0.10),
        highlightColor: cyan.withValues(alpha: 0.06),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDark,
          foregroundColor: inkDark,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: inkDark,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFE6ECFF),
          contentTextStyle: TextStyle(
            fontFamily: fontFamily,
            color: Color(0xFF0A1130),
            fontSize: 13.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surfaceDark,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(radiusSheet),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceDark,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: s16,
            vertical: 14,
          ),
          border: _fieldBorderDark(lineDark),
          enabledBorder: _fieldBorderDark(lineDark),
          focusedBorder: _fieldBorderDark(cyan, width: 1.6),
          errorBorder: _fieldBorderDark(rose),
          focusedErrorBorder: _fieldBorderDark(rose, width: 1.6),
          labelStyle: const TextStyle(fontSize: 14, color: inkSoftDark),
          hintStyle: const TextStyle(fontSize: 14, color: inkFaintDark),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: onPrimary,
            minimumSize: const Size(64, 50),
            padding: const EdgeInsets.symmetric(horizontal: s20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusField),
            ),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: cyan,
            minimumSize: const Size(64, 50),
            side: const BorderSide(color: cyan, width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusField),
            ),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: cyan,
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: washDark,
          labelStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: inkDark,
          ),
          shape: StadiumBorder(side: BorderSide(color: lineDark)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
          ),
          titleTextStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: inkDark,
          ),
        ),
      );

  static OutlineInputBorder _fieldBorder(Color c, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: BorderSide(color: c, width: width),
      );

  static OutlineInputBorder _fieldBorderDark(Color c, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: BorderSide(color: c, width: width),
      );
}

/// مقیاس تایپوگرافی نسل S — عنوان‌های درشت بومی‌موبایلی (بدون Lalezar وب)
abstract final class DsText {
  /// سرتیتر بزرگ صفحه‌ها
  static const TextStyle display = TextStyle(
    fontFamily: Ds.fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.3,
    color: Ds.ink,
  );

  /// تیتر بخش
  static const TextStyle title = TextStyle(
    fontFamily: Ds.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.4,
    color: Ds.ink,
  );

  /// تیتر کارت/ردیف
  static const TextStyle headline = TextStyle(
    fontFamily: Ds.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.5,
    color: Ds.ink,
  );

  /// متن اصلی
  static const TextStyle body = TextStyle(
    fontFamily: Ds.fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: Ds.ink,
  );

  /// متن ثانویه
  static const TextStyle caption = TextStyle(
    fontFamily: Ds.fontFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: Ds.inkSoft,
  );

  /// برچسب ریز — هرگز زیر ۱۱٫۵ (قاعده‌ی خوانایی مهارت: ≥۱۲ برای بدنه)
  static const TextStyle micro = TextStyle(
    fontFamily: Ds.fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: Ds.inkFaint,
  );
}
