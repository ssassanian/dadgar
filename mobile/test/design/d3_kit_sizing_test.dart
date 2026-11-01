/// گیت سنجش خودکار CMD-048 — حکم F4/F5 بازرسی CMD-042:
/// لمس کنترل‌ها ≥۴۴ و متن قرص ۱۲ — و رندر شش‌مرحله‌ای مسیر
/// حقوقی در ۳۹۰px بدون سرریز (آزمون شکستن سطر جواز F5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dadgar_mobile/design/d3_kit.dart';
import 'package:dadgar_mobile/design/journey_bar.dart';
import 'package:dadgar_mobile/features/cases/data/cases_contract.dart';

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: child),
        ),
      ),
    );

void main() {
  testWidgets('DadgarChip — ارتفاع لمس ۴۴ (F4)', (tester) async {
    await tester.pumpWidget(_host(
      DadgarChip('در جریان', selected: false, onTap: () {}),
    ));
    final size = tester.getSize(find.byType(DadgarChip));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('DadgarCardLink — لمس ≥۴۴ (F4)', (tester) async {
    await tester.pumpWidget(_host(
      DadgarCardLink('همه‌ی اسناد گاوصندوق', onTap: () {}),
    ));
    final size = tester.getSize(find.byType(DadgarCardLink));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('DadgarPill — قلم ۱۲ (F5) و ارتفاع ۲۲', (tester) async {
    await tester.pumpWidget(_host(const DadgarPill('تخصیص‌یافته')));
    final text = tester.widget<Text>(find.text('تخصیص‌یافته'));
    expect(text.style?.fontSize, 12);
    final size = tester.getSize(find.byType(DadgarPill));
    expect(size.height, 22);
  });

  testWidgets('دکمه‌های شبح/اصلی — لمس ۴۴ (F4)', (tester) async {
    await tester.pumpWidget(_host(
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DadgarGhostButton('اقدام شبح', onPressed: null),
          DadgarPrimaryButton('اقدام اصلی', onPressed: null),
        ],
      ),
    ));
    expect(tester.getSize(find.byType(DadgarGhostButton)).height, 44);
    expect(tester.getSize(find.byType(DadgarPrimaryButton)).height, 44);
  });

  testWidgets('مسیر حقوقی شش‌مرحله‌ای در ۳۹۰px — بدون سرریز (F5)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(
      const Padding(
        padding: EdgeInsets.all(16),
        child: DadgarJourneyBar(steps: CasesContract.legalJourney),
      ),
    ));
    for (final label in CasesContract.legalJourney) {
      expect(find.text(label), findsOneWidget);
    }
    // برچسب مرحله ≥۱۲ — قاعده‌ی F5 روی عنصر امضایی
    final lbl = tester.widget<Text>(find.text('بررسی مدارک'));
    expect(lbl.style?.fontSize, greaterThanOrEqualTo(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('نگاشت F1 — وضعیت‌های سرور به اندیس حقوقی', (tester) async {
    expect(CasesContract.legalJourney.length, 6);
    expect(CasesContract.legalJourneyIndexFor('waiting'), 0);
    expect(CasesContract.legalJourneyIndexFor('proposing'), 1);
    expect(CasesContract.legalJourneyIndexFor('assigned'), 2);
    expect(CasesContract.legalJourneyIndexFor('running'), 3);
    expect(CasesContract.legalJourneyIndexFor('done'), 5);
    expect(CasesContract.legalJourneyIndexFor('unknown'), isNull);
  });
}
