import 'package:dadgar_mobile/app/providers.dart';
import 'package:dadgar_mobile/core/api/api_client.dart';
import 'package:dadgar_mobile/features/appointments/application/appointments_controller.dart';
import 'package:dadgar_mobile/features/appointments/data/appointments_contract.dart';
import 'package:dadgar_mobile/features/appointments/domain/appointment.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

/// صفحه‌ی داده‌ی آزمایشی — «الانِ» سرور قبل از آغاز ماه قرارداد
AppointmentsPage _openPage({Set<String> taken = const {}, int todayDay = 7}) {
  return AppointmentsPage(
    rows: const [
      Appointment(
        id: 11,
        startsAt: 0,
        day: 2,
        slot: '۰۹:۰۰',
        kind: 'حضوری',
        status: 'booked',
      ),
    ],
    taken: taken,
    serverNowSeconds: AppointmentContract.monthStartEpochSeconds - 86400,
    todayDay: todayDay,
  );
}

Future<AppointmentsUi> _readReady(ProviderContainer container) async {
  container.read(appointmentsControllerProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return container.read(appointmentsControllerProvider);
}

void main() {
  group('AppointmentsController — بارگذاری', () {
    test('بارگذاری موفق: امروزِ باز انتخاب می‌شود', () async {
      final repo = FakeAppointmentsRepository(page: _openPage());
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        appointmentsRepository: repo,
      );
      addTearDown(container.dispose);

      final ui = await _readReady(container);

      expect(ui.status, LoadStatus.ready);
      expect(ui.todayDay, 7);
      expect(ui.selectedDay, 7);
      expect(ui.rows, hasLength(1));
      expect(ui.isError, isFalse);
      expect(repo.fetchCalls, 1);
    });

    test('۴۰۱ → وضعیت خطا با پیام صادقانه‌ی D-6', () async {
      final repo = FakeAppointmentsRepository(
        failWith: const ApiException('ورود لازم است', statusCode: 401),
      );
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        appointmentsRepository: repo,
      );
      addTearDown(container.dispose);

      final ui = await _readReady(container);

      expect(ui.status, LoadStatus.error);
      expect(ui.isError, isTrue);
      expect(
        ui.message,
        'اتصال زنده به سرور پس از حکم مدیر بر D-6 فعال می‌شود — '
        'کد موبایل آماده است',
      );
    });

    test('روزِ بسته‌ی امروز → نخستین روزِ باز انتخاب می‌شود', () async {
      // روز ۷ و ۸ کاملاً پر؛ روز ۹ باز
      final repo = FakeAppointmentsRepository(
        page: _openPage(taken: {
          '7:۰۹:۰۰', '7:۱۰:۳۰', '7:۱۲:۰۰', '7:۱۶:۰۰', '7:۱۷:۳۰',
          '8:۰۹:۰۰', '8:۱۰:۳۰', '8:۱۲:۰۰', '8:۱۶:۰۰', '8:۱۷:۳۰',
        }),
      );
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        appointmentsRepository: repo,
      );
      addTearDown(container.dispose);

      final ui = await _readReady(container);

      expect(ui.selectedDay, 9);
    });
  });

  group('AppointmentsController — وضعیت بازه‌ها', () {
    test('آزاد / پر / گذشته — دقیقاً با قواعد سرور', () {
      // «الانِ» سرور در میانه‌ی روز ۲ ماه قرارداد
      final ui = AppointmentsUi(
        status: LoadStatus.ready,
        taken: {'7:۰۹:۰۰'},
        serverNowSeconds:
            AppointmentContract.monthStartEpochSeconds + 2 * 86400 + 630 * 60,
        todayDay: 2,
      );

      // روز ۷ (آینده): یک بازه پر، بقیه آزاد
      expect(ui.slotStateFor(7, '۰۹:۰۰'), SlotState.taken);
      expect(ui.slotStateFor(7, '۱۰:۳۰'), SlotState.free);
      // روز ۱ کاملاً گذشته است
      expect(ui.slotStateFor(1, '۰۹:۰۰'), SlotState.past);
      expect(ui.slotStateFor(1, '۱۷:۳۰'), SlotState.past);
      // روز ۱ بسته، روز ۷ باز
      expect(ui.isDayClosed(1), isTrue);
      expect(ui.isDayClosed(7), isFalse);
      // برچسب ناشناخته = غیرقابل رزرو
      expect(ui.slotStateFor(7, '۰۸:۰۰'), SlotState.taken);
    });
  });

  group('AppointmentsController — رزرو و لغو', () {
    test('رزرو موفق: پیام سبز + بازیابی مجدد داده', () async {
      final repo = FakeAppointmentsRepository(page: _openPage());
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        appointmentsRepository: repo,
      );
      addTearDown(container.dispose);

      await _readReady(container);
      final controller = container.read(appointmentsControllerProvider.notifier);
      controller.selectSlot('۱۶:۰۰');
      await controller.book();

      final ui = container.read(appointmentsControllerProvider);
      expect(repo.bookCalls, 1);
      expect(repo.bookArgs.single.day, ui.selectedDay);
      expect(repo.bookArgs.single.slot, '۱۶:۰۰');
      expect(repo.bookArgs.single.kind, 'حضوری');
      expect(ui.message, 'نوبت ثبت شد — در انتظار تایید موسسه');
      expect(ui.isError, isFalse);
      expect(repo.fetchCalls, greaterThanOrEqualTo(2),
          reason: 'پس از رزرو داده دوباره خوانده می‌شود');
    });

    test('رزرو با ۴۰۹: پیام سرور نمایش داده می‌شود و خطا برچسب می‌خورد',
        () async {
      final repo = FakeAppointmentsRepository(page: _openPage());
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        appointmentsRepository: repo,
      );
      addTearDown(container.dispose);

      await _readReady(container);
      // شکست فقط برای خودِ رزرو — نه بارگذاری اولیه
      repo.failWith = const ApiException(
        'این بازه قبلاً رزرو شده است؛ بازه‌ی دیگری انتخاب کنید.',
        statusCode: 409,
      );
      final controller = container.read(appointmentsControllerProvider.notifier);
      controller.selectSlot('۰۹:۰۰');
      await controller.book();

      final ui = container.read(appointmentsControllerProvider);
      expect(ui.isError, isTrue);
      expect(ui.message,
          'این بازه قبلاً رزرو شده است؛ بازه‌ی دیگری انتخاب کنید.');
    });

    test('لغو موفق: PATCH با وضعیت canceled + پیام لغو', () async {
      final repo = FakeAppointmentsRepository(page: _openPage());
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        appointmentsRepository: repo,
      );
      addTearDown(container.dispose);

      await _readReady(container);
      final controller = container.read(appointmentsControllerProvider.notifier);
      await controller.cancel(11);

      final ui = container.read(appointmentsControllerProvider);
      expect(repo.statusCalls, 1);
      expect(repo.statusArgs.single, (id: 11, status: 'canceled'));
      expect(ui.message, 'نوبت لغو شد');
      expect(ui.isError, isFalse);
    });

    test('انتخاب روز/بازه/نوع پیام قبلی را پاک می‌کند', () async {
      final repo = FakeAppointmentsRepository(page: _openPage());
      final container = dadgarContainer(
        authStatus: const Authenticated('کاربر'),
        appointmentsRepository: repo,
      );
      addTearDown(container.dispose);

      await _readReady(container);
      repo.failWith = const ApiException('x', statusCode: 409);
      final controller = container.read(appointmentsControllerProvider.notifier);
      controller.selectSlot('۰۹:۰۰');
      await controller.book();
      expect(container.read(appointmentsControllerProvider).isError, isTrue);

      controller.selectDay(15);
      final ui = container.read(appointmentsControllerProvider);
      expect(ui.message, isNull);
      expect(ui.isError, isFalse);
      expect(ui.selectedDay, 15);
    });
  });
}
