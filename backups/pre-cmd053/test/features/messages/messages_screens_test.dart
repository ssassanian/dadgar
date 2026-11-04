/// CMD-051 — بازنویسی از صفر؛ نسل S
///
/// تست ویجت صفحات پیام/تیکت/گفتگو با کیت «دادگر S».
///
/// دروازه‌های رفتاری قدیم حفظ شده است: نگاشت `mine` سرور → DsBubble.mine
/// (خودم=چپ در RTL — F6 کد معیار است)، پیشوند «شما:» گزیده‌ی خودی،
/// ارسال/پاسخ/ثبت با فیک آب‌بند (sendArgs/replyArgs/createTicketArgs)،
/// برچسب نقش فقط روی حباب غیرخودی، حالت‌های صادقانه (S-4) و مسیرها.
///
/// حول DsRing هرگز pumpAndSettle نمی‌زنیم (انیمیشن بی‌پایان است) — فقط
/// pump با مدت ثابت.
library;

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/design/ds_kit.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/messages/domain/chat_models.dart';
import 'package:dadgar_mobile/features/messages/domain/ticket_models.dart';
import 'package:dadgar_mobile/features/messages/presentation/chat_screen.dart';
import 'package:dadgar_mobile/features/messages/presentation/new_ticket_screen.dart';
import 'package:dadgar_mobile/features/messages/presentation/ticket_detail_screen.dart';
import 'package:dadgar_mobile/features/messages/presentation/tickets_screen.dart';
import 'package:dadgar_mobile/features/messages/presentation/threads_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fakes.dart';

/// پمپ ثابت — بدون pumpAndSettle (بارگذاری با DsRing بی‌پایان است)
Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
  Widget child,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 100));
}

/// پمپ با روتر مینیمال — برای صفحه‌هایی که context.go می‌زنند
/// (ثبت تیکت موفق → '/tickets/:id')؛ مقصد ساختگی برای وارسی مسیر.
Future<void> _pumpRouted(
  WidgetTester tester,
  ProviderContainer container,
  GoRouterWidgetBuilder builder,
) async {
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: builder),
      GoRoute(
        path: '/tickets/:id',
        builder: (_, state) => Scaffold(
          appBar: DsTopBar('مقصد تیکت ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 100));
}

Thread _thread({int caseId = 7, bool lastMine = false}) => Thread(
      caseId: caseId,
      title: 'اختلاف بر سر مبیع',
      category: 'قرارداد',
      status: 'assigned',
      lastAt: 1792701000,
      lastExcerpt: 'سلام، لایحه آماده شد',
      lastMine: lastMine,
    );

void main() {
  group('ThreadsScreen — گفتگوهای پرونده (نسل S)', () {
    testWidgets('ردیف گفتگو: عنوان/گزیده/تاریخ + شمارنده‌ی زیرنویس',
        (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: FakeMessagesRepository(threads: [_thread()]),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const ThreadsScreen());

      expect(find.text('پیام‌ها'), findsOneWidget);
      expect(find.text('۱ گفتگو'), findsOneWidget);
      expect(find.text('اختلاف بر سر مبیع'), findsOneWidget);
      expect(find.text('سلام، لایحه آماده شد'), findsOneWidget);
      // پیشوند «شما:» فقط برای پیام خودی
      expect(find.textContaining('شما: '), findsNothing);
    });

    testWidgets('گزیده‌ی خودی پیشوند «شما:» می‌گیرد', (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository:
            FakeMessagesRepository(threads: [_thread(lastMine: true)]),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const ThreadsScreen());
      expect(find.text('شما: سلام، لایحه آماده شد'), findsOneWidget);
    });

    testWidgets('خالی صادقانه — پیام سرور برای بی‌وکیل', (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: FakeMessagesRepository(),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const ThreadsScreen());
      expect(find.text('هنوز گفتگویی فعال نیست'), findsOneWidget);
      expect(
        find.text('گفتگوی هر پرونده پس از تخصیص وکیل باز می‌شود.'),
        findsOneWidget,
      );
    });
  });

  group('ChatScreen — گفتگوی پرونده (نسل S)', () {
    ChatEnvelope envelope() => ChatEnvelope(
          caseId: 7,
          caseTitle: 'اختلاف بر سر مبیع',
          caseStatus: 'assigned',
          rows: const [
            ChatMessage(
              id: 1,
              mine: false,
              role: 'lawyer',
              body: 'لایحه را بررسی کردم',
              createdAt: 1792701000,
            ),
            ChatMessage(
              id: 2,
              mine: true,
              role: 'client',
              body: 'ممنون از پیگیری',
              createdAt: 1792701060,
            ),
          ],
        );

    testWidgets('عنوان واقعی پرونده + دو حباب با نگاشت mine سرور',
        (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository:
            FakeMessagesRepository(envelopes: {7: envelope()}),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const ChatScreen(caseId: 7));

      expect(find.text('اختلاف بر سر مبیع'), findsOneWidget);
      expect(find.text('لایحه را بررسی کردم'), findsOneWidget);
      expect(find.text('ممنون از پیگیری'), findsOneWidget);
      // برچسب نقش سرور فقط روی حباب غیرخودی
      expect(find.text('وکیل'), findsOneWidget);

      // دروازه‌ی F6 (سمت کد = قرارداد فارسی): نگاشت mine → DsBubble.mine
      final mineBubble = tester.widget<DsBubble>(
        find.ancestor(
          of: find.text('ممنون از پیگیری'),
          matching: find.byType(DsBubble),
        ).first,
      );
      final themBubble = tester.widget<DsBubble>(
        find.ancestor(
          of: find.text('لایحه را بررسی کردم'),
          matching: find.byType(DsBubble),
        ).first,
      );
      expect(mineBubble.mine, isTrue);
      expect(themBubble.mine, isFalse);
    });

    testWidgets('چت خالی — پیام عین طرح', (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: FakeMessagesRepository(
          envelopes: {
            7: ChatEnvelope(
              caseId: 7,
              caseTitle: 'پرونده',
              caseStatus: 'assigned',
              rows: const [],
            ),
          },
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const ChatScreen(caseId: 7));
      expect(
        find.text('گفتگویی ثبت نشده — اولین پیام را بفرستید.'),
        findsOneWidget,
      );
    });

    testWidgets('ارسال پیام: متن → sendArgs با متن یکسان + پاک‌شدن مسیر فراخوانی',
        (tester) async {
      final messages = FakeMessagesRepository(
        envelopes: {
          7: ChatEnvelope(
            caseId: 7,
            caseTitle: 'پرونده',
            caseStatus: 'assigned',
            rows: const [],
          ),
        },
      );
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: messages,
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const ChatScreen(caseId: 7));

      await tester.enterText(find.byType(TextField), 'سلام وکیل');
      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));

      expect(messages.sendCalls, 1);
      expect(messages.sendArgs.single, (caseId: 7, body: 'سلام وکیل'));
    });
  });

  group('TicketsScreen — فهرست تیکت‌ها (نسل S)', () {
    testWidgets('کارت تیکت: قرص وضعیت/موضوع/بخش/شمار پیام + شمارنده',
        (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: FakeMessagesRepository(
          tickets: const [
            TicketSummary(
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
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const TicketsScreen());

      expect(find.text('تیکت‌های پشتیبانی'), findsOneWidget);
      expect(find.text('۱ تیکت'), findsOneWidget);
      expect(find.text('مشکل در ورود'), findsOneWidget);
      expect(find.text('پاسخ داده‌شده'), findsOneWidget);
      expect(find.text('تیکت ۵'), findsOneWidget);
      expect(find.text('فنی'), findsOneWidget);
      expect(find.text('۳ پیام'), findsOneWidget);
      // دکمه‌ی اقدام بالای فهرست — جایگزین FAB قدیمی
      expect(find.text('تیکت جدید'), findsOneWidget);
    });

    testWidgets('خالی صادقانه + اقدام تیکت جدید', (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: FakeMessagesRepository(),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const TicketsScreen());
      expect(find.text('هنوز تیکتی ثبت نکرده‌اید'), findsOneWidget);
      expect(find.text('تیکت جدید'), findsOneWidget);
    });

    testWidgets('خطای ۴۰۱ صادقانه (D-6) + تلاش دوباره', (tester) async {
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: FakeMessagesRepository(
          failWith: const ApiException('no', statusCode: 401),
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const TicketsScreen());
      expect(find.textContaining('D-6'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
    });
  });

  group('NewTicketScreen — ثبت تیکت (نسل S)', () {
    testWidgets('اعتبارسنجی: بخش انتخاب‌نشده → پیام کنترلر بدون فراخوانی',
        (tester) async {
      final messages = FakeMessagesRepository();
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: messages,
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const NewTicketScreen());

      // دکمه‌ی ثبت پایین فرم است — ابتدا به دید بیاور
      await tester.ensureVisible(find.text('ثبت تیکت'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('ثبت تیکت'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('بخش را انتخاب کنید'), findsOneWidget);
      expect(messages.createTicketCalls, 0);
    });

    testWidgets('انتخاب بخش/اولویت از شیت + ثبت موفق → آرگومان‌ها و مسیر',
        (tester) async {
      final messages = FakeMessagesRepository();
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: messages,
      );
      addTearDown(container.dispose);

      await _pumpRouted(tester, container, (_, __) => const NewTicketScreen());

      // انتخاب بخش از شیت نسل S — گزینه‌ها در ویوپورت اسکرول‌شیت‌اند:
      // ابتدا ensureVisible (درس ACT-097)
      await tester.tap(find.byKey(const ValueKey('picker-dept')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('فنی'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('فنی'));
      await tester.pump(const Duration(milliseconds: 400));

      // انتخاب اولویت از شیت نسل S — شیت با ستون shrink-wrap کل گزینه‌ها
      // را نشان می‌دهد (اصلاح CMD-051)؛ دو پمپ ۴۰۰ms برای نشستن شیت
      await tester.tap(find.byKey(const ValueKey('picker-priority')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('بالا'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(
        find.byKey(const ValueKey('field-subject')),
        'موضوع تستی',
      );
      await tester.enterText(
        find.byKey(const ValueKey('field-body')),
        'متن کامل تست',
      );

      // دکمه‌ی ثبت پایین فرم است — ابتدا به دید بیاور
      await tester.ensureVisible(find.text('ثبت تیکت'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('ثبت تیکت'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));

      expect(messages.createTicketCalls, 1);
      expect(
        messages.createTicketArgs.single,
        (
          subject: 'موضوع تستی',
          dept: 'فنی',
          priority: 'بالا',
          body: 'متن کامل تست',
        ),
      );
      // مسیر حفظ‌شده: '/tickets/:id' پس از ثبت موفق
      expect(find.textContaining('مقصد تیکت'), findsOneWidget);
    });
  });

  group('TicketDetailScreen — گفتگوی تیکت (نسل S)', () {
    TicketDetail detail({String status = 'answered'}) => TicketDetail(
          id: 9,
          subject: 'مشکل در ورود',
          dept: 'فنی',
          priority: 'بالا',
          status: status,
          createdAt: 1792701000,
          updatedAt: 1792787400,
          messages: const [
            TicketMessage(
              id: 1,
              mine: false,
              role: 'lawyer',
              body: 'بررسی می‌کنیم',
              createdAt: 1792701000,
            ),
            TicketMessage(
              id: 2,
              mine: true,
              role: 'client',
              body: 'سؤال داشتم',
              createdAt: 1792701060,
            ),
          ],
        );

    testWidgets('سربرگ + حباب‌ها با نگاشت mine + برچسب وکیل؛ پاسخ → replyArgs',
        (tester) async {
      final messages = FakeMessagesRepository(ticketDetails: {9: detail()});
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: messages,
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const TicketDetailScreen(ticketId: 9));

      expect(find.text('گفتگوی تیکت'), findsOneWidget);
      expect(find.text('مشکل در ورود'), findsOneWidget);
      expect(find.text('پاسخ داده‌شده'), findsOneWidget);
      expect(find.text('بررسی می‌کنیم'), findsOneWidget);
      expect(find.text('سؤال داشتم'), findsOneWidget);
      // برچسب نقش سرور فقط روی حباب غیرخودی
      expect(find.text('وکیل'), findsOneWidget);
      // نگاشت mine سرور → DsBubble.mine (F6: خودم=چپ در RTL)
      expect(
        tester
            .widget<DsBubble>(
              find.ancestor(
                of: find.text('سؤال داشتم'),
                matching: find.byType(DsBubble),
              ).first,
            )
            .mine,
        isTrue,
      );
      expect(
        tester
            .widget<DsBubble>(
              find.ancestor(
                of: find.text('بررسی می‌کنیم'),
                matching: find.byType(DsBubble),
              ).first,
            )
            .mine,
        isFalse,
      );

      await tester.enterText(
        find.byKey(const ValueKey('composer-reply')),
        'پاسخ من',
      );
      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));

      expect(messages.replyCalls, 1);
      expect(messages.replyArgs.single, (id: 9, body: 'پاسخ من'));
      expect(find.text('پاسخ ارسال شد'), findsOneWidget);
    });

    testWidgets('تیکت بسته: دکمه‌ی پاسخ غیرفعال و بدون فراخوانی',
        (tester) async {
      final messages = FakeMessagesRepository(
        ticketDetails: {9: detail(status: 'closed')},
      );
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        messagesRepository: messages,
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const TicketDetailScreen(ticketId: 9));

      expect(find.text('بسته'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(messages.replyCalls, 0);
    });
  });
}
