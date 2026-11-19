import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
class HisaabLogo extends StatelessWidget { final double size; const HisaabLogo({super.key,this.size=48}); @override Widget build(BuildContext context)=>Container(width:size,height:size,decoration:BoxDecoration(color:AppTheme.green,borderRadius:BorderRadius.circular(size*.28)),child:Icon(Icons.account_balance_wallet_rounded,color:Colors.white,size:size*.52)); }
