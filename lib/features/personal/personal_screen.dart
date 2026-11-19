import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../shared/account_list_screen.dart';
class PersonalScreen extends StatelessWidget { const PersonalScreen({super.key}); @override Widget build(BuildContext context){final s=context.watch<LanguageProvider>().strings;return AccountListScreen(type:'personal',title:s.t('personalBook'),subtitle:s.t('personalSubtitle'),category:'friend');}}
