import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../shared/account_list_screen.dart';
class BusinessScreen extends StatelessWidget { const BusinessScreen({super.key}); @override Widget build(BuildContext context){final s=context.watch<LanguageProvider>().strings;return AccountListScreen(type:'business',title:s.t('businessBook'),subtitle:s.t('businessSubtitle'),category:'supplier');}}
