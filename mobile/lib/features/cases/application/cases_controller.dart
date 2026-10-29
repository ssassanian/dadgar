/// کنترلرهای پرونده‌ها — M2 (DOC-04 §۱۱ ردیف M2)
///
/// سه وضعیت UI: فهرست صفحه‌بندی‌شده، جزئیات، و ثبت پرونده جدید.
/// منطق پیش از ارسال آینه‌ی قواعد سرور است (title ۵..۱۲۰، description
/// ≤۵۰۰۰، سقف ۵ پرونده در ساعت = 429) تا پیام‌ها با سرور یکدست بماند.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../data/cases_contract.dart';
import '../data/cases_repository.dart';
import '../domain/case_models.dart';

/// وضعیت بارگذاری داده — مشترک بین کنترلرهای ماژول
enum LoadStatus { loading, ready, error }

/// وضعیت UI فهرست پرونده‌ها
final class CasesUi {
  const CasesUi({
    this.status = LoadStatus.loading,
    this.rows = const [],
    this.page = 0,
    this.pages = 1,
    this.total = 0,
    this.loadingMore = false,
    this.busy = false,
    this.message,
    this.isError = false,
  });

  final LoadStatus status;
  final List<CaseSummary> rows;

  /// آخرین صفحه‌ی دریافت‌شده (۰ = هنوز چیزی نیامده)
  final int page;
  final int pages;
  final int total;

  /// در حال دریافت صفحه‌ی بعد (پس‌زمینه‌ی اسکرول)
  final bool loadingMore;
  final bool busy;
  final String? message;
  final bool isError;

  bool get hasMore => page < pages;

  CasesUi copyWith({
    LoadStatus? status,
    List<CaseSummary>? rows,
    int? page,
    int? pages,
    int? total,
    bool? loadingMore,
    bool? busy,
    String? message,
    bool? isError,
    bool clearMessage = false,
  }) {
    return CasesUi(
      status: status ?? this.status,
      rows: rows ?? this.rows,
      page: page ?? this.page,
      pages: pages ?? this.pages,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

/// کنترلر فهرست پرونده‌ها — صفحه‌بندی همان قرارداد سرور (CASES_PER=10)
final class CasesController extends Notifier<CasesUi> {
  CasesRepository get _repo => ref.read(casesRepositoryProvider);

  @override
  CasesUi build() {
    Future.microtask(_loadFirst);
    return const CasesUi();
  }

  /// پیام صادقانه — 401 تا حکم D-6 یعنی «اتصال زنده فعال نیست»
  String _honestMessage(ApiException e) {
    if (e.statusCode == 401) {
      return 'اتصال زنده به سرور پس از حکم مدیر بر D-6 فعال می‌شود — '
          'کد موبایل آماده است';
    }
    return e.message;
  }

  Future<void> _loadFirst() async {
    state = state.copyWith(status: LoadStatus.loading, clearMessage: true);
    try {
      final page = await _repo.fetchPage(page: 1);
      state = state.copyWith(
        status: LoadStatus.ready,
        rows: page.rows,
        page: page.page,
        pages: page.pages,
        total: page.total,
        isError: false,
        clearMessage: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        status: LoadStatus.error,
        message: _honestMessage(e),
        isError: true,
      );
    }
  }

  /// تلاش دوباره از صفحه‌ی اول
  Future<void> reload() => _loadFirst();

  /// صفحه‌ی بعدی — پیوست به ردیف‌ها؛ هیچ‌گاه هم‌زمان دو درخواست
  Future<void> loadMore() async {
    final current = state;
    if (current.loadingMore ||
        current.busy ||
        !current.hasMore ||
        current.status != LoadStatus.ready) {
      return;
    }
    final next = current.page + 1;
    if (next > CasesContract.maxPage) return;
    state = current.copyWith(loadingMore: true);
    try {
      final page = await _repo.fetchPage(page: next);
      final known = current.rows.map((r) => r.id).toSet();
      final fresh =
          page.rows.where((r) => !known.contains(r.id)).toList(growable: false);
      state = state.copyWith(
        rows: [...current.rows, ...fresh],
        page: page.page,
        pages: page.pages,
        total: page.total,
        loadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        loadingMore: false,
        message: _honestMessage(e),
        isError: true,
      );
    }
  }
}

/// وضعیت UI ثبت پرونده جدید
final class CreateCaseUi {
  const CreateCaseUi({
    this.category = '',
    this.title = '',
    this.description = '',
    this.busy = false,
    this.doneId,
    this.message,
    this.isError = false,
  });

  final String category;
  final String title;
  final String description;
  final bool busy;

  /// شناسه‌ی پرونده‌ی ثبت‌شده — موفقیت
  final int? doneId;
  final String? message;
  final bool isError;

  CreateCaseUi copyWith({
    String? category,
    String? title,
    String? description,
    bool? busy,
    int? doneId,
    String? message,
    bool? isError,
    bool clearMessage = false,
  }) {
    return CreateCaseUi(
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      busy: busy ?? this.busy,
      doneId: doneId ?? this.doneId,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

/// کنترلر ثبت پرونده — اعتبارسنجی آینه‌ی سرور قبل از POST
final class CreateCaseController extends Notifier<CreateCaseUi> {
  CasesRepository get _repo => ref.read(casesRepositoryProvider);

  @override
  CreateCaseUi build() => const CreateCaseUi();

  void setCategory(String category) {
    state = state.copyWith(
      category: category,
      isError: false,
      clearMessage: true,
    );
  }

  void setTitle(String title) {
    state = state.copyWith(
      title: title,
      isError: false,
      clearMessage: true,
    );
  }

  void setDescription(String description) {
    state = state.copyWith(
      description: description,
      isError: false,
      clearMessage: true,
    );
  }

  /// ثبت — برمی‌گرداند: شناسه‌ی پرونده در موفقیت، وگرنه null
  Future<int?> submit() async {
    final category = state.category;
    final titleError = CasesContract.validateTitle(state.title);
    final descriptionError =
        CasesContract.validateDescription(state.description);
    if (!CasesContract.cats.contains(category)) {
      state = state.copyWith(
        message: 'دسته‌بندی را انتخاب کنید',
        isError: true,
      );
      return null;
    }
    if (titleError != null || descriptionError != null) {
      state = state.copyWith(
        message: titleError ?? descriptionError,
        isError: true,
      );
      return null;
    }
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final id = await _repo.create(
        category: category,
        title: state.title.trim(),
        description: state.description,
      );
      state = state.copyWith(
        busy: false,
        doneId: id,
        message: 'پرونده ثبت شد — در انتظار بررسی موسسه',
        isError: false,
      );
      return id;
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        message: _honestMessage(e),
        isError: true,
      );
      return null;
    }
  }

  String _honestMessage(ApiException e) {
    if (e.statusCode == 401) {
      return 'اتصال زنده به سرور پس از حکم مدیر بر D-6 فعال می‌شود — '
          'کد موبایل آماده است';
    }
    return e.message;
  }
}

/// کنترلر جزئیات — M2: خانواده‌ای بر شناسه‌ی پرونده با FutureProvider
///
/// در Riverpod 3 کلاس FamilyNotifier حذف شده (CHANGELOG ۳.۰)؛ الگوی رسمی
/// برای حالت فقط-خواندنی، FutureProvider.family است. خطای ۴۰۱ اینجا به
/// پیام صادقانه‌ی D-6 نگاشت می‌شود تا UI فقط یک شکل خطا ببیند.
String honestApiMessage(ApiException e) {
  if (e.statusCode == 401) {
    return 'اتصال زنده به سرور پس از حکم مدیر بر D-6 فعال می‌شود — '
        'کد موبایل آماده است';
  }
  return e.message;
}

/// جزئیات یک پرونده — ۴۰۴ ضدافشا و ۴۲۹ عین سرور حفظ می‌شود
///
/// `retry: null-برگردان` — Riverpod 3 خطاهای provider را خودکار تکرار
/// می‌کند؛ برای ۴xx (مثل ۴۰۴ ضدافشا و ۴۰۱ در انتظار D-6) تکرار معنادار
/// نیست و پیام صادقانه باید ماندگار بماند.
final caseDetailProvider =
    FutureProvider.family<CaseDetail, int>(
  (ref, id) async {
    final repo = ref.watch(casesRepositoryProvider);
    try {
      return await repo.fetchDetail(id: id);
    } on ApiException catch (e) {
      throw ApiException(honestApiMessage(e), statusCode: e.statusCode);
    }
  },
  retry: (retryCount, error) => null,
);
