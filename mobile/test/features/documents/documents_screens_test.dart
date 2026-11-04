/// CMD-051 — بازنویسی از صفر؛ نسل S — تست ویجت صفحات اسناد
///
/// همان پوشش رفتاری نسل قبل (گاوصندوق اسناد + بارگذاری سند) روی درخت
/// ویجت نسل S: سربرگ DsTopBar، کارت‌های گرد سند با قرص دسترسی، شیت
/// پایین showDsSheet، دیالوگ تأیید حذف و حالت‌های صادقانه‌ی
/// DsEmptyState. حافظه‌ی رفتاری عین قدیم: دانلود → SnackBar، حذف فقط
/// اسناد خودی، آپلود از دوربین با سقف ۴ مگابایت.
///
/// نکته‌ی پمپ (بند «تست» حکم CMD-051): DsRing (حالت بارگذاری) انیمیشن
/// بی‌پایان دارد → همه‌جا tester.pump(Duration) و هرگز pumpAndSettle.
///
/// تست تیکت‌ها که پیش‌تر در همین فایل هم‌جوار بود، به گروه «پیام‌ها»
/// تعلق دارد و در فایل تست همان گروه بازنویسی می‌شود (تقسیم گروهی
/// CMD-051).
library;

import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/documents/domain/document_models.dart';
import 'package:dadgar_mobile/features/documents/presentation/documents_screen.dart';
import 'package:dadgar_mobile/features/documents/presentation/documents_picker.dart';
import 'package:dadgar_mobile/features/documents/presentation/upload_doc_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import '../../helpers/fakes.dart';

/// پمپ بدون pumpAndSettle — DsRing بی‌پایان است
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
  await tester.pump(const Duration(milliseconds: 60));
}

/// سند نمونه — پرونده‌ی «اختلاف بر سر مبیع»
DocSummary _doc({
  required int id,
  required String name,
  required bool mine,
  bool shared = true,
}) {
  return DocSummary(
    id: id,
    caseId: 7,
    caseTitle: 'اختلاف بر سر مبیع',
    name: name,
    mime: 'image/jpeg',
    size: 2048,
    mine: mine,
    shared: shared,
    createdAt: 1792701000,
  );
}

void main() {
  group('DocumentsScreen — گاوصندوق اسناد (نسل S)', () {
    testWidgets('سربرگ: عنوان ثابت + شمارنده؛ ردیف سند با قرص دسترسی',
        (tester) async {
      final container = dadgarContainer(
        documentsRepository: FakeDocumentsRepository(
          docs: [_doc(id: 21, name: 'قرارداد.jpg', mine: true)],
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const DocumentsScreen());

      expect(find.text('گاوصندوق اسناد'), findsOneWidget);
      expect(find.text('۱ سند'), findsOneWidget);
      expect(find.text('قرارداد.jpg'), findsOneWidget);
      expect(find.text('اشتراک با وکیل'), findsOneWidget);
      // دکمه‌ی پایان فهرست (FAB حذف شد — CMD-046)
      expect(find.text('آپلود سند جدید'), findsOneWidget);
    });

    testWidgets('شیت عملیات: دانلود → SnackBar؛ حذف با تأیید (سند خودی)',
        (tester) async {
      final repo = FakeDocumentsRepository(
        docs: [_doc(id: 21, name: 'قرارداد.jpg', mine: true)],
      );
      // ذخیره‌ساز باید در همان کانتینری override شود که کنترلر در آن حل
      // می‌شود (کانتینر فرزند به ref والد نمی‌رسد — درس CMD-051)
      final container = dadgarContainer(
        documentsRepository: repo,
        docSaver: (name, bytes) async => '/test/$name',
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const DocumentsScreen());

      // ── دانلود ──
      // شیت با دو پمپ ۴۰۰ms می‌نشیند (هندسه‌ی نهایی پایدار) — بدون
      // ensureVisible روی محتوای شیت (کشف CMD-051: روی شیت بی‌اثر/مخرب)
      await tester.tap(find.text('قرارداد.jpg'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('دانلود'), findsOneWidget);
      expect(find.text('حذف'), findsOneWidget);

      await tester.tap(find.text('دانلود'));
      // حلقه‌ی دانلود + ظاهرشدن SnackBar — پمپ کافی
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('سند در پوشه‌ی اسناد اپ ذخیره شد'), findsOneWidget);
      expect(repo.downloadIds, contains(21));

      // تخلیه‌ی چرخه‌ی SnackBar پیش از شیت دوم
      await tester.pump(const Duration(seconds: 5));

      // ── حذف با دیالوگ تأیید ──
      await tester.tap(find.text('قرارداد.jpg'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('حذف'));
      await tester.pump(const Duration(milliseconds: 400)); // شیت بسته + دیالوگ
      expect(find.text('حذف سند'), findsOneWidget);
      expect(find.text('این سند برای همیشه حذف شود؟'), findsOneWidget);

      // دکمه‌ی تایید دیالوگ — مقید به AlertDialog چون دکمه‌ی شیت در
      // انیمیشن خروج هنوز در درخت است (دو Text هم‌نام)
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('حذف'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.deleteCalls, 1);
      expect(find.text('سند حذف شد'), findsOneWidget);

      // تخلیه‌ی تایمر SnackBar (۴ ثانیه + انیمیشن خروج) — تست نباید با
      // تایمر معلق تمام شود و pumpAndSettle هم مجاز نیست (CMD-051)
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('سند غیر خودی → شیت دکمه‌ی حذف ندارد', (tester) async {
      final container = dadgarContainer(
        documentsRepository: FakeDocumentsRepository(
          docs: [_doc(id: 22, name: 'لایحه.pdf', mine: false)],
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const DocumentsScreen());

      expect(find.text('لایحه.pdf'), findsOneWidget);
      await tester.tap(find.text('لایحه.pdf'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('دانلود'), findsOneWidget);
      expect(find.text('حذف'), findsNothing);
    });

    testWidgets('خالی صادقانه + دکمه‌ی آپلود', (tester) async {
      final container = dadgarContainer(
        documentsRepository: FakeDocumentsRepository(),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const DocumentsScreen());
      expect(find.text('هنوز سندی بارگذاری نشده است'), findsOneWidget);
      expect(find.text('آپلود سند جدید'), findsOneWidget);
    });

    testWidgets('خطای صادقانه‌ی D-6 + تلاش دوباره', (tester) async {
      final container = dadgarContainer(
        documentsRepository: FakeDocumentsRepository(
          failWith: const ApiException('no', statusCode: 401),
        ),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container, const DocumentsScreen());
      expect(find.textContaining('D-6'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
    });
  });

  group('UploadDocScreen — بارگذاری سند', () {
    testWidgets('انتخاب از دوربین → پیش‌نمایش + سقف ۴ مگابایت (بدون پرونده)',
        (tester) async {
      final container = dadgarContainer(
        documentsRepository: FakeDocumentsRepository(),
        casesRepository: FakeCasesRepository(),
      );
      addTearDown(container.dispose);
      // بازنویسی انتخابگر — بدون پلتفرم (DOC-04 §۹)
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

      expect(find.text('بارگذاری سند'), findsOneWidget);
      // بدون پرونده: پیام صادقانه‌ی «ابتدا پرونده ثبت کنید»
      expect(
        find.textContaining('ابتدا یک پرونده ثبت کنید'),
        findsOneWidget,
      );

      await tester.tap(find.text('دوربین'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('IMG_0001.jpg'), findsOneWidget);
      expect(find.textContaining('سقف: ۴ مگابایت'), findsOneWidget);
      expect(find.text('پیش‌نمایش'), findsOneWidget);
    });
  });
}
