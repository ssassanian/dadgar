import 'package:dadgar_mobile/core/time/jalali.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('لنگرهای شناخته‌شده (هم‌ساز با قرارداد سرور)', () {
    test('۱۴۰۵/۰۸/۰۱ تهران == 2026-10-23 ۰۰:۰۰ تهران (ثابت BK سرور)', () {
      final epoch = DateTime.utc(2026, 10, 23).millisecondsSinceEpoch ~/ 1000 -
          12600;
      expect(JalaliCalendar.fromEpochSeconds(epoch),
          const JalaliDate(1405, 8, 1));
      expect(JalaliCalendar.toEpochSeconds(const JalaliDate(1405, 8, 1)),
          epoch);
    });

    test('نوروز ۱۴۰۵ == 2026-03-21', () {
      expect(JalaliCalendar.fromGregorian(2026, 3, 21),
          const JalaliDate(1405, 1, 1));
      final (gy, gm, gd) =
          JalaliCalendar.toGregorian(const JalaliDate(1405, 1, 1));
      expect((gy, gm, gd), (2026, 3, 21));
    });

    test('۱۴۰۳ کبیسه است (اسفند ۳۰) و ۱۴۰۵ کبیسه نیست', () {
      expect(JalaliCalendar.isLeapYear(1403), isTrue);
      expect(JalaliCalendar.isLeapYear(1404), isFalse);
      expect(JalaliCalendar.isLeapYear(1405), isFalse);
      expect(JalaliCalendar.isLeapYear(1408), isTrue);
      expect(JalaliCalendar.monthLength(1403, 12), 30);
      expect(JalaliCalendar.monthLength(1405, 12), 29);
      expect(JalaliCalendar.monthLength(1405, 8), 30);
      expect(JalaliCalendar.monthLength(1405, 6), 31);
    });

    test('۱۴۰۵/۰۸/۰۱ جمعه است (اندیس ۶)', () {
      expect(JalaliCalendar.weekIndexOf(const JalaliDate(1405, 8, 1)), 6);
      expect(JalaliCalendar.weekDayNames[6], 'جمعه');
    });
  });

  group('رفت‌وبرگشت کامل تقویم', () {
    test('شمسی → epoch → شمسی روی بازه‌ی ۱۳۵۰ تا ۱۴۵۰', () {
      for (var jy = 1350; jy <= 1450; jy++) {
        for (var jm = 1; jm <= 12; jm++) {
          final length = JalaliCalendar.monthLength(jy, jm);
          for (final jd in [1, length ~/ 2, length]) {
            final date = JalaliDate(jy, jm, jd);
            final epoch = JalaliCalendar.toEpochSeconds(date);
            expect(JalaliCalendar.fromEpochSeconds(epoch), date,
                reason: 'رفت‌وبرگشت شکست در $date');
          }
        }
      }
    });

    test('میلادی → شمسی → میلادی روزانه ۲۰۲۰ تا ۲۰۳۶', () {
      var cursor = DateTime.utc(2020, 1, 1);
      final end = DateTime.utc(2036, 12, 31);
      var checked = 0;
      while (!cursor.isAfter(end)) {
        final j = JalaliCalendar.fromGregorian(
            cursor.year, cursor.month, cursor.day);
        final (gy, gm, gd) = JalaliCalendar.toGregorian(j);
        expect(
          DateTime.utc(gy, gm, gd),
          cursor,
          reason: 'رفت‌وبرگشت میلادی شکست در $cursor → $j',
        );
        cursor = cursor.add(const Duration(days: 1));
        checked++;
      }
      expect(checked, greaterThan(6000));
    });

    test('پیوستگی روزهای هفته شمسی و میلادی هم‌خوان است', () {
      var cursor = DateTime.utc(2026, 10, 1);
      var previousIndex = -1;
      for (var i = 0; i < 120; i++) {
        final j = JalaliCalendar.fromGregorian(
            cursor.year, cursor.month, cursor.day);
        final index = JalaliCalendar.weekIndexOf(j);
        if (previousIndex >= 0) {
          expect(index, (previousIndex + 1) % 7,
              reason: 'پیوستگی هفته شکست در $cursor');
        }
        previousIndex = index;
        cursor = cursor.add(const Duration(days: 1));
      }
    });
  });

  group('قالب‌بندی فارسی', () {
    test('ارقام فارسی', () {
      expect(JalaliCalendar.toPersianDigits(1405), '۱۴۰۵');
      expect(JalaliCalendar.toPersianDigits('09:00'), '۰۹:۰۰');
    });

    test('قالب بلند و عددی', () {
      expect(JalaliCalendar.formatLong(const JalaliDate(1405, 8, 1)),
          '۱ آبان ۱۴۰۵');
      expect(JalaliCalendar.formatNumeric(const JalaliDate(1405, 8, 1)),
          '۱۴۰۵/۰۸/۰۱');
    });

    test('زمان تهران: آفست ثابت ۱۲۶۰۰ ثانیه اعمال می‌شود', () {
      // ۱۴۰۵/۰۸/۰۱ ساعت ۰۹:۰۰ تهران == 2026-10-23T05:30Z
      final epoch = TehranTime.epochSecondsOf(2026, 10, 23, 9, 0);
      final utc = DateTime.fromMillisecondsSinceEpoch(epoch * 1000,
          isUtc: true);
      expect(utc.hour, 5);
      expect(utc.minute, 30);
      final wall = TehranTime.wallClockFromEpochSeconds(epoch);
      expect(wall.hour, 9);
      expect(wall.minute, 0);
    });
  });
}
