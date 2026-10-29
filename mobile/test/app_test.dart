import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dadgar_mobile/app/app.dart';

void main() {
  testWidgets('صفحه‌ی خانه رندر می‌شود: عنوان دادگر + RTL فارسی', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DadgarApp()));
    await tester.pumpAndSettle();

    // عنوان اپ
    expect(find.text('دادگر'), findsOneWidget);

    // راستا: فارسی RTL — الزام DOC-04 §۷
    final BuildContext titleContext =
        tester.element(find.text('دادگر'));
    expect(Directionality.of(titleContext), TextDirection.rtl);

    // پالت نهایی D-3 (سرمه‌ای) — برچسب رنگ‌ها
    expect(find.text('#14345B'), findsOneWidget);
    expect(find.text('#FAF7F2'), findsOneWidget);
    expect(find.text('#2E7D32'), findsOneWidget);
  });
}
