import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web_preview/web_preview_app.dart';

/// Chrome UI preview entry — P2P/Nearby Android par kaam karta hai.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  runApp(const ProviderScope(child: WebPreviewApp()));
}
