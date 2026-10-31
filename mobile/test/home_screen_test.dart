import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('خانه با نشست معتبر: روال کار-اول CMD-040 + RTL',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider
              .overrideWith(() => FakeAuthController(const Authenticated('مدیر'))),
        ],
        child: const MaterialApp(
          locale: Locale('fa'),
          supportedLocales: [Locale('fa')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // خوش‌آمد نشست
    expect(find.text('سلام، مدیر'), findsOneWidget);
    // عنوان اپ در AppBar
    expect(find.text('دادگر'), findsOneWidget);

    // راستا: فارسی RTL — الزام DOC-04 §۷
    final BuildContext titleContext = tester.element(find.text('دادگر'));
    expect(Directionality.of(titleContext), TextDirection.rtl);

    // کارت قهرمان — مسیر پرونده با پنج مرحله‌ی واقعی قرارداد سرور
    expect(find.text('مسیر پرونده'), findsOneWidget);
    expect(find.text('ثبت'), findsOneWidget);
    expect(find.text('پایان'), findsOneWidget);
    expect(find.text('پرونده‌های من'), findsWidgets);

    // سه اقدام فوری (CMD-038)
    expect(find.text('ارسال سند'), findsOneWidget);
    expect(find.text('رزرو نوبت'), findsOneWidget);
    expect(find.text('پرداخت فاکتور'), findsOneWidget);

    // پنل‌های نقشه‌ی امکان
    expect(find.text('پرونده‌ها و گفتگو'), findsOneWidget);
    expect(find.text('نوبت و مالی'), findsOneWidget);
    expect(find.text('گفتگو با وکیل'), findsOneWidget);
    expect(find.text('تیکت‌های پشتیبانی'), findsOneWidget);
    expect(find.text('نوبت‌های من'), findsOneWidget);
    expect(find.text('صورتحساب‌ها و پرداخت'), findsOneWidget);

    // وضعیت صادقانه‌ی M1 — بدون هیچ داده‌ی جعلی
    expect(find.textContaining('D-6'), findsOneWidget);
  });
}
