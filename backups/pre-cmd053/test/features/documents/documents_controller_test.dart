/// تست کنترلر اسناد — فهرست/آپلود با سقف ۴MB/دانلود با ذخیره‌ساز فیک/حذف
library;

import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/documents/application/documents_controller.dart';
import 'package:dadgar_mobile/features/documents/domain/document_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

DocSummary _doc(int id, {bool mine = true}) => DocSummary(
      id: id,
      caseId: 7,
      caseTitle: 'اختلاف بر سر مبیع',
      name: 'سند $id.jpg',
      mime: 'image/jpeg',
      size: 2048,
      mine: mine,
      shared: true,
      createdAt: 1792701000,
    );

Future<void> _pumpReady(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    if (container.read(documentsControllerProvider).status ==
        LoadStatus.ready) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('بارگذاری فهرست اسناد برقرار نشد');
}

void main() {
  ProviderContainer buildContainer(
    FakeDocumentsRepository repo, {
    String? savedPath,
  }) {
    final container = ProviderContainer(
      overrides: [
        documentsRepositoryProvider.overrideWithValue(repo),
        docSaverProvider.overrideWithValue(
          (name, bytes) async => savedPath ?? '/tmp/$name',
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('بارگذاری اول → ردیف‌ها؛ خطای 401 → پیام صادقانه‌ی D-6', () async {
    final repo = FakeDocumentsRepository(docs: [_doc(21)]);
    final container = buildContainer(repo);
    container.read(documentsControllerProvider.notifier);
    await _pumpReady(container);
    expect(container.read(documentsControllerProvider).rows.single.id, 21);

    repo.failWith = const ApiException('no', statusCode: 401);
    await container.read(documentsControllerProvider.notifier).reload();
    final ui = container.read(documentsControllerProvider);
    expect(ui.status, LoadStatus.error);
    expect(ui.message, contains('D-6'));
  });

  test('آپلود: سقف ۴MB سمت کاربر رد می‌شود (بدون درخواست شبکه)', () async {
    final repo = FakeDocumentsRepository();
    final container = buildContainer(repo);
    container.read(documentsControllerProvider.notifier);
    await _pumpReady(container);

    final big = PickedDoc(
      name: 'big.jpg',
      mime: 'image/jpeg',
      bytes: List<int>.filled(4 * 1024 * 1024 + 1, 1),
    );
    final ok = await container
        .read(documentsControllerProvider.notifier)
        .upload(big, caseId: 7);
    expect(ok, isFalse);
    expect(repo.uploadCalls, 0);
    expect(
      container.read(documentsControllerProvider).message,
      'حجم سند بیش از ۴ مگابایت است',
    );
  });

  test('آپلود موفق → بازخوانی فهرست؛ پیام موفقیت', () async {
    final repo = FakeDocumentsRepository(docs: []);
    final container = buildContainer(repo);
    container.read(documentsControllerProvider.notifier);
    await _pumpReady(container);

    final ok = await container
        .read(documentsControllerProvider.notifier)
        .upload(
          const PickedDoc(
            name: 'مدرک.jpg',
            mime: 'image/jpeg',
            bytes: [1, 2, 3],
          ),
          caseId: 7,
        );
    expect(ok, isTrue);
    final args = repo.uploadArgs.single;
    expect(args.caseId, 7);
    expect(args.name, 'مدرک.jpg');
    expect(container.read(documentsControllerProvider).message,
        'سند بارگذاری شد');
  });

  test('دانلود → ذخیره‌ساز تزریق‌شده صدا زده می‌شود', () async {
    final repo = FakeDocumentsRepository(docs: [_doc(21)]);
    var savedName = '';
    final container = ProviderContainer(
      overrides: [
        documentsRepositoryProvider.overrideWithValue(repo),
        docSaverProvider.overrideWithValue((name, bytes) async {
          savedName = name;
          return '/tmp/$name';
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(documentsControllerProvider.notifier);
    await _pumpReady(container);

    final path = await container
        .read(documentsControllerProvider.notifier)
        .download(_doc(21));
    expect(path, '/tmp/$savedName');
    expect(savedName, contains('سند 21')); // نام سند در نام فایل ذخیره
    expect(repo.downloadIds.single, 21);
  });

  test('حذف: سند غیر خودی رد می‌شود؛ سند خودی حذف و فهرست تازه می‌شود',
      () async {
    final repo = FakeDocumentsRepository(docs: [_doc(21), _doc(22, mine: false)]);
    final container = buildContainer(repo);
    container.read(documentsControllerProvider.notifier);
    await _pumpReady(container);

    final c = container.read(documentsControllerProvider.notifier);
    final okOther = await c.remove(_doc(22, mine: false));
    expect(okOther, isFalse);
    expect(repo.deleteCalls, 0);

    final okMine = await c.remove(_doc(21));
    expect(okMine, isTrue);
    expect(repo.deleteIds.single, 21);
    expect(
      container.read(documentsControllerProvider).message,
      'سند حذف شد',
    );
  });
}
