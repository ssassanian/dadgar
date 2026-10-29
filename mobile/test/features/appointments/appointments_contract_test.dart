import 'package:dadgar_mobile/features/appointments/data/appointments_contract.dart';
import 'package:dadgar_mobile/core/time/jalali.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('آینه‌ی قرارداد سرور (BK-* در web/lib/web.js)', () {
    test('شروع ماه قرارداد دقیقاً مثل فرمول سرور', () {
      // Date.UTC(2026, 9, 23, 0, 0) / 1000 - 12600
      final serverFormula =
          DateTime.utc(2026, 10, 23).millisecondsSinceEpoch ~/ 1000 - 12600;
      expect(AppointmentContract.monthStartEpochSeconds, serverFormula);
      // و همان لحظه = ۱ آبان ۱۴۰۵ تهران
      expect(
        JalaliCalendar.fromEpochSeconds(
            AppointmentContract.monthStartEpochSeconds),
        const JalaliDate(1405, 8, 1),
      );
    });

    test('پنج بازه‌ی ثابت با همان برچسب‌های سرور', () {
      expect(AppointmentContract.slotLabels.keys.toList(), [540, 630, 720, 960, 1050]);
      expect(AppointmentContract.slotLabels.values.toList(),
          ['۰۹:۰۰', '۱۰:۳۰', '۱۲:۰۰', '۱۶:۰۰', '۱۷:۳۰']);
      expect(AppointmentContract.slotLabels.length, 5);
    });

    test('startsAtOf دقیقاً فرمول سرور است', () {
      // BK_MONTH_START + (day - 1) * 86400 + BK_SLOTS[slot] * 60
      final day3slot1030 = AppointmentContract.startsAtOf(3, 630);
      expect(day3slot1030,
          AppointmentContract.monthStartEpochSeconds + 2 * 86400 + 630 * 60);
      // برچسب معکوس
      expect(AppointmentContract.slotMinutesOf('۱۰:۳۰'), 630);
      expect(AppointmentContract.slotMinutesOf('۰۸:۰۰'), isNull);
      expect(AppointmentContract.labelOfSlotMinutes(630), '۱۰:۳۰');
      expect(AppointmentContract.labelOfSlotMinutes(999), '');
    });

    test('انواع ملاقات و طول ماه همان سرور', () {
      expect(AppointmentContract.kinds, ['حضوری', 'آنلاین', 'تلفنی']);
      expect(AppointmentContract.monthDays, 30);
      expect(AppointmentContract.jalaliOfDay(30),
          const JalaliDate(1405, 8, 30));
    });

    test('کلید taken و قاعده‌ی روزِ بسته', () {
      expect(AppointmentContract.takenKey(2, '۰۹:۰۰'), '2:۰۹:۰۰');
      // «الان» پیش از آغاز ماه: همه‌ی بازه‌های روز ۲ آینده‌اند
      final beforeMonth = AppointmentContract.monthStartEpochSeconds - 86400;
      expect(
        AppointmentContract.isDayClosed(
          day: 2,
          taken: {'2:۰۹:۰۰', '2:۱۰:۳۰', '2:۱۲:۰۰', '2:۱۶:۰۰'},
          nowSeconds: beforeMonth,
        ),
        isFalse,
        reason: '۱۷:۳۰ هنوز آزاد است',
      );
      // با پرشدن ۱۷:۳۰ روز کامل بسته است
      expect(
        AppointmentContract.isDayClosed(
          day: 2,
          taken: {'2:۰۹:۰۰', '2:۱۰:۳۰', '2:۱۲:۰۰', '2:۱۶:۰۰', '2:۱۷:۳۰'},
          nowSeconds: beforeMonth,
        ),
        isTrue,
      );
      // روز گذشته (زمان جاری بعد از پایان روز ۱)
      final afterDay1 =
          AppointmentContract.monthStartEpochSeconds + 1060 * 60;
      expect(
        AppointmentContract.isDayClosed(
          day: 1,
          taken: {},
          nowSeconds: afterDay1,
        ),
        isTrue,
      );
    });
  });
}
