import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('خانه با نشست معتبر: خوش‌آمد + پالت نهایی D-3 (سرمه‌ای) + RTL',
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

    // پالت نهایی D-3 (سرمه‌ای) — برچسب رنگ‌ها
    expect(find.text('#14345B'), findsOneWidget);
    expect(find.text('#FAF7F2'), findsOneWidget);
    expect(find.text('#2E7D32'), findsOneWidget);
  });
}
