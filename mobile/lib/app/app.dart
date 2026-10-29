import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../design/tokens.dart';
import '../features/home/home_screen.dart';

/// ریشه‌ی اپ دادگر — فارسی، RTL کامل از هسته‌ی فریمورک (DOC-04 §۷)
class DadgarApp extends StatelessWidget {
  const DadgarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const HomeScreen(),
    );
  }
}
