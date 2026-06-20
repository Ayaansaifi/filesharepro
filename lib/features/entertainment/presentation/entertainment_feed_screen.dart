import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/feed_provider.dart';
import 'entertainment_save.dart';
import 'entertainment_ads.dart';
import 'reel_video_player.dart';

class EntertainmentFeedScreen extends ConsumerStatefulWidget {
  const EntertainmentFeedScreen({super.key});

  @override
  ConsumerState<EntertainmentFeedScreen> createState() =>
      _EntertainmentFeedScreenState();
}

class _EntertainmentFeedScreenState
    extends ConsumerState<EntertainmentFeedScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late TabController _tabController;

  // AdMob — Android/iOS only (web uses stub controller)
  late final MemeBannerController _banner = createMemeBannerController();
  bool _isBannerAdLoaded = false;

  // Track which ad page index was shown to avoid reusing AdWidget
  int? _adShownAtIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _banner.load(
      onLoaded: () {
        if (mounted) setState(() => _isBannerAdLoaded = true);
      },
      onFailed: (err) => debugPrint('Banner ad failed to load: $err'),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    _banner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(memeFeedProvider);
    final blockedAuthors = ref.watch(blockedMemeAuthorsProvider);
    final likedMemes = ref.watch(likedMemesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: feedAsync.when(
        data: (memes) {
          final allFiltered =
              memes.where((m) => !blockedAuthors.contains(m.author)).toList();

          // Split memes vs reels
          final memeItems = allFiltered
              .where((m) => !m.isVideo)
              .toList();
          final reelItems = allFiltered
              .where((m) => m.isVideo)
              .toList();

          if (allFiltered.isEmpty) {
            return _buildEmpty();
          }

          return Column(
            children: [
              // ─── Header & Tab Bar ────────────────────────
              _buildHeader(),

              // ─── Content ─────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildMemeFeed(memeItems, likedMemes),
                    _buildReelFeed(reelItems, likedMemes),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
            child:
                CircularProgressIndicator(color: AppColors.primaryCyan)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load feed',
                  style:
                      AppTypography.heading3.copyWith(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(memeFeedProvider.notifier).refresh(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryCyan),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sentiment_dissatisfied_rounded,
              color: AppColors.textHint, size: 48),
          const SizedBox(height: 16),
          Text('No content available',
              style: AppTypography.heading3.copyWith(color: Colors.white)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(memeFeedProvider.notifier).refresh(),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryCyan),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 4,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Entertainment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 22),
                  onPressed: () =>
                      ref.read(memeFeedProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryCyan,
            indicatorWeight: 2,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Memes'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_filled_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Reels'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Meme Feed ───────────────────────────────────────────

  Widget _buildMemeFeed(List<MemeModel> memes, Set<String> likedMemes) {
    if (memes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported_rounded,
                color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text('No memes right now',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(memeFeedProvider.notifier).refresh(),
              child: const Text('Refresh',
                  style: TextStyle(color: AppColors.primaryCyan)),
            ),
          ],
        ),
      );
    }
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: memes.length,
      onPageChanged: (index) {
        HapticFeedback.selectionClick();
        if (index >= memes.length - 5) {
          ref.read(memeFeedProvider.notifier).loadMore();
        }
        if (index == 5 && _adShownAtIndex == null && _isBannerAdLoaded) {
          setState(() => _adShownAtIndex = 5);
        }
      },
      itemBuilder: (context, index) {
        final meme = memes[index];
        return _buildMemePage(meme, index, likedMemes);
      },
    );
  }

  // ─── Reel Feed ───────────────────────────────────────────

  Widget _buildReelFeed(List<MemeModel> reels, Set<String> likedMemes) {
    if (reels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded,
                color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text('No reels available right now',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            const Text(
              'Funny & trending reels load automatically',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ref.read(memeFeedProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.primaryCyan, size: 18),
              label: const Text('Load Reels',
                  style: TextStyle(color: AppColors.primaryCyan)),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: reels.length,
      onPageChanged: (index) {
        HapticFeedback.selectionClick();
        if (index >= reels.length - 3) {
          ref.read(memeFeedProvider.notifier).loadMore();
        }
      },
      itemBuilder: (context, index) {
        final reel = reels[index];
        return _buildReelPage(reel, index, likedMemes);
      },
    );
  }

  Widget _buildReelPage(MemeModel reel, int index, Set<String> likedMemes) {
    final isLiked = likedMemes.contains(reel.postLink);

    return Stack(
      children: [
        // Full-screen video
        Positioned.fill(
          child: reel.videoUrl != null
              ? ReelVideoPlayer(url: reel.videoUrl!)
              : _buildImageFallback(reel),
        ),

        // Bottom gradient
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 280,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),

        // Info panel bottom left
        Positioned(
          bottom: 100,
          left: 16,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Author row
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE040FB), Color(0xFFFF6B6B)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        reel.author.isNotEmpty
                            ? reel.author[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '@${reel.author}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                reel.title,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'r/${reel.subreddit}',
                  style: const TextStyle(
                      color: AppColors.primaryCyan, fontSize: 11),
                ),
              ),
            ],
          ),
        ),

        // Action buttons right side
        Positioned(
          bottom: 90,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReelAction(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${reel.ups}',
                color: isLiked ? Colors.red : Colors.white,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(likedMemesProvider.notifier)
                      .toggle(reel.postLink);
                },
              ),
              const SizedBox(height: 20),
              _buildReelAction(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {
                  Share.share('${reel.title}\n\nVia FileShare Pro: ${reel.postLink}');
                },
              ),
              const SizedBox(height: 20),
              _buildReelAction(
                icon: Icons.download_rounded,
                label: 'Save',
                onTap: () => _saveToGallery(reel),
              ),
              const SizedBox(height: 20),
              _buildReelAction(
                icon: Icons.more_vert_rounded,
                label: 'More',
                onTap: () => _showReportDialog(context, reel),
              ),
            ],
          ),
        ),

        // Progress dots at top right
        Positioned(
          top: 8,
          right: 14,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3.clamp(0, 5),
              (i) => Container(
                width: 3,
                height: i == index % 3 ? 16 : 8,
                margin: const EdgeInsets.symmetric(vertical: 1.5),
                decoration: BoxDecoration(
                  color: i == index % 3
                      ? Colors.white
                      : Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReelAction({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFallback(MemeModel meme) {
    return CachedNetworkImage(
      imageUrl: meme.url,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryCyan)),
      errorWidget: (context, url, error) =>
          const Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 48)),
    );
  }

  // ─── Meme Page ───────────────────────────────────────────

  Widget _buildMemePage(MemeModel meme, int index, Set<String> likedMemes) {
    final isLiked = likedMemes.contains(meme.postLink);
    final showAd =
        index == _adShownAtIndex && _isBannerAdLoaded && _banner.isLoaded;

    return Stack(
      children: [
        // Image
        Positioned.fill(
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: meme.url,
              fit: BoxFit.contain,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) =>
                  const Center(child: Icon(Icons.error, color: Colors.white)),
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
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Info
        Positioned(
          bottom: 40,
          left: 16,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primaryCyan.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'r/${meme.subreddit}',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.primaryCyan, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                meme.title,
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.arrow_upward_rounded,
                      color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${meme.ups}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.person_outline_rounded,
                      color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '@${meme.author}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ],
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
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: isLiked ? 'Liked' : '${meme.ups}',
                color: isLiked ? Colors.red : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(likedMemesProvider.notifier)
                      .toggle(meme.postLink);
                },
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {
                  Share.share(
                      '${meme.title}\n\nVia FileShare Pro: ${meme.url}');
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

        // Ad banner
        if (showAd)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: _banner.buildBanner(),
            ),
          ),
      ],
    );
  }

  Future<void> _saveToGallery(MemeModel meme) async {
    if (kIsWeb) {
      _showSnackBar('Save is not supported on web', isError: true);
      return;
    }

    _showSnackBar('Downloading to gallery...');

    try {
      await saveMemeToGallery(meme);
      if (mounted) {
        HapticFeedback.mediumImpact();
        _showSnackBar('✅ Saved to gallery!');
      }
    } catch (e) {
      debugPrint('Save to gallery error: $e');
      if (mounted) {
        _showSnackBar('❌ Failed to save', isError: true);
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Options', style: AppTypography.heading3),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.report_rounded, color: AppColors.error),
              title: const Text('Report Content',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Flag inappropriate or offensive content',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _submitReport(meme);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.block_rounded, color: AppColors.error),
              title: const Text('Block User',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Hide all future content from this user',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12)),
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
      ref.read(blockedMemeAuthorsProvider.notifier).blockAuthor(meme.author);
    }

    _showSnackBar(
      isBlock
          ? 'User "${meme.author}" blocked.'
          : 'Content reported. Thank you!',
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.error : AppColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: color ?? Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
