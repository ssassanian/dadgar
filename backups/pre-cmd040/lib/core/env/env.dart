/// تنظیمات محیط — فقط مقادیر عمومی (DOC-04 §۸: صفر secret در باینری)
///
/// BASE_URL با `--dart-define=DADGAR_BASE_URL=...` قابل بازنویسی است؛
/// مقدار پیش‌فرض، آدرس عمومی production وب دادگر است.
class Env {
  const Env._();

  static const String baseUrl = String.fromEnvironment(
    'DADGAR_BASE_URL',
    defaultValue: 'https://dadgar-aboalisinacom-7507.vercel.app',
  );
}
