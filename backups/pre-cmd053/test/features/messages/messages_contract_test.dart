/// تست قرارداد پیام/تیکت — آینه‌ی ثابت‌های CMD-007
library;

import 'package:dadgar_mobile/features/messages/data/messages_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagesContract — آینه‌ی CMD-007', () {
    test('بخش‌ها و اولویت‌ها عین سرور با همان ترتیب', () {
      expect(
        MessagesContract.tkDepts,
        ['فنی', 'مالی', 'شکایات', 'عمومی', 'حقوقی'],
      );
      expect(MessagesContract.tkPris, ['کم', 'متوسط', 'بالا']);
    });

    test('برچسب وضعیت‌ها = نقشه‌ی TK_ST وب', () {
      expect(MessagesContract.labelOfTicketStatus('open'), 'باز');
      expect(
        MessagesContract.labelOfTicketStatus('review'),
        'در حال بررسی',
      );
      expect(
        MessagesContract.labelOfTicketStatus('answered'),
        'پاسخ داده‌شده',
      );
      expect(MessagesContract.labelOfTicketStatus('closed'), 'بسته');
      expect(MessagesContract.labelOfTicketStatus('x'), 'x');
    });

    test('محدوده‌های اعتبارسنجی عین قواعد سرور', () {
      expect(MessagesContract.subjectMin, 3);
      expect(MessagesContract.subjectMax, 120);
      expect(MessagesContract.ticketBodyMin, 3);
      expect(MessagesContract.ticketBodyMax, 3000);
      expect(MessagesContract.replyBodyMax, 3000);
      expect(MessagesContract.chatBodyMax, 2000);
      expect(MessagesContract.tkLimit, 200);
      expect(MessagesContract.msgLimit, 300);
      expect(MessagesContract.threadsLimit, 50);
      expect(MessagesContract.lastExcerptLen, 80);
    });

    test('اعتبارسنجی فرم تیکت — کوتاه/بلند/مرزی', () {
      expect(MessagesContract.validateSubject('  '), isNotNull);
      expect(MessagesContract.validateSubject('ab'), isNotNull);
      expect(MessagesContract.validateSubject('abc'), isNull);
      expect(
        MessagesContract.validateSubject('x' * 121),
        isNotNull,
      );
      expect(MessagesContract.validateSubject('x' * 120), isNull);
      expect(MessagesContract.validateTicketBody('ab'), isNotNull);
      expect(MessagesContract.validateTicketBody('abc'), isNull);
      expect(
        MessagesContract.validateTicketBody('x' * 3001),
        isNotNull,
      );
    });

    test('اعتبارسنجی پاسخ و پیام چت', () {
      expect(MessagesContract.validateReplyBody(''), isNotNull);
      expect(MessagesContract.validateReplyBody('x'), isNull);
      expect(
        MessagesContract.validateReplyBody('x' * 3001),
        isNotNull,
      );
      expect(MessagesContract.validateChatBody(''), isNotNull);
      expect(MessagesContract.validateChatBody('سلام'), isNull);
      expect(
        MessagesContract.validateChatBody('x' * 2001),
        isNotNull,
      );
    });

    test('پیام‌های خطای سرور عیناً + برچسب نقش‌ها', () {
      expect(
        MessagesContract.ticketRateLimit,
        'سقف ارسال تیکت در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
      );
      expect(
        MessagesContract.ticketClosedMessage,
        'این تیکت بسته شده است؛ برای موضوع جدید تیکت جدیدی باز کنید.',
      );
      expect(
        MessagesContract.chatNotActiveMessage,
        'گفتگوی این پرونده هنوز فعال نیست؛ پس از تخصیص وکیل باز می‌شود.',
      );
      expect(MessagesContract.ticketNotFound, 'تیکت یافت نشد.');
      expect(MessagesContract.labelOfRole('client'), 'موکل');
      expect(MessagesContract.labelOfRole('lawyer'), 'وکیل');
      expect(MessagesContract.labelOfRole('admin'), 'مدیر');
      expect(MessagesContract.labelOfRole('?'), 'کاربر');
    });
  });
}
