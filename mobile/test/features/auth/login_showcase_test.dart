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
    expect(find.text('پرونده‌تان را قدم‌به‌قدم ببینید'), findsOneWidget);
    expect(find.textContaining('نمایشی'), findsOneWidget);
    expect(find.text('ثبت'), findsOneWidget);
    expect(find.text('پیشنهاد'), findsOneWidget);
    expect(find.text('تخصیص'), findsOneWidget);
    expect(find.text('در حال انجام'), findsOneWidget);
    expect(find.text('پایان'), findsOneWidget);

    // فرم ورود عین M1 — منطق دست‌نخورده
    expect(find.text('ورود به دادگر'), findsOneWidget);
    expect(find.text('نام کاربری'), findsOneWidget);
    expect(find.text('رمز عبور'), findsOneWidget);
    expect(find.text('ورود'), findsOneWidget);
    expect(find.text('ورود با کد یک‌بارمصرف (OTP)'), findsOneWidget);
    expect(find.textContaining('D-6'), findsOneWidget);

    // راستا: فارسی RTL — الزام DOC-04 §۷
    final BuildContext titleContext =
        tester.element(find.text('ورود به دادگر'));
    expect(Directionality.of(titleContext), TextDirection.rtl);
  });
}
