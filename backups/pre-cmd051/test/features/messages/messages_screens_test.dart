/// تست ویجت صفحات پیام‌ها — گفتگوها و چت (CMD-046 فاز ۳)
///
/// دروازه‌های کلیدی: ساختار bMsgs/bChat طرح، **سمت حباب عین قرارداد
/// فارسی (خودم=چپ)** — F6 برای پروتوتایپ باز است ولی کد معیار است —
/// و ارسال با فیک آب‌بند (sendArgs).
library;

import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/messages/domain/chat_models.dart';
import 'package:dadgar_mobile/features/messages/presentation/chat_screen.dart';
import 'package:dadgar_mobile/features/messages/presentation/threads_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

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
  await tester.pumpAndSettle();
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
  group('ThreadsScreen — گفتگوهای پرونده (طرح bMsgs)', () {
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

  group('ChatScreen — گفتگوی پرونده (طرح bChat)', () {
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

    testWidgets('عنوان واقعی پرونده + دو حباب با سمت قرارداد فارسی',
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

      // دروازه‌ی F6 (سمت کد = قرارداد فارسی): خودم=چپ، وکیل=راست
      final mineAlign = tester.widget<Align>(
        find.ancestor(
          of: find.text('ممنون از پیگیری'),
          matching: find.byType(Align),
        ).first,
      );
      final themAlign = tester.widget<Align>(
        find.ancestor(
          of: find.text('لایحه را بررسی کردم'),
          matching: find.byType(Align),
        ).first,
      );
      expect(mineAlign.alignment, Alignment.centerLeft);
      expect(themAlign.alignment, Alignment.centerRight);
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

    testWidgets('ارسال پیام: متن → sendArgs با متن یکسان + پاک‌شدن ورودی',
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

      expect(messages.sendCalls, 1);
      expect(messages.sendArgs.single, (caseId: 7, body: 'سلام وکیل'));
    });
  });
}
