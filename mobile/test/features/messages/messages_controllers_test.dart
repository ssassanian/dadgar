/// تست کنترلرهای تیکت و چت — M5
library;

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/messages/application/chat_controller.dart';
import 'package:dadgar_mobile/features/messages/application/tickets_controller.dart';
import 'package:dadgar_mobile/features/messages/domain/chat_models.dart';
import 'package:dadgar_mobile/features/messages/domain/ticket_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

Future<void> _pump(void Function() check) async {
  for (var i = 0; i < 50; i++) {
    try {
      check();
      return;
    } on Object {
      // ادامه‌ی پمپ تا برقراری شرط
    }
    await Future<void>.delayed(Duration.zero);
  }
  check(); // آخرین تلاش برای نمایش خطای واقعی
}

TicketDetail _detail({
  String status = 'open',
  List<TicketMessage> messages = const [],
}) =>
    TicketDetail(
      id: 9,
      subject: 'پیگیری نوبت',
      dept: 'عمومی',
      priority: 'کم',
      status: status,
      createdAt: 1792701000,
      updatedAt: 1792702000,
      messages: messages,
    );

void main() {
  group('TicketsController — فهرست تیکت‌ها', () {
    test('بارگذاری اول → ردیف‌ها؛ خطا → پیام صادقانه‌ی D-6', () async {
      final repo = FakeMessagesRepository(
        tickets: [
          const TicketSummary(
            id: 5,
            subject: 'مشکل در ورود',
            dept: 'فنی',
            priority: 'بالا',
            status: 'answered',
            createdAt: 1792701000,
            updatedAt: 1792787400,
            msgCount: 3,
          ),
        ],
      );
      final container = dadgarContainer(messagesRepository: repo);
      addTearDown(container.dispose);

      container.read(ticketsControllerProvider.notifier);
      await _pump(
        () => expect(
          container.read(ticketsControllerProvider).status,
          LoadStatus.ready,
        ),
      );
      expect(
        container.read(ticketsControllerProvider).rows.single.id,
        5,
      );

      // خطای 401
      repo.failWith = const ApiException('no', statusCode: 401);
      await container.read(ticketsControllerProvider.notifier).reload();
      final ui = container.read(ticketsControllerProvider);
      expect(ui.isError, isTrue);
      expect(ui.message, contains('D-6'));
    });
  });

  group('NewTicketController — ثبت تیکت', () {
    test('اعتبارسنجی آینه‌ی سرور: موضوع کوتاه رد می‌شود', () async {
      final repo = FakeMessagesRepository();
      final container = dadgarContainer(messagesRepository: repo);
      addTearDown(container.dispose);

      final c = container.read(newTicketControllerProvider.notifier);
      c.setSubject('ab');
      c.setDept('عمومی');
      c.setPriority('کم');
      c.setBody('متن درست');
      final id = await c.submit();
      expect(id, isNull);
      expect(repo.createTicketCalls, 0);
    });

    test('بخش/اولویت انتخاب‌نشده رد می‌شود', () async {
      final repo = FakeMessagesRepository();
      final container = dadgarContainer(messagesRepository: repo);
      addTearDown(container.dispose);

      final c = container.read(newTicketControllerProvider.notifier);
      c.setSubject('موضوع درست');
      c.setBody('متن درست');
      final id = await c.submit();
      expect(id, isNull);
      expect(container.read(newTicketControllerProvider).message,
          'بخش را انتخاب کنید');
    });

    test('ثبت موفق → شناسه‌ی تیکت + آرگومان‌های پاک‌سازی‌شده', () async {
      final repo = FakeMessagesRepository();
      final container = dadgarContainer(messagesRepository: repo);
      addTearDown(container.dispose);

      final c = container.read(newTicketControllerProvider.notifier);
      c.setSubject('  درخواست اصلاح  ');
      c.setDept('مالی');
      c.setPriority('متوسط');
      c.setBody('  شرح درخواست  ');
      final id = await c.submit();
      expect(id, 77);
      final args = repo.createTicketArgs.single;
      expect(args.subject, 'درخواست اصلاح');
      expect(args.body, 'شرح درخواست');
      expect(args.dept, 'مالی');
    });

    test('۴۲۹ → پیام عین سرور', () async {
      final repo = FakeMessagesRepository(
        failWith: const ApiException(
          'سقف ارسال تیکت در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
          statusCode: 429,
        ),
      );
      final container = dadgarContainer(messagesRepository: repo);
      addTearDown(container.dispose);

      final c = container.read(newTicketControllerProvider.notifier);
      c.setSubject('موضوع درست');
      c.setDept('عمومی');
      c.setPriority('کم');
      c.setBody('متن درست');
      final id = await c.submit();
      expect(id, isNull);
      expect(
        container.read(newTicketControllerProvider).message,
        'سقف ارسال تیکت در یک ساعت تکمیل شده است. بعداً تلاش کنید.',
      );
    });
  });

  group('TicketDetailController — گفتگوی تیکت', () {
    test('بارگذاری + پاسخ → بازخوانی با وضعیت جدید سرور', () async {
      final repo = FakeMessagesRepository(ticketDetails: {
        9: _detail(
          messages: const [
            TicketMessage(
              id: 1,
              mine: true,
              role: 'client',
              body: 'سلام',
              createdAt: 1792701500,
            ),
          ],
        ),
      });
      final container = dadgarContainer(messagesRepository: repo);
      addTearDown(container.dispose);

      final provider = ticketDetailProvider(9);
      final c = container.read(provider.notifier);
      await _pump(
        () => expect(container.read(provider).status, LoadStatus.ready),
      );
      expect(container.read(provider).detail!.messages.single.body, 'سلام');

      repo.ticketDetails[9] = _detail(
        status: 'answered',
        messages: const [
          TicketMessage(
            id: 1,
            mine: true,
            role: 'client',
            body: 'سلام',
            createdAt: 1792701500,
          ),
          TicketMessage(
            id: 2,
            mine: false,
            role: 'admin',
            body: 'بررسی شد',
            createdAt: 1792702500,
          ),
        ],
      );
      final ok = await c.sendReply('پیگیری');
      expect(ok, isTrue);
      expect(repo.replyArgs.single.body, 'پیگیری');
      expect(container.read(provider).detail!.status, 'answered');
      expect(container.read(provider).detail!.messages, hasLength(2));
    });

    test('تیکت بسته → پاسخ رد می‌شود با پیام عین سرور', () async {
      final repo = FakeMessagesRepository(ticketDetails: {
        9: _detail(status: 'closed'),
      });
      final container = dadgarContainer(messagesRepository: repo);
      addTearDown(container.dispose);

      final provider = ticketDetailProvider(9);
      final c = container.read(provider.notifier);
      await _pump(
        () => expect(container.read(provider).status, LoadStatus.ready),
      );

      final ok = await c.sendReply('باز هم');
      expect(ok, isFalse);
      expect(repo.replyCalls, 0);
      expect(
        container.read(provider).message,
        'این تیکت بسته شده است؛ برای موضوع جدید تیکت جدیدی باز کنید.',
      );
    });
  });

  group('Threads/Chat — گفتگوی پرونده', () {
    test('فهرست گفتگوها → ردیف‌ها', () async {
      final repo = FakeMessagesRepository(
        threads: const [
          Thread(
            caseId: 7,
            title: 'اختلاف بر سر مبیع',
            category: 'ملکی',
            status: 'assigned',
            lastAt: 1792787400,
            lastExcerpt: 'پیشنهاد شما بررسی شد',
            lastMine: false,
          ),
        ],
      );
      final container = dadgarContainer(messagesRepository: repo);
      addTearDown(container.dispose);

      container.read(threadsControllerProvider.notifier);
      await _pump(
        () => expect(
          container.read(threadsControllerProvider).status,
          LoadStatus.ready,
        ),
      );
      expect(
        container.read(threadsControllerProvider).rows.single.caseId,
        7,
      );
    });

    test('چت: بارگذاری + ارسال → بازخوانی پیام‌ها؛ خطای ۴۰۰ عین سرور',
        () async {
      final repo = FakeMessagesRepository(envelopes: {
        7: const ChatEnvelope(
          caseId: 7,
          caseTitle: 'اختلاف بر سر مبیع',
          caseStatus: 'running',
          rows: [
            ChatMessage(
              id: 3,
              mine: false,
              role: 'lawyer',
              body: 'پیشنهاد شما بررسی شد',
              createdAt: 1792787400,
            ),
          ],
        ),
      });
      final container = dadgarContainer(messagesRepository: repo);
      addTearDown(container.dispose);

      final provider = chatProvider(7);
      final c = container.read(provider.notifier);
      await _pump(
        () => expect(container.read(provider).status, LoadStatus.ready),
      );
      expect(container.read(provider).envelope!.caseTitle, 'اختلاف بر سر مبیع');

      repo.envelopes[7] = const ChatEnvelope(
        caseId: 7,
        caseTitle: 'اختلاف بر سر مبیع',
        caseStatus: 'running',
        rows: [
          ChatMessage(
            id: 3,
            mine: false,
            role: 'lawyer',
            body: 'پیشنهاد شما بررسی شد',
            createdAt: 1792787400,
          ),
          ChatMessage(
            id: 4,
            mine: true,
            role: 'client',
            body: 'ممنون',
            createdAt: 1792788000,
          ),
        ],
      );
      final ok = await c.send(' ممنون ');
      expect(ok, isTrue);
      expect(repo.sendArgs.single.body, 'ممنون');
      expect(container.read(provider).envelope!.rows, hasLength(2));

      // خطای ۴۰۰ گفتگوی غیرفعال
      repo.failWith = const ApiException(
        'گفتگوی این پرونده هنوز فعال نیست؛ پس از تخصیص وکیل باز می‌شود.',
        statusCode: 400,
      );
      final ok2 = await c.send('باز هم');
      expect(ok2, isFalse);
      expect(
        container.read(provider).message,
        'گفتگوی این پرونده هنوز فعال نیست؛ پس از تخصیص وکیل باز می‌شود.',
      );
    });
  });
}
