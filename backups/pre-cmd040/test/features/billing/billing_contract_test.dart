/// تست قرارداد مالی — آینه‌ی ثابت‌های CMD-005 + قالب مبلغ
library;

import 'package:dadgar_mobile/features/billing/data/billing_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BillingContract — آینه‌ی CMD-005', () {
    test('ثابت‌های سرور عیناً: سقف ۳۰۰، بازه‌ی مبلغ', () {
      expect(BillingContract.invLimit, 300);
      expect(BillingContract.amountMin, 1000);
      expect(BillingContract.amountMax, 10000000000);
    });

    test('برچسب وضعیت‌ها = نقشه‌ی BIST وب', () {
      expect(BillingContract.labelOfStatus('pending'), 'در انتظار');
      expect(BillingContract.labelOfStatus('paid'), 'پرداخت‌شده');
      // ناشناخته = مقدار خام (مثل سرور)
      expect(BillingContract.labelOfStatus('unknown'), 'unknown');
    });

    test('پیام‌های صادقانه عین متن وب', () {
      expect(
        BillingContract.paymentGatewayMessage,
        'درگاه پرداخت هنوز متصل نشده است؛ پس از تصمیم مدیر فعال می‌شود.',
      );
      expect(
        BillingContract.emptyMessage,
        'هنوز فاکتوری برای شما صادر نشده است.',
      );
      expect(BillingContract.lawyerForbiddenMessage, 'دسترسی ندارید.');
    });

    test('formatToman: جداکننده‌ی هزارگان + ارقام فارسی', () {
      expect(BillingContract.formatToman(25000000), '۲۵٬۰۰۰٬۰۰۰ تومان');
      expect(BillingContract.formatToman(1000), '۱٬۰۰۰ تومان');
      expect(BillingContract.formatToman(950), '۹۵۰ تومان');
      expect(BillingContract.formatToman(0), '۰ تومان');
    });

    test('toPersianDigits: تبدیل کامل ارقام لاتین', () {
      expect(BillingContract.toPersianDigits(123), '۱۲۳');
      expect(BillingContract.toPersianDigits('فاکتور 45'), 'فاکتور ۴۵');
    });
  });
}
