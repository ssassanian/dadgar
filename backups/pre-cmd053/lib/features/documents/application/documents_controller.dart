/// کنترلر اسناد — M5 (DOC-04 §۱۱ ردیف M5)
///
/// فهرست گاوصندوق اسناد مشتری + حذف + آپلود + دانلود. سقف ۴ مگابایت
/// پیش از ارسال با پیام فارسی چک می‌شود (آینه‌ی DOC_MAX سرور).
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_client.dart';
import '../data/documents_contract.dart';
import '../data/documents_io.dart';
import '../data/documents_repository.dart';
import '../domain/document_models.dart';

/// وضعیت بارگذاری — الگوی ماژول‌ها (هر فیچر نسخه‌ی خودش — S-5)
enum LoadStatus { loading, ready, error }

/// وضعیت UI فهرست اسناد
final class DocumentsUi {
  const DocumentsUi({
    this.status = LoadStatus.loading,
    this.rows = const [],
    this.busy = false,
    this.message,
    this.isError = false,
  });

  final LoadStatus status;
  final List<DocSummary> rows;

  /// مشغولیت حذف/آپلود/دانلود — دکمه‌ها را قفل می‌کند
  final bool busy;
  final String? message;
  final bool isError;

  DocumentsUi copyWith({
    LoadStatus? status,
    List<DocSummary>? rows,
    bool? busy,
    String? message,
    bool? isError,
    bool clearMessage = false,
  }) {
    return DocumentsUi(
      status: status ?? this.status,
      rows: rows ?? this.rows,
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

/// کنترلر اسناد
final class DocumentsController extends Notifier<DocumentsUi> {
  DocumentsRepository get _repo => ref.read(documentsRepositoryProvider);

  @override
  DocumentsUi build() {
    Future.microtask(_load);
    return const DocumentsUi();
  }

  String _honestMessage(ApiException e) {
    if (e.statusCode == 401) {
      return 'اتصال زنده به سرور پس از حکم مدیر بر D-6 فعال می‌شود — '
          'کد موبایل آماده است';
    }
    return e.message;
  }

  Future<void> _load() async {
    state = state.copyWith(status: LoadStatus.loading, clearMessage: true);
    try {
      final rows = await _repo.fetchDocuments();
      state = state.copyWith(
        status: LoadStatus.ready,
        rows: rows,
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

  Future<void> reload() => _load();

  /// آپلود سند انتخاب‌شده — سقف ۴MB پیش از ارسال؛ موفقیت: بازخوانی فهرست
  Future<bool> upload(PickedDoc doc, {required int caseId}) async {
    if (doc.bytes.isEmpty) {
      state = state.copyWith(
        message: DocumentsContract.emptyFile,
        isError: true,
      );
      return false;
    }
    if (doc.bytes.length > DocumentsContract.docMaxBytes) {
      state = state.copyWith(
        message: 'حجم سند بیش از ۴ مگابایت است',
        isError: true,
      );
      return false;
    }
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      await _repo.upload(
        caseId: caseId,
        name: doc.name,
        mime: doc.mime,
        bytes: Uint8List.fromList(doc.bytes),
      );
      final rows = await _repo.fetchDocuments();
      state = state.copyWith(
        busy: false,
        rows: rows,
        message: 'سند بارگذاری شد',
        isError: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        message: _honestMessage(e),
        isError: true,
      );
      return false;
    }
  }

  /// دانلود بایت‌به‌بایت — ذخیره با saver تزریق‌شده (تست‌پذیری §۹)
  Future<String?> download(DocSummary doc) async {
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final bytes = await _repo.download(id: doc.id);
      final path = await ref.read(docSaverProvider)(doc.name, bytes);
      state = state.copyWith(
        busy: false,
        message: 'سند ذخیره شد',
        isError: false,
      );
      return path;
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        message: _honestMessage(e),
        isError: true,
      );
      return null;
    }
  }

  /// حذف سند — فقط اسناد خود کاربر (mine از سرور)؛ موفقیت: بازخوانی
  Future<bool> remove(DocSummary doc) async {
    if (!doc.mine) {
      state = state.copyWith(
        message: 'فقط سندی که خودتان بارگذاری کرده‌اید قابل حذف است',
        isError: true,
      );
      return false;
    }
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      await _repo.delete(id: doc.id);
      final rows = await _repo.fetchDocuments();
      state = state.copyWith(
        busy: false,
        rows: rows,
        message: 'سند حذف شد',
        isError: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        message: _honestMessage(e),
        isError: true,
      );
      return false;
    }
  }
}

/// تزریق ذخیره‌ساز — تولیدی: path_provider (پوشه‌ی اسناد اپ)؛ تست: فیک
///
/// پل پلتفرمی در documents_io.dart جداست و در تست‌ها override می‌شود
/// تا هیچ مسیر پلتفرمی در چرخه‌ی آزمون اجرا نشود (DOC-04 §۹).
final docSaverProvider = Provider<Future<String> Function(String, List<int>)>(
  (ref) => (name, bytes) async {
    final dir = await appDocumentsPath();
    final safe = 'dadgar-doc-${DateTime.now().millisecondsSinceEpoch}-$name';
    return saveDocumentFile(dir, safe, bytes);
  },
);

/// provider فهرست اسناد — M5
final documentsControllerProvider =
    NotifierProvider<DocumentsController, DocumentsUi>(
  DocumentsController.new,
);
