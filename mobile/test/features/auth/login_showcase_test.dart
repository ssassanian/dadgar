/// ویترین امکانات صفحه‌ی ورود — CMD-040 (بازطراحی تاییدشده CMD-039)
library;

import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('ورود: شش قابلیت + نمونه‌ی مسیر پرونده پیش از فرم + RTL',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(const AuthUnauthenticated()),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('fa'),
          supportedLocales: [Locale('fa')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // شش قابلیت — عین ماتریس امکان CMD-039
    expect(find.text('پیگیری زنده‌ی پرونده'), findsOneWidget);
    expect(find.text('گفتگو با وکیل'), findsOneWidget);
    expect(find.text('رزرو نوبت'), findsOneWidget);
    expect(find.text('گاوصندوق اسناد'), findsOneWidget);
    expect(find.text('فاکتور و پرداخت'), findsOneWidget);
    expect(find.text('اعلان جلسات'), findsOneWidget);

    // عنصر امضایی — نمونه‌ی مسیر پرونده با برچسب صادقانه‌ی نمایشی
    // (حکم F1 سند CMD-048: شش مرحله‌ی حقوقی عین طرح)
    expect(find.text('پرونده‌تان را قدم‌به‌قدم ببینید'), findsOneWidget);
    expect(find.textContaining('نمایشی'), findsOneWidget);
    expect(find.text('ثبت'), findsOneWidget);
    expect(find.text('بررسی مدارک'), findsOneWidget);
    expect(find.text('طرح دعوا'), findsOneWidget);
    expect(find.text('جلسات'), findsOneWidget);
    expect(find.text('صدور رأی'), findsOneWidget);
    expect(find.text('قطعی'), findsOneWidget);

    // فرم ورود عین M1 — منطق دست‌نخورده
    expect(find.text('ورود به دادگر'), findsOneWidget);
    expect(find.text('نام کاربری'), findsOneWidget);
    expect(find.text('رمز عبور'), findsOneWidget);
    expect(find.text('ورود'), findsOneWidget);
    expect(find.text('ورود با کد یک‌بارمصرف (OTP)'), findsOneWidget);
    // F8 (حکم CMD-048): لینک فراموشی رمز زیر فرم
    expect(find.text('فراموشی رمز عبور؟'), findsOneWidget);
    expect(find.textContaining('CMD-026/REL-011'), findsOneWidget);

    // راستا: فارسی RTL — الزام DOC-04 §۷
    final BuildContext titleContext =
        tester.element(find.text('ورود به دادگر'));
    expect(Directionality.of(titleContext), TextDirection.rtl);
  });

  testWidgets('F8 (حکم CMD-048): فراموشی رمز — شیت دفترمحور صادقانه',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(const AuthUnauthenticated()),
          ),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    // دکمه زیر پنل‌های ویترین است (زیر خط دید) — الگوی ensureVisible درس ACT-097
    await tester.ensureVisible(find.text('فراموشی رمز عبور؟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فراموشی رمز عبور؟'));
    await tester.pumpAndSettle();

    expect(find.text('بازیابی رمز عبور'), findsOneWidget);
    expect(find.textContaining('دفتر مؤسسه'), findsWidgets);
    expect(find.textContaining('۰۲۱-۰۰۰۰۰۰۰۰'), findsOneWidget);

    // دکمه‌ی تماس — پیام صادقانه‌ی عین پروتوتایپ، بدون مسیر سرور جعلی
    await tester.tap(find.textContaining('تماس با دفتر'));
    await tester.pumpAndSettle();
    expect(find.text('در اپ واقعی: تماس با دفتر مؤسسه'), findsOneWidget);
  });
}
