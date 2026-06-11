import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../domain/video_download_service.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  late final VideoDownloadService _downloadService;

  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String? _errorMessage;
  String _detectedPlatform = '';

  @override
  void initState() {
    super.initState();
    _downloadService = VideoDownloadService();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _downloadService.onProgress = (progress) {
      if (mounted) setState(() => _progress = progress);
    };
    _downloadService.onStatusChange = (status) {
      if (mounted) setState(() => _statusMessage = status);
    };
    _downloadService.onError = (error) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = error;
          _statusMessage = '';
        });
        _showSnackBar(error, isError: true);
      }
    };
    _downloadService.onComplete = (path) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = 0.0;
          _urlController.clear();
          _detectedPlatform = '';
          _statusMessage = '';
          _errorMessage = null;
        });
        _showSnackBar('✅ Video saved to gallery!', isError: false);
        HapticFeedback.heavyImpact();
      }
    };
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final text = data!.text!.trim();
      // Only paste if it looks like a URL
      if (VideoDownloadService.isValidUrl(text)) {
        setState(() {
          _urlController.text = text;
          _detectedPlatform = VideoDownloadService.detectPlatform(text);
          _errorMessage = null;
        });
        HapticFeedback.lightImpact();
      } else {
        _showSnackBar('Clipboard doesn\'t contain a valid URL', isError: true);
      }
    }
  }

  void _onUrlChanged(String value) {
    setState(() {
      if (value.trim().isNotEmpty && VideoDownloadService.isValidUrl(value.trim())) {
        _detectedPlatform = VideoDownloadService.detectPlatform(value.trim());
        _errorMessage = null;
      } else {
        _detectedPlatform = '';
      }
    });
  }

  void _startDownload() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please paste a video URL first', isError: true);
      return;
    }

    if (!VideoDownloadService.isValidUrl(url)) {
      setState(() => _errorMessage = 'Invalid URL. Must start with http:// or https://');
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = null;
      _statusMessage = 'Starting download...';
    });

    HapticFeedback.mediumImpact();
    _downloadService.startDownload(url);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'Instagram':
        return Icons.camera_alt_rounded;
      case 'TikTok':
        return Icons.music_note_rounded;
      case 'Facebook':
        return Icons.facebook_rounded;
      case 'Twitter/X':
        return Icons.tag_rounded;
      case 'Pinterest':
        return Icons.push_pin_rounded;
      default:
        return Icons.video_library_rounded;
    }
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'Instagram':
        return const Color(0xFFE4405F);
      case 'TikTok':
        return const Color(0xFF00F2EA);
      case 'Facebook':
        return const Color(0xFF1877F2);
      case 'Twitter/X':
        return const Color(0xFF1DA1F2);
      case 'Pinterest':
        return const Color(0xFFBD081C);
      default:
        return AppColors.primaryCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Video Downloader', style: AppTypography.heading3),
                        Text(
                          'Instagram • TikTok • Facebook • Twitter',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // URL Input
              GlassCard(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Paste video link here...',
                              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              prefixIcon: _detectedPlatform.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 12, right: 4),
                                      child: Icon(
                                        _getPlatformIcon(_detectedPlatform),
                                        color: _getPlatformColor(_detectedPlatform),
                                        size: 20,
                                      ),
                                    )
                                  : null,
                              prefixIconConstraints: const BoxConstraints(minWidth: 36),
                            ),
                            onChanged: _onUrlChanged,
                          ),
                        ),
                        if (_urlController.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _urlController.clear();
                              setState(() {
                                _detectedPlatform = '';
                                _errorMessage = null;
                              });
                            },
                            icon: const Icon(Icons.close_rounded, color: AppColors.textHint, size: 20),
                          ),
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: _handlePaste,
                            icon: const Icon(Icons.content_paste_rounded, color: Colors.white, size: 20),
                            tooltip: 'Paste from clipboard',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Platform detected badge
              if (_detectedPlatform.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPlatformColor(_detectedPlatform).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getPlatformColor(_detectedPlatform).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPlatformIcon(_detectedPlatform),
                        color: _getPlatformColor(_detectedPlatform),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_detectedPlatform detected',
                        style: AppTypography.caption.copyWith(
                          color: _getPlatformColor(_detectedPlatform),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.caption.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Download Button / Progress
              if (!_isDownloading)
                GradientButton(
                  label: 'Download Video',
                  icon: Icons.download_rounded,
                  gradient: AppColors.primaryGradient,
                  enabled: _urlController.text.trim().isNotEmpty,
                  onPressed: _startDownload,
                )
              else
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: _progress > 0 ? _progress : null,
                              strokeWidth: 2,
                              color: AppColors.primaryCyan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusMessage.isNotEmpty ? _statusMessage : 'Processing...',
                              style: AppTypography.labelMedium,
                            ),
                          ),
                          Text(
                            '${(_progress * 100).toStringAsFixed(0)}%',
                            style: AppTypography.heading4.copyWith(
                              color: AppColors.primaryCyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryCyan),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          _downloadService.cancelDownload();
                          setState(() {
                            _isDownloading = false;
                            _progress = 0;
                            _statusMessage = '';
                          });
                        },
                        child: Text(
                          'Cancel',
                          style: AppTypography.labelMedium.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 40),

              // Supported platforms
              Text('Supported Platforms', style: AppTypography.heading4),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildPlatformChip('Instagram', Icons.camera_alt_rounded, const Color(0xFFE4405F)),
                  _buildPlatformChip('TikTok', Icons.music_note_rounded, const Color(0xFF00F2EA)),
                  _buildPlatformChip('Facebook', Icons.facebook_rounded, const Color(0xFF1877F2)),
                  _buildPlatformChip('Twitter/X', Icons.tag_rounded, const Color(0xFF1DA1F2)),
                  _buildPlatformChip('Pinterest', Icons.push_pin_rounded, const Color(0xFFBD081C)),
                ],
              ),

              const SizedBox(height: 40),

              // Privacy info
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.security_rounded, color: AppColors.success, size: 28),
                    const SizedBox(height: 8),
                    Text('100% Private & Secure', style: AppTypography.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      'No data stored on servers. Downloads processed locally.',
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformChip(String name, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            name,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
