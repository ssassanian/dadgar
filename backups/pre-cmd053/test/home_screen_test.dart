/// گیت صفحه‌ی خانه‌ی نسل S — بازنویسی برای CMD-051 (داک‌سازگار، کار-اول)
library;

import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('خانه نسل S: سربرگ آبی + درود + مسیر پرونده + اقدام‌ها + RTL',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(const Authenticated('مدیر')),
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
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // درود نشست روی سربرگ تمام‌آبی
    expect(find.text('سلام، مدیر'), findsOneWidget);

    // کارت قهرمان — مسیر پرونده با شش مرحله‌ی حقوقی (حکم F1 سند CMD-048)
    expect(find.text('مسیر پرونده'), findsOneWidget);
    expect(find.text('ثبت'), findsOneWidget);
    expect(find.text('قطعی'), findsOneWidget);
    expect(find.text('صدور رأی'), findsOneWidget);
    expect(find.text('پرونده‌های من'), findsWidgets);

    // چهار اقدام فوری (CMD-038 — نسل S دایره‌ای)
    expect(find.text('ارسال سند'), findsOneWidget);
    expect(find.text('رزرو نوبت'), findsOneWidget);
    expect(find.text('پرداخت فاکتور'), findsOneWidget);
    // هم دایره‌ی اقدام و هم کاشی بخش
    expect(find.text('گفتگو با وکیل'), findsWidgets);

    // بخش‌های کاشی‌ای
    expect(find.text('پرونده‌ها و گفتگو'), findsOneWidget);
    expect(find.text('نوبت و مالی'), findsOneWidget);
    expect(find.text('تیکت‌های پشتیبانی'), findsOneWidget);
    expect(find.text('نوبت‌های من'), findsOneWidget);
    expect(find.text('صورتحساب‌ها و پرداخت'), findsOneWidget);

    // وضعیت صادقانه‌ی M1 — بدون هیچ داده‌ی جعلی
    expect(find.textContaining('اتصال زنده به سرور دادگر'), findsOneWidget);
    expect(find.textContaining('Keystore/Keychain'), findsOneWidget);

    // راستا: فارسی RTL — الزام DOC-04 §۷
    final BuildContext greetingContext = tester.element(
      find.text('سلام، مدیر'),
    );
    expect(Directionality.of(greetingContext), TextDirection.rtl);
  });
}
