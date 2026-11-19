import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app/hisaab_app.dart';
import 'providers/language_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/account_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider(create: (_) => HisaabAuthProvider()),
      ChangeNotifierProvider(create: (_) => AccountProvider()),
    ],
    child: const HisaabApp(),
  ));
}
