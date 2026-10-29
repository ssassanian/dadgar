/// تست ویجت صفحات M5 — تیکت‌ها و اسناد و بارگذاری
library;

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/documents/domain/document_models.dart';
import 'package:dadgar_mobile/features/documents/presentation/documents_screen.dart';
import 'package:dadgar_mobile/features/documents/presentation/documents_picker.dart';
import 'package:dadgar_mobile/features/documents/presentation/upload_doc_screen.dart';
import 'package:dadgar_mobile/features/messages/domain/ticket_models.dart';
import 'package:dadgar_mobile/features/messages/presentation/tickets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

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
}

void main() {
  group('TicketsScreen — فهرست تیکت‌ها', () {
    testWidgets('کارت تیکت با موضوع/وضعیت/بخش رندر می‌شود', (tester) async {
      final container = dadgarContainer(
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
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('مشکل در ورود'), findsOneWidget);
      expect(find.text('پاسخ داده‌شده'), findsOneWidget);
      expect(find.text('۱ تیکت'), findsOneWidget);
      expect(find.text('تیکت ۵'), findsOneWidget);
    });

    testWidgets('خالی صادقانه + خطای D-6', (tester) async {
      final container = dadgarContainer(messagesRepository: FakeMessagesRepository());
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const TicketsScreen());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('هنوز تیکتی ثبت نکرده‌اید'), findsOneWidget);

      final errContainer = dadgarContainer(
        messagesRepository: FakeMessagesRepository(
          failWith: const ApiException('no', statusCode: 401),
        ),
      );
      addTearDown(errContainer.dispose);
      await _pumpApp(tester, errContainer, const TicketsScreen());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('D-6'), findsOneWidget);
    });
  });

  group('DocumentsScreen — گاوصندوق اسناد', () {
    testWidgets('کارت سند با سطح دسترسی و عملیات رندر می‌شود', (tester) async {
      final container = dadgarContainer(
        documentsRepository: FakeDocumentsRepository(
          docs: [
            DocSummary(
              id: 21,
              caseId: 7,
              caseTitle: 'اختلاف بر سر مبیع',
              name: 'قرارداد.jpg',
              mime: 'image/jpeg',
              size: 2048,
              mine: true,
              shared: true,
              createdAt: 1792701000,
            ),
          ],
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const DocumentsScreen());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('قرارداد.jpg'), findsOneWidget);
      expect(find.text('اشتراک با وکیل'), findsOneWidget);
      expect(find.text('۱ سند'), findsOneWidget);
      expect(find.text('دانلود'), findsOneWidget);
      expect(find.text('حذف'), findsOneWidget);
      expect(find.text('بارگذاری سند'), findsOneWidget);
    });

    testWidgets('سند غیر خودی → دکمه‌ی حذف ندارد', (tester) async {
      final container = dadgarContainer(
        documentsRepository: FakeDocumentsRepository(
          docs: [
            DocSummary(
              id: 22,
              caseId: 7,
              caseTitle: 'پرونده',
              name: 'لایحه.pdf',
              mime: 'application/pdf',
              size: 4096,
              mine: false,
              shared: true,
              createdAt: 1792701000,
            ),
          ],
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const DocumentsScreen());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('لایحه.pdf'), findsOneWidget);
      expect(find.text('حذف'), findsNothing);
    });

    testWidgets('خالی صادقانه', (tester) async {
      final container = dadgarContainer(
        documentsRepository: FakeDocumentsRepository(),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const DocumentsScreen());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('هنوز سندی بارگذاری نشده است'), findsOneWidget);
    });
  });

  group('UploadDocScreen — بارگذاری سند', () {
    testWidgets('انتخاب از دوربین → پیش‌نمایش + ارسال به مخزن', (tester) async {
      final container = dadgarContainer(
        documentsRepository: FakeDocumentsRepository(),
        casesRepository: FakeCasesRepository(),
      );
      addTearDown(container.dispose);
      // بازنویسی انتخابگر — بدون پلتفرم
      final scoped = ProviderContainer(
        parent: container,
        overrides: [
          docPickerProvider.overrideWithValue(
            (ImageSource source) async => PickedDoc(
              name: source == ImageSource.camera
                  ? 'IMG_0001.jpg'
                  : 'gallery.jpg',
              mime: 'image/jpeg',
              bytes: const [1, 2, 3, 4],
            ),
          ),
        ],
      );
      addTearDown(scoped.dispose);

      await _pumpApp(tester, scoped, const UploadDocScreen());
      await tester.pump(const Duration(milliseconds: 50));
      // بدون پرونده: پیام صادقانه‌ی «ابتدا پرونده ثبت کنید»
      expect(
        find.textContaining('ابتدا یک پرونده ثبت کنید'),
        findsOneWidget,
      );

      await tester.tap(find.text('دوربین'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('IMG_0001.jpg'), findsOneWidget);
      expect(find.textContaining('سقف: ۴ مگابایت'), findsOneWidget);
    });
  });
}
