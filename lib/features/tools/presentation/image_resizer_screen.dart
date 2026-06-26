import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Filter presets that can be applied to the resized image.
enum ImageFilter {
  none,
  grayscale,
  sepia,
  invert,
  brighten,
  contrast,
  vintage,
}

extension ImageFilterX on ImageFilter {
  String get label => switch (this) {
        ImageFilter.none => 'Original',
        ImageFilter.grayscale => 'B&W',
        ImageFilter.sepia => 'Sepia',
        ImageFilter.invert => 'Invert',
        ImageFilter.brighten => 'Bright',
        ImageFilter.contrast => 'Punch',
        ImageFilter.vintage => 'Vintage',
      };
}

class ImageResizerScreen extends StatefulWidget {
  const ImageResizerScreen({super.key});

  @override
  State<ImageResizerScreen> createState() => _ImageResizerScreenState();
}

class _ImageResizerScreenState extends State<ImageResizerScreen> {
  File? _selectedImage;
  int _originalWidth = 0;
  int _originalHeight = 0;
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  double _quality = 85;
  bool _maintainAspect = true;
  bool _isProcessing = false;
  File? _resizedImage;
  int _resizedSize = 0;
  int _originalSize = 0;
  String _selectedFormat = 'jpg';

  // Advanced controls
  int _rotation = 0; // 0, 90, 180, 270
  bool _flipH = false;
  bool _flipV = false;
  double _brightness = 0; // -100..100
  double _contrast = 0; // -100..100
  double _saturation = 0; // -100..100
  ImageFilter _filter = ImageFilter.none;

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded != null) {
        setState(() {
          _selectedImage = file;
          _originalWidth = decoded.width;
          _originalHeight = decoded.height;
          _originalSize = bytes.length;
          _widthController.text = decoded.width.toString();
          _heightController.text = decoded.height.toString();
          _resizedImage = null;
          _resizedSize = 0;
          // Reset advanced controls
          _rotation = 0;
          _flipH = false;
          _flipV = false;
          _brightness = 0;
          _contrast = 0;
          _saturation = 0;
          _filter = ImageFilter.none;
        });
      }
    }
  }

  void _onWidthChanged(String val) {
    if (!_maintainAspect || _originalWidth == 0) return;
    final w = int.tryParse(val);
    if (w != null && w > 0) {
      final ratio = _originalHeight / _originalWidth;
      _heightController.text = (w * ratio).round().toString();
    }
  }

  void _onHeightChanged(String val) {
    if (!_maintainAspect || _originalHeight == 0) return;
    final h = int.tryParse(val);
    if (h != null && h > 0) {
      final ratio = _originalWidth / _originalHeight;
      _widthController.text = (h * ratio).round().toString();
    }
  }

  void _applyPreset(int w, int h) {
    HapticFeedback.lightImpact();
    setState(() {
      _widthController.text = w.toString();
      _heightController.text = h.toString();
      _maintainAspect = false;
    });
  }

  void _rotate() {
    HapticFeedback.lightImpact();
    setState(() {
      _rotation = (_rotation + 90) % 360;
      // Swap width/height when rotated 90/270
      if (_rotation == 90 || _rotation == 270) {
        final w = _originalHeight;
        final h = _originalWidth;
        _widthController.text = w.toString();
        _heightController.text = h.toString();
      } else {
        _widthController.text = _originalWidth.toString();
        _heightController.text = _originalHeight.toString();
      }
    });
  }

  /// Apply brightness/contrast/saturation/filter adjustments to a decoded image.
  img.Image _applyAdjustments(img.Image src) {
    var out = src;

    // Brightness (-100..100 → factor)
    if (_brightness != 0) {
      final factor = 1 + (_brightness / 100) * 0.8;
      out = img.adjustColor(out, brightness: factor);
    }
    // Contrast (-100..100 → factor)
    if (_contrast != 0) {
      final factor = 1 + (_contrast / 100);
      out = img.adjustColor(out, contrast: factor);
    }
    // Saturation
    if (_saturation != 0) {
      final factor = 1 + (_saturation / 100);
      out = img.adjustColor(out, saturation: factor);
    }

    switch (_filter) {
      case ImageFilter.grayscale:
        out = img.grayscale(out);
        break;
      case ImageFilter.invert:
        out = img.invert(out);
        break;
      case ImageFilter.sepia:
        out = img.sepia(out);
        break;
      case ImageFilter.brighten:
        out = img.adjustColor(out, brightness: 1.3);
        break;
      case ImageFilter.contrast:
        out = img.adjustColor(out, contrast: 1.4, saturation: 1.1);
        break;
      case ImageFilter.vintage:
        out = img.sepia(out);
        out = img.adjustColor(out, contrast: 1.15, brightness: 1.05);
        break;
      case ImageFilter.none:
        break;
    }

    return out;
  }

  Future<void> _resizeImage() async {
    if (_selectedImage == null) return;
    final targetW = int.tryParse(_widthController.text);
    final targetH = int.tryParse(_heightController.text);
    if (targetW == null || targetH == null || targetW <= 0 || targetH <= 0) {
      _showSnackBar('Please enter valid width and height', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Could not decode image');

      // Resize first
      decoded = img.copyResize(decoded,
          width: targetW, height: targetH,
          interpolation: img.Interpolation.linear);

      // Apply adjustments
      decoded = _applyAdjustments(decoded);

      // Rotate
      if (_rotation == 90) {
        decoded = img.copyRotate(decoded, angle: 90);
      } else if (_rotation == 180) {
        decoded = img.copyRotate(decoded, angle: 180);
      } else if (_rotation == 270) {
        decoded = img.copyRotate(decoded, angle: 270);
      }

      // Flip
      if (_flipH) decoded = img.flipHorizontal(decoded);
      if (_flipV) decoded = img.flipVertical(decoded);

      List<int> encoded;
      String ext;
      switch (_selectedFormat) {
        case 'png':
          encoded = img.encodePng(decoded);
          ext = 'png';
          break;
        case 'webp':
          // dart image lib doesn't always support webp encoding, fallback to jpg
          encoded = img.encodeJpg(decoded, quality: _quality.round());
          ext = 'jpg';
          break;
        default:
          encoded = img.encodeJpg(decoded, quality: _quality.round());
          ext = 'jpg';
      }

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/resized_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final outFile = File(filePath);
      await outFile.writeAsBytes(encoded);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _resizedImage = outFile;
          _resizedSize = encoded.length;
        });
        HapticFeedback.mediumImpact();
        _showSnackBar('✅ Image processed successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackBar('❌ Failed: $e', isError: true);
      }
    }
  }

  void _resetAdjustments() {
    HapticFeedback.lightImpact();
    setState(() {
      _brightness = 0;
      _contrast = 0;
      _saturation = 0;
      _filter = ImageFilter.none;
      _rotation = 0;
      _flipH = false;
      _flipV = false;
    });
  }

  void _shareResized() {
    if (_resizedImage == null) return;
    Share.shareXFiles([XFile(_resizedImage!.path)],
        text: 'Edited by FileShare Pro');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              Color(0xFF0F1630),
              Color(0xFF1A1F38),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedImage == null)
                        _buildPickArea()
                      else ...[
                        _buildImagePreview(),
                        const SizedBox(height: 20),
                        _buildTransformToolbar(),
                        const SizedBox(height: 20),
                        _buildSizePresets(),
                        const SizedBox(height: 20),
                        _buildDimensionInputs(),
                        const SizedBox(height: 20),
                        _buildQualitySlider(),
                        const SizedBox(height: 20),
                        _buildFormatSelector(),
                        const SizedBox(height: 20),
                        _buildAdjustmentsSection(),
                        const SizedBox(height: 20),
                        _buildFiltersRow(),
                        const SizedBox(height: 24),
                        _buildResizeButton(),
                        if (_resizedImage != null) ...[
                          const SizedBox(height: 20),
                          _buildResultCard(),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.photo_size_select_large_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image Studio',
                    style: AppTypography.heading3.copyWith(fontSize: 18)),
                Text('रिसाइज़ • फ़िल्टर • एडिट',
                    style: TextStyle(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_selectedImage != null)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded,
                  color: AppColors.primaryCyan),
              onPressed: _pickImage,
              tooltip: 'Change image',
            ),
        ],
      ),
    );
  }

  Widget _buildPickArea() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(60),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_photo_alternate_rounded,
                  color: Color(0xFF6C5CE7), size: 48),
            ),
            const SizedBox(height: 20),
            Text('Select an image to edit',
                style: AppTypography.heading3.copyWith(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Resize • Rotate • Filters • Adjust',
                style: AppTypography.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final hasEdits = _rotation != 0 ||
        _flipH ||
        _flipV ||
        _brightness != 0 ||
        _contrast != 0 ||
        _saturation != 0 ||
        _filter != ImageFilter.none;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _rotation * math.pi / 180,
                  child: Transform.flip(
                    flipX: _flipH,
                    flipY: _flipV,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(
                        _buildColorMatrix(),
                      ),
                      child: Image.file(
                        _selectedImage!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 220,
                          color: AppColors.surfaceLight,
                          child: const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.white38)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasEdits)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_fix_high_rounded,
                              color: Color(0xFF6C5CE7), size: 12),
                          SizedBox(width: 4),
                          Text('Edited',
                              style:
                                  TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoChip(Icons.straighten_rounded,
                    '$_originalWidth × $_originalHeight'),
                _infoChip(Icons.data_usage_rounded,
                    _formatBytes(_originalSize)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Live preview color matrix from brightness/contrast/saturation.
  List<double> _buildColorMatrix() {
    double b = _brightness / 100;
    double c = 1 + _contrast / 100;
    double s = 1 + _saturation / 100;
    // quick filter approximations for live preview
    if (_filter == ImageFilter.grayscale) {
      return const [
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ];
    }
    if (_filter == ImageFilter.invert) {
      return const [
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ];
    }
    if (_filter == ImageFilter.sepia) {
      return [
        0.393, 0.769, 0.189, 0, 0,
        0.349, 0.686, 0.168, 0, 0,
        0.272, 0.534, 0.131, 0, 0,
        0, 0, 0, 1, 0,
      ];
    }
    return [
      c, 0, 0, 0, b * 255 * c,
      0, c, 0, 0, b * 255 * c,
      0, 0, c, 0, b * 255 * c,
      0, 0, 0, 1, 0,
    ]..[0] = c * s; // light saturation effect on preview
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textHint, size: 14),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildTransformToolbar() {
    final tools = <(IconData, String, VoidCallback)>[
      (Icons.rotate_90_degrees_ccw_rounded, 'Rotate', _rotate),
      (
        Icons.flip_rounded,
        'Flip H',
        () {
          HapticFeedback.lightImpact();
          setState(() => _flipH = !_flipH);
        }
      ),
      (
        Icons.flip_outlined,
        'Flip V',
        () {
          HapticFeedback.lightImpact();
          setState(() => _flipV = !_flipV);
        }
      ),
      (Icons.restart_alt_rounded, 'Reset', _resetAdjustments),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tools.map((t) {
          final active = (t.$2 == 'Flip H' && _flipH) ||
              (t.$2 == 'Flip V' && _flipV);
          return GestureDetector(
            onTap: t.$3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF6C5CE7).withValues(alpha: 0.2)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(t.$1,
                      color: active
                          ? const Color(0xFFA29BFE)
                          : AppColors.textSecondary,
                      size: 20),
                ),
                const SizedBox(height: 4),
                Text(t.$2,
                    style: TextStyle(
                        color: active
                            ? const Color(0xFFA29BFE)
                            : AppColors.textHint,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSizePresets() {
    final presets = [
      ('HD', 1280, 720),
      ('FHD', 1920, 1080),
      ('Icon', 512, 512),
      ('Thumb', 200, 200),
      ('Insta', 1080, 1080),
      ('Story', 1080, 1920),
      ('4K', 3840, 2160),
      ('Avatar', 256, 256),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Presets',
            style: AppTypography.labelLarge.copyWith(fontSize: 14)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((p) {
            return GestureDetector(
              onTap: () => _applyPreset(p.$2, p.$3),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  children: [
                    Text(p.$1,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    Text('${p.$2}×${p.$3}',
                        style: const TextStyle(
                            color: AppColors.textHint, fontSize: 9)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDimensionInputs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _dimensionField(
                    'Width', _widthController, _onWidthChanged),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  _maintainAspect
                      ? Icons.link_rounded
                      : Icons.link_off_rounded,
                  color: _maintainAspect
                      ? AppColors.primaryCyan
                      : AppColors.textHint,
                  size: 20,
                ),
              ),
              Expanded(
                child: _dimensionField(
                    'Height', _heightController, _onHeightChanged),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: _maintainAspect,
                onChanged: (v) => setState(() => _maintainAspect = v),
                activeThumbColor: AppColors.primaryCyan,
              ),
              const SizedBox(width: 8),
              const Text('Maintain aspect ratio',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dimensionField(String label, TextEditingController controller,
      Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixText: 'px',
            suffixStyle:
                const TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildQualitySlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quality',
                  style:
                      AppTypography.labelLarge.copyWith(fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_quality.round()}%',
                    style: const TextStyle(
                        color: AppColors.primaryCyan,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primaryCyan,
              inactiveTrackColor: AppColors.surfaceLight,
              thumbColor: AppColors.primaryCyan,
              overlayColor: AppColors.primaryCyan.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _quality,
              min: 10,
              max: 100,
              divisions: 9,
              onChanged: (v) => setState(() => _quality = v),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low',
                  style: TextStyle(color: AppColors.textHint, fontSize: 10)),
              Text('High',
                  style: TextStyle(color: AppColors.textHint, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          // Estimated Size display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calculate_rounded, color: AppColors.textHint, size: 14),
              const SizedBox(width: 6),
              Text(
                'Estimated Size: ${_getEstimatedSize()}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getEstimatedSize() {
    if (_originalSize == 0 || _originalWidth == 0 || _originalHeight == 0) return '---';
    final targetW = int.tryParse(_widthController.text) ?? _originalWidth;
    final targetH = int.tryParse(_heightController.text) ?? _originalHeight;
    final areaRatio = (targetW * targetH) / (_originalWidth * _originalHeight);
    final qualityRatio = _quality / 100.0;
    // Rough estimation formula
    final est = _originalSize * areaRatio * qualityRatio * 0.8;
    return _formatBytes(est.toInt());
  }

  Widget _buildFormatSelector() {
    final formats = ['jpg', 'png'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Output Format',
              style: AppTypography.labelLarge.copyWith(fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: formats.map((f) {
              final isSelected = _selectedFormat == f;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFormat = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)])
                          : null,
                      color: isSelected ? null : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? null
                          : Border.all(color: AppColors.glassBorder),
                    ),
                    child: Text(
                      f.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textHint,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fine Tune',
                  style:
                      AppTypography.labelLarge.copyWith(fontSize: 14)),
              GestureDetector(
                onTap: _resetAdjustments,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Reset',
                      style: TextStyle(
                          color: AppColors.error, fontSize: 10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _adjustSlider(
            label: 'Brightness',
            icon: Icons.brightness_6_rounded,
            value: _brightness,
            onChanged: (v) => setState(() => _brightness = v),
          ),
          _adjustSlider(
            label: 'Contrast',
            icon: Icons.contrast_rounded,
            value: _contrast,
            onChanged: (v) => setState(() => _contrast = v),
          ),
          _adjustSlider(
            label: 'Saturation',
            icon: Icons.water_drop_rounded,
            value: _saturation,
            onChanged: (v) => setState(() => _saturation = v),
          ),
        ],
      ),
    );
  }

  Widget _adjustSlider({
    required String label,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textHint, size: 16),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFF6C5CE7),
                inactiveTrackColor: AppColors.surfaceLight,
                thumbColor: const Color(0xFFA29BFE),
                overlayColor: const Color(0xFFA29BFE).withValues(alpha: 0.2),
                trackHeight: 3,
              ),
              child: Slider(
                value: value,
                min: -100,
                max: 100,
                divisions: 40,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              value > 0 ? '+${value.round()}' : '${value.round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AppColors.textHint, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filters',
            style: AppTypography.labelLarge.copyWith(fontSize: 14)),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ImageFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final f = ImageFilter.values[index];
              final isSelected = _filter == f;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _filter = f);
                },
                child: Container(
                  width: 64,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6C5CE7)
                          : AppColors.glassBorder,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          f == ImageFilter.none
                              ? Icons.layers_rounded
                              : Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(f.label,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textHint,
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResizeButton() {
    return GestureDetector(
      onTap: _isProcessing ? null : _resizeImage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            else
              const Icon(Icons.auto_fix_high_rounded,
                  color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              _isProcessing ? 'Processing...' : 'Apply & Export',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final savings = _originalSize > 0
        ? (100 - (_resizedSize / _originalSize * 100)).toStringAsFixed(1)
        : '0';
    final isSmaller = _resizedSize < _originalSize;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00B894).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF00B894).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF00B894), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Exported Successfully!',
                    style: AppTypography.labelLarge.copyWith(
                        color: const Color(0xFF00B894), fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _resultStat('Original', _formatBytes(_originalSize)),
              _resultStat('New Size', _formatBytes(_resizedSize)),
              _resultStat(
                  isSmaller ? 'Saved' : 'Grew',
                  '${isSmaller ? savings : (-double.parse(savings)).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _shareResized,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B894).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share_rounded,
                            color: Color(0xFF00B894), size: 18),
                        SizedBox(width: 8),
                        Text('Share',
                            style: TextStyle(
                                color: Color(0xFF00B894),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: AppColors.background,
                        appBar: AppBar(
                          title: const Text('Preview'),
                          backgroundColor: AppColors.surface,
                        ),
                        body: Center(
                          child: Image.file(_resizedImage!),
                        ),
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_rounded,
                            color: AppColors.primaryCyan, size: 18),
                        SizedBox(width: 8),
                        Text('Preview',
                            style: TextStyle(
                                color: AppColors.primaryCyan,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: AppColors.textHint, fontSize: 10)),
      ],
    );
  }
}
