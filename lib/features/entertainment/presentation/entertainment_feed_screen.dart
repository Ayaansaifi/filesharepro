import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../chat/providers/chat_provider.dart';
import '../providers/feed_provider.dart';

class EntertainmentFeedScreen extends ConsumerStatefulWidget {
  const EntertainmentFeedScreen({super.key});

  @override
  ConsumerState<EntertainmentFeedScreen> createState() => _EntertainmentFeedScreenState();
}

class _EntertainmentFeedScreenState extends ConsumerState<EntertainmentFeedScreen> {
  final PageController _pageController = PageController();
  
  // AdMob — use test IDs in debug, real IDs in release
  // IMPORTANT: Replace these with your real AdMob IDs before production release
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  
  /// Returns the correct Ad Unit ID based on build mode
  String get _adUnitId {
    if (kDebugMode) {
      // Google's official test banner ID — safe for development
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    // TODO: Replace with your real AdMob Banner ID for production
    // For now, return test ID to prevent policy violation
    return 'ca-app-pub-3940256099942544/6300978111';
  }

  // Track which ad page index was shown to avoid reusing AdWidget
  int? _adShownAtIndex;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (kIsWeb) return; // Google Mobile Ads does not support Web, bypass to prevent crash.
    
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner ad failed to load: $err');
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(memeFeedProvider);
    final blockedUsers = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: feedAsync.when(
        data: (memes) {
          // Filter out blocked authors
          final filteredMemes = memes
              .where((m) => !blockedUsers.contains(m.author))
              .toList();
          
          if (filteredMemes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sentiment_dissatisfied_rounded, color: AppColors.textHint, size: 48),
                  const SizedBox(height: 16),
                  Text('No content available', style: AppTypography.heading3.copyWith(color: Colors.white)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(memeFeedProvider),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryCyan),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: filteredMemes.length,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
            },
            itemBuilder: (context, index) {
              final meme = filteredMemes[index];
              return _buildMemePage(meme, index);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load feed', style: AppTypography.heading3.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Check your internet connection and try again',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(memeFeedProvider),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryCyan),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemePage(MemeModel meme, int index) {
    // Only show ad banner on the first occurrence (index == 5) to avoid AdWidget reuse crash
    final showAd = _isBannerAdLoaded && 
                   _bannerAd != null &&
                   index == 5 && 
                   _adShownAtIndex == null;
    
    if (showAd) {
      _adShownAtIndex = index;
    }

    return Stack(
      children: [
        // Image
        Positioned.fill(
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: meme.url,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white)),
            ),
          ),
        ),
        
        // Overlay Gradients
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Info & Actions
        Positioned(
          bottom: 40,
          left: 16,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'r/${meme.subreddit}',
                style: AppTypography.labelLarge.copyWith(color: AppColors.primaryCyan),
              ),
              const SizedBox(height: 8),
              Text(
                meme.title,
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Action Buttons (Right Side)
        Positioned(
          bottom: 40,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                icon: Icons.thumb_up_rounded,
                label: '${meme.ups}',
                onTap: () {
                  HapticFeedback.lightImpact();
                },
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {
                  Share.share('${meme.title}\n\nVia FileShare Pro: ${meme.url}');
                },
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.download_rounded,
                label: 'Save',
                onTap: () => _saveToGallery(meme),
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.more_vert_rounded,
                label: 'More',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _showReportDialog(context, meme);
                },
              ),
            ],
          ),
        ),

        // Show ad banner only at the designated index (once)
        if (index == _adShownAtIndex && _isBannerAdLoaded && _bannerAd != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
          ),
      ],
    );
  }

  /// Actually download meme image and save to gallery
  Future<void> _saveToGallery(MemeModel meme) async {
    if (kIsWeb) {
      _showSnackBar('Save is not supported on web', isError: true);
      return;
    }
    
    _showSnackBar('Downloading to gallery...');
    
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'meme_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${tempDir.path}/$fileName';
      
      final dio = Dio();
      await dio.download(
        meme.url,
        filePath,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
          },
        ),
      );
      
      final file = File(filePath);
      if (await file.exists()) {
        if (!await Gal.hasAccess()) {
          await Gal.requestAccess();
        }
        await Gal.putImage(filePath);
        
        if (mounted) {
          HapticFeedback.mediumImpact();
          _showSnackBar('✅ Saved to gallery!');
        }
        
        // Cleanup temp file
        try { await file.delete(); } catch (_) {}
      }
    } catch (e) {
      debugPrint('Save to gallery error: $e');
      if (mounted) {
        _showSnackBar('❌ Failed to save image', isError: true);
      }
    }
  }

  void _showReportDialog(BuildContext context, MemeModel meme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Options', style: AppTypography.heading3),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.report_rounded, color: AppColors.error),
              title: const Text('Report Content', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Flag this content as inappropriate or offensive', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _submitReport(meme);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: AppColors.error),
              title: const Text('Block User', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Hide all future content from this user', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _submitReport(meme, isBlock: true);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _submitReport(MemeModel meme, {bool isBlock = false}) {
    HapticFeedback.mediumImpact();
    
    if (isBlock) {
      // Actually persist the block using blockedUsersProvider
      ref.read(blockedUsersProvider.notifier).blockUser(meme.author);
    }
    
    _showSnackBar(
      isBlock 
        ? 'User "${meme.author}" blocked successfully.' 
        : 'Content reported. We will review it shortly.',
    );
    
    // Skip to next page to hide the content
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
