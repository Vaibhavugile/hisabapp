import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/language_provider.dart';
import '../features/auth/auth_gate.dart';

class HisaabApp extends StatelessWidget {
  const HisaabApp({super.key});
  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    return MaterialApp(
      title: 'Hisaab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: Locale(language.locale),
      home: const AuthGate(),
    );
  }
}
