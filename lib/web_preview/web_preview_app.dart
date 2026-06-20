import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'web_navigation.dart';

class WebPreviewApp extends StatelessWidget {
  const WebPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FileShare Pro — Web Preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const WebNavigation(),
    );
  }
}
