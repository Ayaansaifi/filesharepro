import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class PdfMakerScreen extends StatefulWidget {
  const PdfMakerScreen({super.key});

  @override
  State<PdfMakerScreen> createState() => _PdfMakerScreenState();
}

class _PdfMakerScreenState extends State<PdfMakerScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  double _fontSize = 14;
  bool _isGenerating = false;
  String _selectedFont = 'Helvetica';
  String _selectedPageSize = 'A4';
  bool _addDate = true;
  bool _addPageNumbers = true;
  File? _logoImage;
  pw.TextAlign _textAlign = pw.TextAlign.left;

  final _fontOptions = ['Helvetica', 'Courier', 'Times'];
  final _pageSizes = {
    'A4': PdfPageFormat.a4,
    'Letter': PdfPageFormat.letter,
    'Legal': PdfPageFormat.legal,
    'A5': PdfPageFormat.a5,
  };

  pw.Font _getPdfFont() {
    switch (_selectedFont) {
      case 'Courier':
        return pw.Font.courier();
      case 'Times':
        return pw.Font.times();
      default:
        return pw.Font.helvetica();
    }
  }

  pw.Font _getPdfFontBold() {
    switch (_selectedFont) {
      case 'Courier':
        return pw.Font.courierBold();
      case 'Times':
        return pw.Font.timesBold();
      default:
        return pw.Font.helveticaBold();
    }
  }

  Future<void> _generatePdf() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('Please enter some content', isError: true);
      return;
    }

    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    try {
      final pdf = pw.Document();
      final title = _titleController.text.trim();
      final pageFormat = _pageSizes[_selectedPageSize] ?? PdfPageFormat.a4;
      final font = _getPdfFont();
      final fontBold = _getPdfFontBold();
      final now = DateTime.now();
      final dateStr =
          '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

      final pw.MemoryImage? logoProvider = _logoImage != null
          ? pw.MemoryImage(_logoImage!.readAsBytesSync())
          : null;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(40),
          header: (context) {
            if (context.pageNumber == 1 && (title.isNotEmpty || logoProvider != null)) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoProvider != null) ...[
                    pw.Image(logoProvider, height: 60),
                    pw.SizedBox(height: 16),
                  ],
                  if (title.isNotEmpty)
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: _fontSize + 10,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                  if (_addDate)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(
                        'Created: $dateStr',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.blueGrey200, thickness: 0.5),
                  pw.SizedBox(height: 12),
                ],
              );
            }
            return pw.SizedBox();
          },
          footer: _addPageNumbers
              ? (context) {
                  return pw.Container(
                    alignment: pw.Alignment.centerRight,
                    margin: const pw.EdgeInsets.only(top: 8),
                    child: pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: PdfColors.grey500,
                      ),
                    ),
                  );
                }
              : null,
          build: (context) {
            final paragraphs = content.split('\n');
            return paragraphs.map((para) {
              if (para.trim().isEmpty) {
                return pw.SizedBox(height: _fontSize * 0.8);
              }
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  para,
                  textAlign: _textAlign,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: _fontSize,
                    color: PdfColors.grey800,
                    lineSpacing: _fontSize * 0.6,
                  ),
                ),
              );
            }).toList();
          },
        ),
      );

      final pdfBytes = await pdf.save();

      // Save
      final dir = await getTemporaryDirectory();
      final safeName = (title.isNotEmpty ? title : 'document')
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final filePath =
          '${dir.path}/${safeName}_${now.millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        setState(() => _isGenerating = false);
        _showSuccessDialog(filePath, pdfBytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        _showSnackBar('❌ Failed: $e', isError: true);
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
              width: 40,
              height: 4,
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
            Text('PDF Created! ✅',
                style: AppTypography.heading3.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(_titleController.text.isNotEmpty
                ? _titleController.text
                : 'Document ready',
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
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    icon: Icons.preview_rounded,
                    label: 'Preview',
                    color: const Color(0xFFFDCB6E),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: AppColors.background,
                            appBar: AppBar(
                              title: const Text('PDF Preview'),
                              backgroundColor: AppColors.surface,
                            ),
                            body: PdfPreview(
                              build: (_) => Future.value(pdfBytes),
                              canChangeOrientation: false,
                              canChangePageFormat: false,
                            ),
                          ),
                        ),
                      );
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
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
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
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
                      _buildTitleInput(),
                      const SizedBox(height: 16),
                      _buildLogoPicker(),
                      const SizedBox(height: 16),
                      _buildContentInput(),
                      const SizedBox(height: 20),
                      _buildAlignmentToggles(),
                      const SizedBox(height: 16),
                      _buildOptionsSection(),
                      const SizedBox(height: 24),
                      _buildGenerateButton(),
                      const SizedBox(height: 80),
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
                colors: [Color(0xFFFDCB6E), Color(0xFFE17055)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.note_add_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PDF Maker',
                    style: AppTypography.heading3.copyWith(fontSize: 18)),
                Text('PDF बनाएं',
                    style: TextStyle(
                        color: const Color(0xFFFDCB6E).withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Word count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_contentController.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words',
              style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: _titleController,
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Document Title (optional)...',
          hintStyle:
              TextStyle(color: AppColors.textHint.withValues(alpha: 0.5), fontSize: 16),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.title_rounded,
                color: Color(0xFFFDCB6E), size: 22),
          ),
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _logoImage = File(result.files.single.path!);
      });
    }
  }

  Widget _buildLogoPicker() {
    return GestureDetector(
      onTap: _pickLogo,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDCB6E).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.image_rounded, color: Color(0xFFFDCB6E), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Document Logo', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(_logoImage != null ? 'Logo selected' : 'Optional header image', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                ],
              ),
            ),
            if (_logoImage != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.error),
                onPressed: () => setState(() => _logoImage = null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentToggles() {
    final aligns = [
      (Icons.format_align_left_rounded, pw.TextAlign.left),
      (Icons.format_align_center_rounded, pw.TextAlign.center),
      (Icons.format_align_right_rounded, pw.TextAlign.right),
      (Icons.format_align_justify_rounded, pw.TextAlign.justify),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: aligns.map((a) {
          final isSelected = _textAlign == a.$2;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _textAlign = a.$2);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFDCB6E).withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(a.$1, color: isSelected ? const Color(0xFFFDCB6E) : AppColors.textHint),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContentInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: _contentController,
        maxLines: 12,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Write your content here...\n\nYou can write notes, letters, reports, or anything you want to convert into a professional PDF.',
          hintStyle: TextStyle(
              color: AppColors.textHint.withValues(alpha: 0.4),
              fontSize: 13,
              height: 1.6),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PDF Settings',
              style: AppTypography.labelLarge.copyWith(fontSize: 15)),
          const SizedBox(height: 16),

          // Font size slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Font Size',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDCB6E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_fontSize.round()}pt',
                    style: const TextStyle(
                        color: Color(0xFFFDCB6E),
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFFDCB6E),
              inactiveTrackColor: AppColors.surfaceLight,
              thumbColor: const Color(0xFFFDCB6E),
              overlayColor: const Color(0xFFFDCB6E).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _fontSize,
              min: 8,
              max: 28,
              divisions: 10,
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ),

          Divider(color: AppColors.glassBorder, height: 24),

          // Font selection
          const Text('Font Style',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: _fontOptions.map((f) {
              final isSelected = _selectedFont == f;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFont = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFFDCB6E), Color(0xFFE17055)])
                          : null,
                      color: isSelected ? null : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textHint,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          Divider(color: AppColors.glassBorder, height: 24),

          // Page size
          const Text('Page Size',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _pageSizes.keys.map((s) {
              final isSelected = _selectedPageSize == s;
              return GestureDetector(
                onTap: () => setState(() => _selectedPageSize = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFFFDCB6E), Color(0xFFE17055)])
                        : null,
                    color: isSelected ? null : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textHint,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          Divider(color: AppColors.glassBorder, height: 24),

          // Toggles
          _toggleOption(
            label: 'Add creation date',
            value: _addDate,
            onChanged: (v) => setState(() => _addDate = v),
          ),
          const SizedBox(height: 8),
          _toggleOption(
            label: 'Add page numbers',
            value: _addPageNumbers,
            onChanged: (v) => setState(() => _addPageNumbers = v),
          ),
        ],
      ),
    );
  }

  Widget _toggleOption({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFFFDCB6E),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    final hasContent = _contentController.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: hasContent && !_isGenerating ? _generatePdf : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: hasContent
              ? const LinearGradient(
                  colors: [Color(0xFFFDCB6E), Color(0xFFE17055)],
                )
              : null,
          color: hasContent ? null : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          boxShadow: hasContent
              ? [
                  BoxShadow(
                    color: const Color(0xFFFDCB6E).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isGenerating)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            else
              Icon(Icons.picture_as_pdf_rounded,
                  color: hasContent ? Colors.white : AppColors.textHint,
                  size: 22),
            const SizedBox(width: 10),
            Text(
              _isGenerating ? 'Generating...' : 'Create PDF',
              style: TextStyle(
                color: hasContent ? Colors.white : AppColors.textHint,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
