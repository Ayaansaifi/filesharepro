import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<File> _selectedImages = [];
  bool _isConverting = false;
  String _pdfFileName = 'converted_images';
  bool _addMargin = false;

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null) {
            _selectedImages.add(File(file.path!));
          }
        }
      });
    }
  }

  void _removeImage(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedImages.removeAt(index));
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  Future<void> _convertToPdf() async {
    if (_selectedImages.isEmpty) return;

    setState(() => _isConverting = true);

    try {
      final pdf = pw.Document();

      for (final imageFile in _selectedImages) {
        final bytes = await imageFile.readAsBytes();
        final image = pw.MemoryImage(bytes);

        // Decode to get dimensions for proper aspect ratio
        final decoded = img.decodeImage(bytes);
        final double imgWidth = decoded?.width.toDouble() ?? 595;
        final double imgHeight = decoded?.height.toDouble() ?? 842;

        // Calculate page size based on image aspect ratio
        final ratio = imgWidth / imgHeight;
        PdfPageFormat pageFormat;
        if (ratio > 1) {
          // Landscape
          pageFormat = PdfPageFormat(imgWidth * 0.75, imgHeight * 0.75,
              marginAll: 0);
        } else {
          // Portrait
          pageFormat = PdfPageFormat(imgWidth * 0.75, imgHeight * 0.75,
              marginAll: 0);
        }

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: _addMargin ? const pw.EdgeInsets.all(20) : pw.EdgeInsets.zero,
            build: (context) {
              return pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      final pdfBytes = await pdf.save();

      // Save to temp
      final dir = await getTemporaryDirectory();
      final safeName = _pdfFileName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final filePath = '${dir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        setState(() => _isConverting = false);
        _showSuccessDialog(filePath, pdfBytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        _showSnackBar('❌ Failed to convert: $e', isError: true);
      }
    }
  }

  void _showSuccessDialog(String filePath, Uint8List pdfBytes) {
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
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00B894).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF00B894), size: 48),
            ),
            const SizedBox(height: 16),
            Text('PDF Created Successfully! ✅',
                style: AppTypography.heading3.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text('${_selectedImages.length} images converted',
                style: AppTypography.caption),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    color: AppColors.primaryCyan,
                    onTap: () {
                      Navigator.pop(ctx);
                      Share.shareXFiles([XFile(filePath)],
                          text: 'PDF created by FileShare Pro');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    icon: Icons.print_rounded,
                    label: 'Print',
                    color: const Color(0xFF6C5CE7),
                    onTap: () {
                      Navigator.pop(ctx);
                      Printing.layoutPdf(
                          onLayout: (_) => Future.value(pdfBytes));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
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
              const SizedBox(height: 16),
              _buildFileNameInput(),
              const SizedBox(height: 12),
              _buildMarginToggle(),
              const SizedBox(height: 16),
              Expanded(
                child: _selectedImages.isEmpty
                    ? _buildEmptyState()
                    : _buildImageGrid(),
              ),
              _buildBottomBar(),
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
                colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image to PDF',
                    style: AppTypography.heading3.copyWith(fontSize: 18)),
                Text('इमेज से PDF बनाएं',
                    style: TextStyle(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_selectedImages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${_selectedImages.length} images',
                  style: const TextStyle(
                      color: AppColors.primaryCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildFileNameInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'PDF file name...',
            hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.6)),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon: const Icon(Icons.edit_rounded,
                color: AppColors.textHint, size: 18),
          ),
          onChanged: (val) => _pdfFileName = val.isEmpty ? 'converted_images' : val,
        ),
      ),
    );
  }

  Widget _buildMarginToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Add white borders (margins)', style: TextStyle(color: Colors.white, fontSize: 14)),
            Switch(
              value: _addMargin,
              onChanged: (v) => setState(() => _addMargin = v),
              activeThumbColor: const Color(0xFFFF6B6B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: GestureDetector(
        onTap: _pickImages,
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_photo_alternate_rounded,
                    color: Color(0xFFFF6B6B), size: 48),
              ),
              const SizedBox(height: 20),
              Text('Tap to select images',
                  style: AppTypography.heading3.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              Text('Select multiple images to convert into PDF',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _selectedImages.length,
      onReorder: _reorderImages,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              color: Colors.transparent,
              elevation: 8,
              shadowColor: AppColors.primaryCyan.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        return Container(
          key: ValueKey(_selectedImages[index].path),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
                child: Image.file(
                  _selectedImages[index],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 80, height: 80,
                    color: AppColors.surfaceLight,
                    child: const Icon(Icons.broken_image, color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page ${index + 1}',
                      style: AppTypography.labelLarge.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedImages[index].path.split('/').last,
                      style: AppTypography.caption.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Drag handle
              const Icon(Icons.drag_handle_rounded,
                  color: AppColors.textHint, size: 20),
              // Delete
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.error, size: 20),
                onPressed: () => _removeImage(index),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        children: [
          // Add more images
          Expanded(
            child: GestureDetector(
              onTap: _pickImages,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded,
                        color: AppColors.primaryCyan, size: 20),
                    SizedBox(width: 8),
                    Text('Add Images',
                        style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Convert
          Expanded(
            child: GestureDetector(
              onTap: _selectedImages.isEmpty || _isConverting
                  ? null
                  : _convertToPdf,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: _selectedImages.isEmpty
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                        ),
                  color:
                      _selectedImages.isEmpty ? AppColors.surfaceLight : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _selectedImages.isNotEmpty
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isConverting)
                      const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isConverting ? 'Converting...' : 'Convert',
                      style: TextStyle(
                        color: _selectedImages.isEmpty
                            ? AppColors.textHint
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
