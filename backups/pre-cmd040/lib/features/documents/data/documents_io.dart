/// پل پلتفرمی اسناد — فقط این فایل به چرخه‌ی حیات دستگاه وصل است (M5)
///
/// در تست‌ها هرگز صدا زده نمی‌شود: provider ذخیره‌ساز (`docSaverProvider`)
/// override می‌شود و DOC-04 §۹ (کد تولیدی هرگز مستقیماً پلتفرم را در
/// منطق لمس نمی‌کند) رعایت می‌ماند.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// مسیر پوشه‌ی اسناد اپ — Application Documents Directory
Future<String> appDocumentsPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}

/// ذخیره‌ی بایت‌ها با نام یکتا — مسیر کامل بازگردانده می‌شود
Future<String> saveDocumentFile(
  String dirPath,
  String fileName,
  List<int> bytes,
) async {
  final file = File('$dirPath/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
