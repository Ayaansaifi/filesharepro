import 'package:flutter/material.dart';
import 'entertainment_ads_types.dart';

class MemeBannerControllerImpl implements MemeBannerController {
  @override
  bool get isLoaded => false;

  @override
  void load({
    required VoidCallback onLoaded,
    required void Function(Object err) onFailed,
  }) {}

  @override
  Widget buildBanner() => const SizedBox.shrink();

  @override
  void dispose() {}
}

MemeBannerController createMemeBannerController() => MemeBannerControllerImpl();
