import 'package:flutter/material.dart';

class AppTheme {
  static const green = Color(0xFF16794B);
  static const greenDark = Color(0xFF105C39);
  static const ink = Color(0xFF18231D);
  static const muted = Color(0xFF78847D);
  static const canvas = Color(0xFFF5F7F4);
  static const line = Color(0xFFE7ECE8);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: canvas,
    colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.light)
        .copyWith(primary: green, secondary: const Color(0xFFB7D9C5), surface: Colors.white),
    appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: ink,
      elevation: 0, centerTitle: false, titleTextStyle: TextStyle(fontSize: 21,
      fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.5)),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: line))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      hintStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: green, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: green, foregroundColor: Colors.white, minimumSize: const Size(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink, letterSpacing: -1),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
      bodyMedium: TextStyle(fontSize: 14, color: ink),
      bodySmall: TextStyle(fontSize: 12, color: muted),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true, brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF55B982), brightness: Brightness.dark),
    scaffoldBackgroundColor: const Color(0xFF101713),
  );
}
