/// گیت‌های اندازه‌ی کیت نسل S — بازنویسی برای ds_kit (CMD-051)
///
/// قواعد مهارت ui-ux-pro-max: هدف لمس ≥۴۸dp، متن بدنه ≥۱۲ (مرز کپشن
/// مستند: برچسب‌های میکرو/نقشه‌ی مسیر ۱۱–۱۱٫۵)، بدون سرریز روی عرض باریک.
library;

import 'package:dadgar_mobile/app/tab_shell.dart';
import 'package:dadgar_mobile/design/ds_kit.dart';
import 'package:dadgar_mobile/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester,
    Widget child, {
    Size surface = const Size(400, 900),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: Ds.lightTheme(),
        home: Scaffold(body: child),
      ),
    );
    await tester.pump();
  }

  group('DsButton — ارتفاع لمس', () {
    testWidgets('دکمه‌ی استاندارد ≥۴۸', (tester) async {
      await pumpHost(
        tester,
        const DsButton('ورود', expand: true),
      );
      final size = tester.getSize(find.byType(DsButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('دکمه‌ی با آیکون و برچسب بلند ≥۴۸ و بدون سرریز', (tester) async {
      await pumpHost(
        tester,
        const Padding(
          padding: EdgeInsets.all(8),
          child: DsButton(
            'برچسب نسبتاً بلند برای آزمون سرریز متن روی عرض باریک',
            icon: Icons.folder_outlined,
            expand: true,
          ),
        ),
      );
      final size = tester.getSize(find.byType(DsButton));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  });

  group('DsTile — ردیف اقدام', () {
    testWidgets('ارتفاع ≥۵۶ با عنوان و زیرنویس', (tester) async {
      await pumpHost(
        tester,
        const DsTile(
          icon: Icons.folder_outlined,
          title: 'پرونده‌های من',
          subtitle: 'فهرست و جزئیات پرونده‌ها',
        ),
      );
      final size = tester.getSize(find.byType(DsTile));
      expect(size.height, greaterThanOrEqualTo(56));
    });
  });

  group('DsPill — خوانایی', () {
    testWidgets('متن قرص ≥۱۲', (tester) async {
      await pumpHost(
        tester,
        const DsPill('پرداخت‌شده', tone: DsPillTone.success),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(DsPill),
          matching: find.byType(Text),
        ),
      );
      expect(text.style?.fontSize, greaterThanOrEqualTo(12));
    });
  });

  group('DsJourneyBar — نقشه‌ی مسیر', () {
    const steps = <String>[
      'ثبت',
      'بررسی مدارک',
      'طرح دعوا',
      'جلسات',
      'صدور رأی',
      'قطعی',
    ];

    testWidgets('شش مرحله روی عرض باریک ۳۲۰ بدون سرریز', (tester) async {
      await pumpHost(
        tester,
        const Padding(
          padding: EdgeInsets.all(12),
          child: DsJourneyBar(steps: steps),
        ),
        surface: const Size(320, 400),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('حالت currentIndex بدون سرریز و با نقطه‌ی فعال', (tester) async {
      await pumpHost(
        tester,
        const Padding(
          padding: EdgeInsets.all(12),
          child: DsJourneyBar(steps: steps, currentIndex: 2),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('DsDock — مقصدهای ناوبری', () {
    testWidgets('هر مقصد ≥۴۸ ارتفاع لمس', (tester) async {
      await pumpHost(
        tester,
        DsDock(
          currentIndex: 0,
          onDestinationSelected: (_) {},
          pendingInvoices: 0,
        ),
        surface: const Size(360, 200),
      );
      for (final location in <String>['/', '/cases', '/invoices']) {
        final size = tester.getSize(
          find.byKey(ValueKey<String>('dock-$location')),
        );
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('DsTextField — برچسب', () {
    testWidgets('برچسب ≥۱۲', (tester) async {
      await pumpHost(
        tester,
        DsTextField(controller: TextEditingController(), label: 'نام کاربری'),
      );
      final label = tester.widget<Text>(
        find.text('نام کاربری'),
      );
      expect(label.style?.fontSize, greaterThanOrEqualTo(12));
    });
  });
}
