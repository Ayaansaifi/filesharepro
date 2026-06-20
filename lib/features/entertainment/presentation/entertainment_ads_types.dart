import 'package:flutter/material.dart';

abstract class MemeBannerController {
  bool get isLoaded;
  Widget buildBanner();
  void load({
    required VoidCallback onLoaded,
    required void Function(Object err) onFailed,
  });
  void dispose();
}
