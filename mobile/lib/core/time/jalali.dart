/// تقویم شمسی نیتیو دادگر — خالص Dart، صفر وابستگی بیرونی (DOC-04 §۶-۵ / §۷)
///
/// الگوریتم مرجع: تقویم جلالی (Borkowski) مطابق پیاده‌سازی مرجع `jalaali-js` —
/// بازه‌ی معتبر ۱۱۷۸ تا ۱۶۳۳ هجری‌شمسی. سند DOC-04 پکیج `shamsi_date` را
/// نام برده بود؛ در این محیط دسترسی pub.dev مسدود است و اضافه‌کردن وابستگی
/// جدید ناممکن بود — لذا همان الگوریتم مرجع به‌صورت نیتیو پیاده شد (تفاوت
/// ثبت‌شده در CMD-021؛ رفتار یکسان، وابستگی صفر، تست جامع دارد).
///
/// زمان تهران: ایران از سال ۱۴۰۱ ساعت تابستانی ندارد → آفست ثابت ‎+۰۳:۳۰
/// (هم‌ساز با ثابت سرور در `web/lib/web.js`).
library;

int _div(int a, int b) => a ~/ b;
int _mod(int a, int b) => a - (a ~/ b) * b;

/// مرزهای الگوریتم جلالی (سال‌های کبیسه‌ی ۳۳ساله)
const List<int> _breaks = [
  -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1633,
];

final class _JalCal {
  const _JalCal(this.leap, this.gy, this.march);

  /// تعداد سال از آخرین سال کبیسه؛ صفر = همین سال کبیسه است
  final int leap;
  final int gy;
  final int march;
}

_JalCal _jalCal(int jy) {
  final gy = jy + 621;
  var leapJ = -14;
  var jp = _breaks[0];
  var jump = 0;
  if (jy < jp || jy >= _breaks.last) {
    throw ArgumentError('سال شمسی خارج از بازه‌ی معتبر الگوریتم است: $jy');
  }
  for (var i = 1; i < _breaks.length; i++) {
    final jm = _breaks[i];
    jump = jm - jp;
    if (jy < jm) break;
    leapJ += _div(jump, 33) * 8 + _div(_mod(jump, 33), 4);
    jp = jm;
  }
  var n = jy - jp;
  leapJ += _div(n, 33) * 8 + _div(_mod(n, 33) + 3, 4);
  if (_mod(jump, 33) == 4 && jump - n == 4) leapJ++;
  final leapG = _div(gy, 4) - _div((_div(gy, 100) + 1) * 3, 4) - 150;
  final march = 20 + leapJ - leapG;
  if (jump - n < 6) n = n - jump + _div(jump + 4, 33) * 33;
  var leap = _mod(_mod(n + 1, 33) - 1, 4);
  if (leap == -1) leap = 4;
  return _JalCal(leap, gy, march);
}

int _g2d(int gy, int gm, int gd) {
  var d = _div((gy + _div(gm - 8, 6) + 100100) * 1461, 4) +
      _div(153 * _mod(gm + 9, 12) + 2, 5) +
      gd -
      34840408;
  d = d - _div(_div(gy + 100100 + _div(gm - 8, 6), 100) * 3, 4) + 752;
  return d;
}

(int, int, int) _d2g(int jdn) {
  var j = 4 * jdn + 139361631;
  j = j + _div(_div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908;
  final i = _div(_mod(j, 1461), 4) * 5 + 308;
  final gd = _div(_mod(i, 153), 5) + 1;
  final gm = _mod(_div(i, 153), 12) + 1;
  final gy = _div(j, 1461) - 100100 + _div(8 - gm, 6);
  return (gy, gm, gd);
}

/// تاریخ شمسی — سال/ماه/روز (ماه و روز ۱-مبنا)
final class JalaliDate {
  const JalaliDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is JalaliDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year/$month/$day';
}

/// زمان تهران — آفست ثابت (بدون ساعت تابستانی، هم‌ساز با سرور)
abstract final class TehranTime {
  /// ‎+۰۳:۳۰ = ۱۲۶۰۰ ثانیه
  static const Duration offset = Duration(seconds: 12600);

  /// epoch-seconds → ساعت دیواری تهران (فیلدهای UTC با آفست جابه‌جا شده)
  static DateTime wallClockFromEpochSeconds(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
          .add(offset);

  /// epoch-seconds لحظه‌ی «ساعت دیواری تهران» داده‌شده
  static int epochSecondsOf(int year, int month, int day,
      [int hour = 0, int minute = 0]) {
    return DateTime.utc(year, month, day, hour, minute)
            .millisecondsSinceEpoch ~/
        1000 -
        offset.inSeconds;
  }
}

/// تبدیل‌های تقویم شمسی — تنها نقطه‌ی دانش تقویم در کل اپ
abstract final class JalaliCalendar {
  /// نام ماه‌های شمسی
  static const List<String> monthNames = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  /// نام روزهای هفته از شنبه (اندیس صفر)
  static const List<String> weekDayNames = [
    'شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه',
  ];

  /// epoch-seconds (لحظه‌ی جهانی) → تاریخ شمسی تهران
  static JalaliDate fromEpochSeconds(int seconds) {
    final wall = TehranTime.wallClockFromEpochSeconds(seconds);
    return fromGregorian(wall.year, wall.month, wall.day);
  }

  /// میلادی → شمسی
  static JalaliDate fromGregorian(int gy, int gm, int gd) {
    return julianDayToJalali(_g2d(gy, gm, gd));
  }

  /// شمسی → epoch-seconds تهرانِ ساعت دیواری داده‌شده
  static int toEpochSeconds(JalaliDate date, [int hour = 0, int minute = 0]) {
    final (gy, gm, gd) = toGregorian(date);
    return TehranTime.epochSecondsOf(gy, gm, gd, hour, minute);
  }

  /// شمسی → میلادی (مؤلفه‌های تقویمی)
  static (int, int, int) toGregorian(JalaliDate date) {
    final jdn = julianDayOf(date);
    return _d2g(jdn);
  }

  /// شمسی → شماره‌ی روز ژولینی
  static int julianDayOf(JalaliDate date) {
    final r = _jalCal(date.year);
    return _g2d(r.gy, 3, r.march) +
        (date.month - 1) * 31 -
        _div(date.month, 7) * (date.month - 7) +
        date.day -
        1;
  }

  /// شماره‌ی روز ژولینی → شمسی
  static JalaliDate julianDayToJalali(int jdn) {
    final gy = _d2g(jdn).$1;
    var jy = gy - 621;
    final r = _jalCal(jy);
    final jdn1f = _g2d(gy, 3, r.march);
    var k = jdn - jdn1f;
    if (k >= 0) {
      if (k <= 185) {
        return JalaliDate(jy, 1 + _div(k, 31), _mod(k, 31) + 1);
      }
      k -= 186;
    } else {
      jy -= 1;
      k += 179;
      if (r.leap == 1) k += 1;
    }
    return JalaliDate(jy, 7 + _div(k, 30), _mod(k, 30) + 1);
  }

  /// آیا سال کبیسه است؟ (esfand = ۳۰ روز)
  static bool isLeapYear(int jy) => _jalCal(jy).leap == 0;

  /// طول ماه شمسی (۳۱ / ۳۰ / ۲۹)
  static int monthLength(int jy, int jm) {
    if (jm <= 6) return 31;
    if (jm <= 11) return 30;
    return isLeapYear(jy) ? 30 : 29;
  }

  /// اندیس روز هفته: ۰=شنبه … ۶=جمعه
  static int weekIndexOf(JalaliDate date) {
    final (gy, gm, gd) = toGregorian(date);
    // DateTime.weekday: دوشنبه=۱ … شنبه=۶، یکشنبه=۷ → نگاشت به شنبه=۰
    return (DateTime.utc(gy, gm, gd).weekday + 1) % 7;
  }

  /// قالب «روزِ نام‌ماه سال» — مثل «۱ آبان ۱۴۰۵»
  static String formatLong(JalaliDate date) {
    return '${toPersianDigits(date.day)} '
        '${monthNames[date.month - 1]} ${toPersianDigits(date.year)}';
  }

  /// قالب «سال/ماه/روز با ارقام فارسی» — مثل «۱۴۰۵/۰۸/۰۱»
  static String formatNumeric(JalaliDate date) =>
      '${toPersianDigits(date.year)}/'
      '${toPersianDigits(date.month.toString().padLeft(2, '0'))}/'
      '${toPersianDigits(date.day.toString().padLeft(2, '0'))}';

  /// تبدیل ارقام لاتین به فارسی (DOC-04 §۷: اعداد فارسی)
  static String toPersianDigits(Object value) {
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    final s = value.toString();
    final buffer = StringBuffer();
    for (final code in s.runes) {
      final ch = code - 0x30;
      buffer.write(ch >= 0 && ch <= 9 ? fa[ch] : String.fromCharCode(code));
    }
    return buffer.toString();
  }
}
