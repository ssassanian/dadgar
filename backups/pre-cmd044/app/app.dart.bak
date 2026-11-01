import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'router.dart';

/// ریشه‌ی اپ دادگر — فارسی، RTL کامل از هسته‌ی فریمورک (DOC-04 §۷)
///
/// ناوبری اعلامی با go_router: مسیرها بر اساس وضعیت نشست
/// (splash → login/home → lock) هدایت می‌شوند (M1).
class DadgarApp extends ConsumerWidget {
  const DadgarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'دادگر',
      debugShowCheckedModeBanner: false,
      theme: DadgarTokens.lightTheme(),
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
