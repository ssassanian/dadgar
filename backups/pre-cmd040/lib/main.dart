import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  // نقطه‌ی ورود — ProviderScope با گراف واقعی providers.dart (M1)
  runApp(const ProviderScope(child: DadgarApp()));
}
