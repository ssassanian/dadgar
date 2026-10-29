/// تست قرارداد پرونده‌ها — آینه‌ی CMD-003 سرور (web.js)
///
/// شکست این تست = انحراف موبایل از قرارداد سرور → توقف فاز (DOC-04 §۹-۵)
library;

import 'package:dadgar_mobile/features/cases/data/cases_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CasesContract — آینه‌ی ثابت‌های سرور', () {
    test('اندازه‌ی صفحه و خلاصه دقیقاً مثل web.js', () {
      expect(CasesContract.casesPer, 10); // CASES_PER
      expect(CasesContract.excerptLen, 160); // EXCERPT_LEN
      expect(CasesContract.maxPage, 500); // int(..., 1, 500, 'صفحه')
    });

    test('شش دسته‌ی CATS با ترتیب و نگارش دقیق سرور', () {
      expect(
        CasesContract.cats,
        ['ملکی', 'خانواده', 'کیفری', 'شرکت‌ها', 'ارث و وصیت', 'قرارداد'],
      );
      expect(CasesContract.cats.length, 6);
    });

    test('برچسب وضعیت‌ها = نقشه‌ی ST رابط وب', () {
      expect(CasesContract.labelOfStatus('waiting'), 'در انتظار بررسی');
      expect(CasesContract.labelOfStatus('proposing'), 'در حال پیشنهاد');
      expect(CasesContract.labelOfStatus('assigned'), 'تخصیص‌یافته');
      expect(CasesContract.labelOfStatus('running'), 'در حال انجام');
      expect(CasesContract.labelOfStatus('done'), 'بسته‌شده');
      // ناشناخته = مقدار خام (رفتار stK سرور)
      expect(CasesContract.labelOfStatus('unknown_x'), 'unknown_x');
    });

    test('محدوده‌های POST = str(c.body.title, 5, 120) و 5000', () {
      expect(CasesContract.titleMin, 5);
      expect(CasesContract.titleMax, 120);
      expect(CasesContract.descriptionMax, 5000);
    });

    test('validateTitle — کوتاه/بلند/مرزی مثل سرور', () {
      expect(CasesContract.validateTitle(''), isNotNull);
      expect(CasesContract.validateTitle('abcd'), isNotNull); // ۴ نویسه
      expect(CasesContract.validateTitle('abcde'), isNull); // ۵ نویسه = مرز
      expect(
        CasesContract.validateTitle('a' * 120),
        isNull,
      ); // ۱۲۰ نویسه = مرز
      expect(CasesContract.validateTitle('a' * 121), isNotNull);
    });

    test('validateDescription — سقف ۵۰۰۰', () {
      expect(CasesContract.validateDescription(''), isNull); // اختیاری
      expect(CasesContract.validateDescription('ا' * 5000), isNull);
      expect(
        CasesContract.validateDescription('ا' * 5001),
        isNotNull,
      );
    });

    test('پیام‌های سرور عیناً آینه شده‌اند', () {
      expect(
        CasesContract.notFoundMessage,
        'پرونده یافت نشد.',
      );
      expect(
        CasesContract.rateLimitMessage,
        'سقف ثبت پرونده در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
      );
    });
  });
}
