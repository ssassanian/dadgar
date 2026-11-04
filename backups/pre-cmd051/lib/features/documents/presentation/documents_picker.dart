/// انتخابگر سند (دوربین/گالری) — M5 (DOC-04 §۱۱ ردیف M5: «آپلود دوربین»)
///
/// image_picker فقط همین‌جا به کار می‌رود و خروجی به مدل خالص `PickedDoc`
/// تبدیل می‌شود تا مخزن/کنترلر/تست‌ها بدون پلتفرم بمانند (DOC-04 §۹).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/document_models.dart';

/// نوع تزریق‌شدنی انتخاب — تست‌ها override می‌کنند
typedef DocPicker = Future<PickedDoc?> Function(ImageSource source);

/// انتخابگر تولیدی — image_picker با تبدیل XFile → PickedDoc
Future<PickedDoc?> pickDocument(ImageSource source) async {
  final picker = ImagePicker();
  final XFile? x = await picker.pickImage(
    source: source,
    maxWidth: 2560,
    imageQuality: 85,
  );
  if (x == null) return null;
  final mime = _mimeOf(x);
  return PickedDoc(
    name: x.name,
    mime: mime,
    bytes: await x.readAsBytes(),
  );
}

String _mimeOf(XFile x) {
  final m = x.mimeType;
  if (m != null && m.isNotEmpty) return m;
  final p = x.path.toLowerCase();
  if (p.endsWith('.png')) return 'image/png';
  if (p.endsWith('.webp')) return 'image/webp';
  if (p.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg'; // دوربین پیش‌فرض
}

/// provider انتخابگر — در تست‌ها با فیک بازنویسی می‌شود
final docPickerProvider = Provider<DocPicker>((ref) => pickDocument);
