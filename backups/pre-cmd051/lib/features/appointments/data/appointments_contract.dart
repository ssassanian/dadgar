/// آینه‌ی قرارداد نوبت‌دهی سمت سرور — CMD-004 در `web/lib/web.js` (ثابت‌های BK-*)
///
/// S-4: موبایل فقط همین قرارداد موجود را مصرف می‌کند؛ هیچ مسیر/شکل جدیدی
/// تعریف نمی‌شود و سرور با این ماژول صفر تغییر می‌کند.
///
/// تقویم مرجع سرور (نمایشی تا تصمیم مدیر درباره‌ی بازه‌های واقعی وکلا):
/// ماه «آبان ۱۴۰۵»، روزهای ۱..۳۰، پنج بازه‌ی ثابت روزانه.
/// `starts_at` = epoch-seconds لحظه‌ی تهران (UTC+03:30 ثابت).
library;

import '../../../core/time/jalali.dart';

abstract final class AppointmentContract {
  /// ۱۴۰۵/۰۸/۰۱ ۰۰:۰۰ تهران — محاسبه‌شده دقیقاً مثل سرور:
  /// `Date.UTC(2026, 9, 23, 0, 0) / 1000 - 12600`
  static final int monthStartEpochSeconds =
      DateTime.utc(2026, 10, 23).millisecondsSinceEpoch ~/ 1000 - 12600;

  /// ماه قرارداد
  static const int contractYear = 1405;
  static const int contractMonth = 8;
  static const int monthDays = 30;

  /// بازه‌های ثابت روزانه: دقیقه‌ی آغاز از نیمه‌شب → برچسب فارسی
  static const Map<int, String> slotLabels = {
    540: '۰۹:۰۰',
    630: '۱۰:۳۰',
    720: '۱۲:۰۰',
    960: '۱۶:۰۰',
    1050: '۱۷:۳۰',
  };

  /// انواع ملاقات — همان سه مقدار سرور
  static const List<String> kinds = ['حضوری', 'آنلاین', 'تلفنی'];

  /// epoch-seconds یک بازه از (روز، دقیقه‌ی آغاز)
  static int startsAtOf(int day, int slotMinutes) {
    return monthStartEpochSeconds + (day - 1) * 86400 + slotMinutes * 60;
  }

  /// برچسب بازه از دقیقه‌ی آغاز — ناشناخته = رشته‌ی خالی (مثل سرور)
  static String labelOfSlotMinutes(int minutes) {
    return slotLabels[minutes] ?? '';
  }

  /// دقیقه‌ی آغاز از برچسب بازه — ناشناخته = null
  static int? slotMinutesOf(String label) {
    for (final entry in slotLabels.entries) {
      if (entry.value == label) return entry.key;
    }
    return null;
  }

  /// کلید یکتای بازه در مجموعه‌ی «اشغال‌ها» — قالب همان زوج (day, slot) سرور
  static String takenKey(int day, String slotLabel) => '$day:$slotLabel';

  /// آیا روز کاملاً بسته است؟ (همه‌ی بازه‌ها گذشته یا اشغال‌شده)
  static bool isDayClosed({
    required int day,
    required Set<String> taken,
    required int nowSeconds,
  }) {
    for (final entry in slotLabels.entries) {
      final startsAt = startsAtOf(day, entry.key);
      if (startsAt <= nowSeconds) continue;
      if (taken.contains(takenKey(day, entry.value))) continue;
      return false;
    }
    return true;
  }

  /// روز شمسی + برچسب بازه → تاریخ شمسی ساعت‌دار (برای نمایش)
  static JalaliDate jalaliOfDay(int day) {
    return JalaliDate(contractYear, contractMonth, day);
  }
}
