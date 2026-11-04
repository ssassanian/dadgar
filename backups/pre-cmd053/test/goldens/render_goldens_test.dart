/// CMD-052 — رندر شات‌های واقعی نسل «دادگر S» از درخت ویجت زنده
///
/// این فایل «ابزار رندر» است، نه گیت رفتاری: فقط با متغیر محیطی
/// RENDER_GOLDENS=1 شات‌ها را با matchesGoldenFile (--update-goldens)
/// می‌نویسد و در اجرای عادی/CI با صفر تست رد می‌شود. فونت باندل‌شده‌ی
/// Vazirmatn از FontManifest بار می‌شود تا متن فارسی واقعی رندر شود.
///
/// دوازده شات از مقاصد اصلی: ورود، خانه، پرونده‌ها، جزئیات پرونده،
/// نوبت‌ها، صورت‌حساب، گفتگوها، چت، اسناد، پروفایل، فرم ثبت پرونده،
/// خانه‌ی تاریک (قاعده‌ی دارک‌مود مهارت ui-ux-pro-max).
library;

import 'dart:convert';
import 'dart:io';

import 'package:dadgar_mobile/app/app.dart';
import 'package:dadgar_mobile/design/tokens.dart';
import 'package:dadgar_mobile/features/appointments/data/appointments_contract.dart';
import 'package:dadgar_mobile/features/appointments/domain/appointment.dart';
import 'package:dadgar_mobile/features/auth/application/auth_controller.dart';
import 'package:dadgar_mobile/features/billing/domain/invoice_models.dart';
import 'package:dadgar_mobile/features/cases/domain/case_models.dart';
import 'package:dadgar_mobile/features/cases/presentation/case_detail_screen.dart';
import 'package:dadgar_mobile/features/cases/presentation/new_case_screen.dart';
import 'package:dadgar_mobile/features/documents/domain/document_models.dart';
import 'package:dadgar_mobile/features/documents/presentation/documents_screen.dart';
import 'package:dadgar_mobile/features/messages/domain/chat_models.dart';
import 'package:dadgar_mobile/features/messages/presentation/chat_screen.dart';
import 'package:dadgar_mobile/features/messages/presentation/threads_screen.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

/// بارگذاری همه‌ی فونت‌های FontManifest (Vazirmatn سه‌وزن + آیکون‌ها)
Future<void> _loadAppFonts() async {
  final List<dynamic> manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final family in manifest) {
    final loader = FontLoader(
      (family as Map<dynamic, dynamic>)['family']! as String,
    );
    for (final font in (family['fonts'] as List<dynamic>)) {
      loader.addFont(
        rootBundle.load((font as Map<dynamic, dynamic>)['asset']! as String),
      );
    }
    await loader.load();
  }
}

/// داده‌ی نمونه‌ی واقع‌نما — عین داده‌های تأییدشده‌ی تست‌های پروژه
const List<CaseSummary> _cases = [
  CaseSummary(
    id: 7,
    title: 'اختلاف بر سر مبیع',
    category: 'ملکی',
    status: 'running',
    createdAt: 1792701000,
    updatedAt: 1792787400,
  ),
  CaseSummary(
    id: 3,
    title: 'مطالبه‌ی وجه چک',
    category: 'شرکت‌ها',
    status: 'done',
    createdAt: 1792701000,
    updatedAt: 1792701000,
  ),
];

const CaseDetail _detail = CaseDetail(
  id: 7,
  title: 'اختلاف بر سر مبیع',
  category: 'ملکی',
  status: 'assigned',
  createdAt: 1792701000,
  updatedAt: 1792787400,
  finalPrice: 25000000,
  lawyerName: 'دکتر رحیمی',
  description: 'شرح کامل ماجرا و مستندات موکل',
);

const List<Invoice> _invoices = [
  Invoice(
    id: 12,
    amount: 25000000,
    status: 'paid',
    createdAt: 1792701000,
    paidAt: 1792787400,
    caseId: 7,
  ),
  Invoice(
    id: 13,
    amount: 1500000,
    status: 'pending',
    createdAt: 1792701000,
    paidAt: null,
    caseId: 3,
  ),
];

const List<DocSummary> _docs = [
  DocSummary(
    id: 31,
    caseId: 7,
    caseTitle: 'اختلاف بر سر مبیع',
    name: 'قرارداد خریدار و فروشنده.pdf',
    mime: 'application/pdf',
    size: 1048576,
    mine: true,
    shared: true,
    createdAt: 1792701000,
  ),
  DocSummary(
    id: 32,
    caseId: 3,
    caseTitle: 'مطالبه‌ی وجه چک',
    name: 'اظهارنامه چک برگشتی.jpg',
    mime: 'image/jpeg',
    size: 524288,
    mine: false,
    shared: true,
    createdAt: 1792702000,
  ),
];

AppointmentsPage _appointmentsPage() {
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
    taken: const {'2-۰۹:۰۰', '5-۱۱:۰۰'},
    serverNowSeconds: AppointmentContract.monthStartEpochSeconds - 86400,
    todayDay: 7,
  );
}

const List<Thread> _threads = [
  Thread(
    caseId: 7,
    title: 'اختلاف بر سر مبیع',
    category: 'قرارداد',
    status: 'assigned',
    lastAt: 1792701000,
    lastExcerpt: 'سلام، لایحه آماده شد',
    lastMine: false,
  ),
];

ChatEnvelope _envelope() {
  return const ChatEnvelope(
    caseId: 7,
    caseTitle: 'اختلاف بر سر مبیع',
    caseStatus: 'assigned',
    rows: [
      ChatMessage(
        id: 1,
        mine: false,
        role: 'lawyer',
        body: 'لایحه را بررسی کردم؛ مستندات سند را هم بررسی کنید.',
        createdAt: 1792701000,
      ),
      ChatMessage(
        id: 2,
        mine: true,
        role: 'client',
        body: 'ممنون از پیگیری؛ امروز ارسال می‌کنم.',
        createdAt: 1792701060,
      ),
      ChatMessage(
        id: 3,
        mine: false,
        role: 'lawyer',
        body: 'منتظر هستم. جلسه‌ی بعدی چهارشنبه ساعت ۱۰ است.',
        createdAt: 1792701120,
      ),
    ],
  );
}

/// ظرف کامل با همه‌ی شاخه‌های پر از داده
ProviderContainer _richContainer({
  AuthStatus auth = const Authenticated('امیر'),
}) {
  return dadgarContainer(
    authStatus: auth,
    appointmentsRepository: FakeAppointmentsRepository(page: _appointmentsPage()),
    casesRepository: FakeCasesRepository(
      pages: {
        1: CasesPage(rows: _cases, page: 1, pages: 1, total: _cases.length),
      },
      details: const {7: _detail},
    ),
    billingRepository: FakeBillingRepository(
      response: const InvoicesResponse(todayD: 8, rows: _invoices),
    ),
    messagesRepository: FakeMessagesRepository(
      threads: _threads,
      envelopes: {7: _envelope()},
    ),
    documentsRepository: FakeDocumentsRepository(docs: _docs),
  );
}

void main() {
  if (Platform.environment['RENDER_GOLDENS'] != '1') {
    // در تست‌های عادی و CI: صفر تست — رندر فقط ابزار داخلی CMD-052 است.
    return;
  }

  setUpAll(_loadAppFonts);

  /// سطح گوشی واقعی: ۳۹۰×۸۴۴ منطقی با DPR=۲ → PNG با ۷۸۰×۱۶۸۸
  void phoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  /// پمپ اپ کامل (روتر واقعی + داک) — یک ثانیه فریم پشت‌سرهم
  /// (DsRing بی‌پایان است؛ pumpAndSettle ممکن است تایم‌اوت شود)
  Future<void> pumpApp(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DadgarApp()),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// پمپ یک صفحه‌ی مستقیم زیر تم و جهت اپ (بدون داک — مسیرهای پوش‌شده)
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    final container = _richContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: Ds.lightTheme(),
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: screen,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
  }

  testWidgets('شات ۰۱ — ورود (اولین مسیر بدون نشست)', (tester) async {
    phoneSurface(tester);
    final container = _richContainer(auth: const AuthUnauthenticated());
    addTearDown(container.dispose);
    await pumpApp(tester, container);
    await expectLater(
      find.byType(DadgarApp),
      matchesGoldenFile('goldens_out/01-login.png'),
    );
  });

  testWidgets('شات ۰۲ — خانه (داک پنج‌مقصدی + مسیر پرونده)', (tester) async {
    phoneSurface(tester);
    final container = _richContainer();
    addTearDown(container.dispose);
    await pumpApp(tester, container);
    await expectLater(
      find.byType(DadgarApp),
      matchesGoldenFile('goldens_out/02-home.png'),
    );
  });

  testWidgets('شات ۰۳ — فهرست پرونده‌ها', (tester) async {
    phoneSurface(tester);
    final container = _richContainer();
    addTearDown(container.dispose);
    await pumpApp(tester, container);
    await tester.tap(find.byKey(const ValueKey<String>('dock-/cases')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(
      find.byType(DadgarApp),
      matchesGoldenFile('goldens_out/03-cases.png'),
    );
  });

  testWidgets('شات ۰۴ — جزئیات پرونده (مسیر شش‌مرحله‌ای)', (tester) async {
    phoneSurface(tester);
    await pumpScreen(tester, const CaseDetailScreen(caseId: 7));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens_out/04-case-detail.png'),
    );
  });

  testWidgets('شات ۰۵ — نوبت‌ها (تقویم شمسی نیتیو)', (tester) async {
    phoneSurface(tester);
    final container = _richContainer();
    addTearDown(container.dispose);
    await pumpApp(tester, container);
    await tester.tap(find.byKey(const ValueKey<String>('dock-/appointments')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(
      find.byType(DadgarApp),
      matchesGoldenFile('goldens_out/05-appointments.png'),
    );
  });

  testWidgets('شات ۰۶ — صورت‌حساب و پرداخت', (tester) async {
    phoneSurface(tester);
    final container = _richContainer();
    addTearDown(container.dispose);
    await pumpApp(tester, container);
    await tester.tap(find.byKey(const ValueKey<String>('dock-/invoices')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(
      find.byType(DadgarApp),
      matchesGoldenFile('goldens_out/06-invoices.png'),
    );
  });

  testWidgets('شات ۰۷ — فهرست گفتگوهای پرونده', (tester) async {
    phoneSurface(tester);
    await pumpScreen(tester, const ThreadsScreen());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens_out/07-threads.png'),
    );
  });

  testWidgets('شات ۰۸ — گفتگو با وکیل (حباب‌های RTL)', (tester) async {
    phoneSurface(tester);
    await pumpScreen(tester, const ChatScreen(caseId: 7));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens_out/08-chat.png'),
    );
  });

  testWidgets('شات ۰۹ — اسناد', (tester) async {
    phoneSurface(tester);
    await pumpScreen(tester, const DocumentsScreen());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens_out/09-documents.png'),
    );
  });

  testWidgets('شات ۱۰ — پروفایل', (tester) async {
    phoneSurface(tester);
    final container = _richContainer();
    addTearDown(container.dispose);
    await pumpApp(tester, container);
    await tester.tap(find.byKey(const ValueKey<String>('dock-/profile')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await expectLater(
      find.byType(DadgarApp),
      matchesGoldenFile('goldens_out/10-profile.png'),
    );
  });

  testWidgets('شات ۱۱ — ثبت پرونده‌ی جدید (فرم)', (tester) async {
    phoneSurface(tester);
    await pumpScreen(tester, const NewCaseScreen());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens_out/11-new-case.png'),
    );
  });

  testWidgets('شات ۱۲ — خانه‌ی تاریک (قاعده‌ی دارک‌مود مهارت)', (tester) async {
    phoneSurface(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final container = _richContainer();
    addTearDown(container.dispose);
    await pumpApp(tester, container);
    await expectLater(
      find.byType(DadgarApp),
      matchesGoldenFile('goldens_out/12-home-dark.png'),
    );
  });
}
