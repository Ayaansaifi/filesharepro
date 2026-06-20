import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/ai_provider.dart';

/// Shows a 2-line AI-generated preview summary below received file messages.
/// Uses Shimmer while loading, gracefully hides if AI unavailable or errors.
class AiFileInsightCard extends ConsumerWidget {
  final String fileName;
  final int fileSizeBytes;

  const AiFileInsightCard({
    super.key,
    required this.fileName,
    required this.fileSizeBytes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiEnabled = ref.watch(aiEnabledProvider);
    if (!aiEnabled) return const SizedBox.shrink();

    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    final request = FileInsightRequest(
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      mimeType: mimeType,
    );

    final insightAsync = ref.watch(fileInsightProvider(request));

    return insightAsync.when(
      loading: () => _buildShimmer(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (insight) {
        if (insight == null || insight.isEmpty) return const SizedBox.shrink();
        return _buildCard(insight);
      },
    );
  }

  Widget _buildCard(String insight) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primaryPurple,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              insight,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceLight,
      highlightColor: AppColors.glassHighlight,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 10,
              width: double.infinity,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 4),
            ),
            Container(
              height: 10,
              width: 120,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
