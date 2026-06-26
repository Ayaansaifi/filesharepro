import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_animated_builder.dart';
import '../../../core/widgets/glass_card.dart';

class MemeText {
  final String id;
  String text;
  Offset position;
  double fontSize;
  Color color;
  Color strokeColor;
  bool isBold;

  MemeText({
    required this.id,
    required this.text,
    required this.position,
    this.fontSize = 32.0,
    this.color = Colors.white,
    this.strokeColor = Colors.black,
    this.isBold = true,
  });
}

class MemeGeneratorScreen extends StatefulWidget {
  const MemeGeneratorScreen({super.key});

  @override
  State<MemeGeneratorScreen> createState() => _MemeGeneratorScreenState();
}

class _MemeGeneratorScreenState extends State<MemeGeneratorScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0; // 0 = Editor, 1 = My Memes
  
  // Editor State
  File? _selectedImage;
  List<MemeText> _memeTexts = [];
  MemeText? _selectedText;
  final _globalKey = GlobalKey();
  bool _isProcessing = false;
  
  // My Memes State
  List<File> _savedMemes = [];
  bool _isLoadingMemes = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
      if (_currentIndex == 1) {
        _loadSavedMemes();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── EDITOR LOGIC ─────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 100);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _memeTexts.clear();
          _selectedText = null;
        });
        
        // Add default top and bottom texts
        _addTextItem(text: "TOP TEXT", position: const Offset(100, 50));
        _addTextItem(text: "BOTTOM TEXT", position: const Offset(100, 250));
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: $e', isError: true);
    }
  }

  void _addTextItem({String text = "NEW TEXT", Offset? position}) {
    setState(() {
      final newText = MemeText(
        id: const Uuid().v4(),
        text: text,
        position: position ?? const Offset(100, 100),
      );
      _memeTexts.add(newText);
      _selectedText = newText;
    });
  }

  void _editText(MemeText textItem) {
    final textController = TextEditingController(text: textItem.text);
    double tempFontSize = textItem.fontSize;
    Color tempColor = textItem.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Text', style: AppTypography.heading4),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Enter meme text',
                      hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.5)),
                    ),
                    onChanged: (value) {
                      setState(() {
                        textItem.text = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('Font Size: ${tempFontSize.toInt()}', style: AppTypography.labelLarge),
                  Slider(
                    value: tempFontSize,
                    min: 12,
                    max: 100,
                    activeColor: AppColors.primaryCyan,
                    onChanged: (value) {
                      setModalState(() => tempFontSize = value);
                      setState(() => textItem.fontSize = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('Color', style: AppTypography.labelLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: [Colors.white, Colors.black, Colors.red, Colors.yellow, Colors.blue, Colors.green].map((c) {
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => tempColor = c);
                          setState(() {
                            textItem.color = c;
                            textItem.strokeColor = c == Colors.black ? Colors.white : Colors.black;
                          });
                        },
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tempColor == c ? AppColors.primaryCyan : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _memeTexts.removeWhere((t) => t.id == textItem.id);
                            if (_selectedText?.id == textItem.id) _selectedText = null;
                          });
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                        label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryCyan,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _captureAndSaveMeme() async {
    if (_selectedImage == null) return;
    
    setState(() {
      _selectedText = null; // Deselect text to hide boundaries
      _isProcessing = true;
    });

    try {
      // Small delay to let UI update
      await Future.delayed(const Duration(milliseconds: 100));

      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to App Directory for "My Memes"
      final directory = await getApplicationDocumentsDirectory();
      final memesDir = Directory('${directory.path}/memes');
      if (!await memesDir.exists()) {
        await memesDir.create(recursive: true);
      }
      final filePath = '${memesDir.path}/meme_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Save to Gallery
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      await Gal.putImage(filePath);

      _showSnackBar('✅ Meme saved to Gallery and My Memes!');
    } catch (e) {
      _showSnackBar('❌ Failed to save meme: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareMeme() async {
    if (_selectedImage == null) return;

    setState(() {
      _selectedText = null;
      _isProcessing = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/shared_meme.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Created with FileShare Pro Meme Generator!');
    } catch (e) {
      _showSnackBar('❌ Failed to share meme: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── MY MEMES LOGIC ───────────────────────────────────────────

  Future<void> _loadSavedMemes() async {
    setState(() => _isLoadingMemes = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final memesDir = Directory('${directory.path}/memes');
      if (await memesDir.exists()) {
        final List<FileSystemEntity> entities = memesDir.listSync();
        final List<File> files = entities.whereType<File>().where((f) => f.path.endsWith('.png')).toList();
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        setState(() {
          _savedMemes = files;
        });
      }
    } catch (e) {
      debugPrint('Error loading memes: $e');
    } finally {
      setState(() => _isLoadingMemes = false);
    }
  }

  Future<void> _deleteMeme(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        setState(() {
          _savedMemes.removeWhere((f) => f.path == file.path);
        });
        _showSnackBar('Meme deleted');
      }
    } catch (e) {
      _showSnackBar('Failed to delete meme', isError: true);
    }
  }

  // ─── UI BUILDERS ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.background, Color(0xFF1A1F38)],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildEditorTab(),
            _buildMyMemesTab(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Meme Generator', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Create, Edit & Save', style: TextStyle(color: AppColors.primaryCyan.withValues(alpha: 0.8), fontSize: 12)),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primaryCyan,
        labelColor: AppColors.primaryCyan,
        unselectedLabelColor: AppColors.textHint,
        tabs: const [
          Tab(text: 'Editor', icon: Icon(Icons.edit_rounded)),
          Tab(text: 'My Memes', icon: Icon(Icons.photo_library_rounded)),
        ],
      ),
    );
  }

  Widget _buildEditorTab() {
    return Column(
      children: [
        Expanded(
          child: _selectedImage == null
              ? _buildEmptyState()
              : _buildMemeWorkspace(),
        ),
        if (_selectedImage != null) _buildEditorToolbar(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(32),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sentiment_very_satisfied_rounded, size: 64, color: AppColors.primaryCyan),
            ),
            const SizedBox(height: 24),
            const Text('Create a Meme', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Start by selecting an image', style: TextStyle(color: AppColors.textHint, fontSize: 16)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFFFF6B6B),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 16),
                _buildActionBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF6C5CE7),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemeWorkspace() {
    return GestureDetector(
      onTap: () => setState(() => _selectedText = null),
      child: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: RepaintBoundary(
            key: _globalKey,
            child: Stack(
              children: [
                Image.file(
                  _selectedImage!,
                  fit: BoxFit.contain,
                ),
                for (var textItem in _memeTexts) _buildDraggableText(textItem),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableText(MemeText textItem) {
    final isSelected = _selectedText?.id == textItem.id;

    return Positioned(
      left: textItem.position.dx,
      top: textItem.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            textItem.position += details.delta;
            _selectedText = textItem;
          });
        },
        onTap: () {
          setState(() {
            _selectedText = textItem;
          });
          _editText(textItem);
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: isSelected ? Border.all(color: Colors.white, width: 2, style: BorderStyle.solid) : null,
          ),
          child: Stack(
            children: [
              // Stroke text
              Text(
                textItem.text.toUpperCase(),
                style: TextStyle(
                  fontSize: textItem.fontSize,
                  fontWeight: textItem.isBold ? FontWeight.w900 : FontWeight.normal,
                  fontFamily: 'Impact', // Typical meme font
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = textItem.fontSize * 0.15
                    ..color = textItem.strokeColor,
                ),
              ),
              // Solid text
              Text(
                textItem.text.toUpperCase(),
                style: TextStyle(
                  fontSize: textItem.fontSize,
                  fontWeight: textItem.isBold ? FontWeight.w900 : FontWeight.normal,
                  fontFamily: 'Impact',
                  color: textItem.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildToolbarIcon(
              icon: Icons.add_photo_alternate_rounded,
              label: 'Change',
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            _buildToolbarIcon(
              icon: Icons.title_rounded,
              label: 'Add Text',
              onTap: () => _addTextItem(position: const Offset(100, 150)),
            ),
            _buildToolbarIcon(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: _isProcessing ? null : _shareMeme,
              isAction: true,
            ),
            _buildToolbarIcon(
              icon: Icons.download_rounded,
              label: 'Save',
              onTap: _isProcessing ? null : _captureAndSaveMeme,
              isAction: true,
              color: AppColors.primaryCyan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarIcon({required IconData icon, required String label, VoidCallback? onTap, bool isAction = false, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isAction ? 12 : 10),
            decoration: BoxDecoration(
              color: isAction ? (color ?? Colors.white.withValues(alpha: 0.1)).withValues(alpha: 0.15) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color ?? Colors.white, size: isAction ? 24 : 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color ?? Colors.white, fontSize: 10, fontWeight: isAction ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ─── MY MEMES TAB ───────────────────────────────────────────────

  Widget _buildMyMemesTab() {
    if (_isLoadingMemes) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan));
    }

    if (_savedMemes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_rounded, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('No memes saved yet.', style: TextStyle(color: AppColors.textHint, fontSize: 16)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _savedMemes.length,
      itemBuilder: (context, index) {
        final file = _savedMemes[index];
        return GestureDetector(
          onTap: () => _viewMeme(file),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
              image: DecorationImage(
                image: FileImage(file),
                fit: BoxFit.cover,
              ),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => _deleteMeme(file),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_rounded, color: AppColors.error, size: 18),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _viewMeme(File file) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              InteractiveViewer(
                child: Image.file(file),
              ),
              Positioned(
                top: -10, right: -10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                bottom: -50, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Share.shareXFiles([XFile(file.path)]);
                      },
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      label: const Text('Share', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
