import 'package:flutter/material.dart';
import '../core/localization/strings.dart';

class LanguageProvider extends ChangeNotifier {
  String _locale = 'en';
  String get locale => _locale;
  HisaabStrings get strings => HisaabStrings(_locale);
  void setLanguage(String value) { if (!['en','hi','mr'].contains(value)) return; _locale = value; notifyListeners(); }
}
