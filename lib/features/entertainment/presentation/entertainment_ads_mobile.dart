import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../core/constants/app_constants.dart';
import 'entertainment_ads_types.dart';

class MemeBannerControllerImpl implements MemeBannerController {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  bool get isLoaded => _loaded && _ad != null;

  @override
  void load({
    required VoidCallback onLoaded,
    required void Function(Object err) onFailed,
  }) {
    if (kIsWeb) return;

    final adUnitId = kDebugMode
        ? 'ca-app-pub-3940256099942544/6300978111'
        : AppConstants.admobBannerId;

    _ad = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _loaded = true;
          onLoaded();
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
          _loaded = false;
          onFailed(err);
        },
      ),
    );
    _ad!.load();
  }

  @override
  Widget buildBanner() {
    if (_ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
  }
}

MemeBannerController createMemeBannerController() => MemeBannerControllerImpl();
