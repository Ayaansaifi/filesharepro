import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class BpCheckerScreen extends StatefulWidget {
  const BpCheckerScreen({super.key});

  @override
  State<BpCheckerScreen> createState() => _BpCheckerScreenState();
}

class _BpCheckerScreenState extends State<BpCheckerScreen>
    with TickerProviderStateMixin {
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _notesController = TextEditingController();
  BpResult? _result;
  List<BpRecord> _history = [];
  late AnimationController _gaugeAnimController;
  late AnimationController _heartAnimController;
  late AnimationController _resultSlideController;
  late Animation<double> _gaugeAnimation;
  late Animation<double> _heartAnimation;
  late Animation<Offset> _resultSlideAnimation;
  bool _showHistory = false;
  bool _showTrends = false;
  String _selectedTimeOfDay = 'Morning';

  @override
  void initState() {
    super.initState();
    _gaugeAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _gaugeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _gaugeAnimController, curve: Curves.easeOutCubic),
    );

    _heartAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _heartAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _heartAnimController, curve: Curves.easeInOut),
    );

    _resultSlideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _resultSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _resultSlideController, curve: Curves.easeOutCubic));

    _loadHistory();
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    _notesController.dispose();
    _gaugeAnimController.dispose();
    _heartAnimController.dispose();
    _resultSlideController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('bp_history_v2') ?? [];
    setState(() {
      _history = data
          .map((e) {
            try {
              return BpRecord.fromJson(jsonDecode(e));
            } catch (_) {
              return null;
            }
          })
          .whereType<BpRecord>()
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<void> _saveRecord(BpRecord record) async {
    _history.insert(0, record);
    if (_history.length > 100) _history = _history.sublist(0, 100);
    final prefs = await SharedPreferences.getInstance();
    final data = _history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('bp_history_v2', data);
  }

  Future<void> _deleteRecord(int index) async {
    HapticFeedback.lightImpact();
    setState(() => _history.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    final data = _history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('bp_history_v2', data);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bp_history_v2');
    setState(() => _history.clear());
    _showSnackBar('✅ History cleared');
  }

  void _checkBP() {
    final systolic = int.tryParse(_systolicController.text);
    final diastolic = int.tryParse(_diastolicController.text);
    final pulse = int.tryParse(_pulseController.text);

    if (systolic == null || diastolic == null) {
      _showSnackBar('❌ Please enter valid Systolic and Diastolic values', isError: true);
      return;
    }
    if (systolic < 40 || systolic > 300 || diastolic < 20 || diastolic > 200) {
      _showSnackBar('❌ Values out of range', isError: true);
      return;
    }
    if (diastolic >= systolic) {
      _showSnackBar('❌ Diastolic must be less than Systolic', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();

    final result = _analyzeBP(systolic, diastolic);
    setState(() => _result = result);

    _gaugeAnimController.reset();
    _gaugeAnimController.forward();
    _resultSlideController.reset();
    _resultSlideController.forward();

    // Pulse heart animation
    _heartAnimController.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _heartAnimController.stop();
    });

    _saveRecord(BpRecord(
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
      category: result.category,
      date: DateTime.now(),
      timeOfDay: _selectedTimeOfDay,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    ));
    _loadHistory();
  }

  BpResult _analyzeBP(int systolic, int diastolic) {
    if (systolic < 90 || diastolic < 60) {
      return BpResult(
        category: 'Low (Hypotension)',
        categoryHi: 'कम (हाइपोटेंशन)',
        color: const Color(0xFF74B9FF),
        icon: Icons.arrow_downward_rounded,
        message: 'Your blood pressure is lower than normal.',
        messageHi: 'आपका BP सामान्य से कम है।',
        severity: 0.10,
        tips: [
          '💧 Stay hydrated — drink more water',
          '🧂 Increase salt intake slightly',
          '🚶 Avoid standing up too quickly',
          '☕ Caffeine can help temporarily',
          '🩺 Consult doctor if dizzy or fainting',
        ],
      );
    } else if (systolic < 120 && diastolic < 80) {
      return BpResult(
        category: 'Normal',
        categoryHi: 'सामान्य',
        color: const Color(0xFF00B894),
        icon: Icons.check_circle_rounded,
        message: 'Your blood pressure is in the healthy range!',
        messageHi: 'आपका BP बिल्कुल ठीक है!',
        severity: 0.30,
        tips: [
          '🎉 Great! Keep maintaining your lifestyle',
          '🏃 Continue regular exercise',
          '🥗 Maintain balanced diet',
          '😴 Get 7-8 hours of sleep',
          '🧘 Manage stress with meditation',
        ],
      );
    } else if (systolic < 130 && diastolic < 80) {
      return BpResult(
        category: 'Elevated',
        categoryHi: 'थोड़ा बढ़ा हुआ',
        color: const Color(0xFFFDCB6E),
        icon: Icons.trending_up_rounded,
        message: 'Slightly elevated. Lifestyle changes recommended.',
        messageHi: 'थोड़ा बढ़ा हुआ है। जीवनशैली में बदलाव करें।',
        severity: 0.45,
        tips: [
          '🧂 Reduce sodium/salt intake',
          '🏋️ Exercise at least 30 min daily',
          '🚭 Avoid smoking and limit alcohol',
          '⚖️ Maintain a healthy weight',
          '📊 Monitor BP regularly',
        ],
      );
    } else if (systolic < 140 || diastolic < 90) {
      return BpResult(
        category: 'High — Stage 1',
        categoryHi: 'उच्च — स्टेज 1',
        color: const Color(0xFFE17055),
        icon: Icons.warning_rounded,
        message: 'High blood pressure Stage 1. See your doctor.',
        messageHi: 'हाई BP स्टेज 1। डॉक्टर से सलाह लें।',
        severity: 0.65,
        tips: [
          '🩺 Consult a doctor promptly',
          '💊 Medication may be needed',
          '🧂 DASH diet recommended',
          '🏃 Regular cardio exercise',
          '📉 Target: below 130/80',
        ],
      );
    } else if (systolic < 180 || diastolic < 120) {
      return BpResult(
        category: 'High — Stage 2',
        categoryHi: 'उच्च — स्टेज 2',
        color: const Color(0xFFD63031),
        icon: Icons.error_rounded,
        message: 'High blood pressure Stage 2. Medical attention needed.',
        messageHi: 'हाई BP स्टेज 2। चिकित्सा सहायता ज़रूरी है।',
        severity: 0.82,
        tips: [
          '🏥 See your doctor immediately',
          '💊 Likely needs medication',
          '📊 Monitor BP twice daily',
          '🚫 Eliminate alcohol and smoking',
          '⚡ Reduce stress urgently',
        ],
      );
    } else {
      return BpResult(
        category: 'Hypertensive Crisis!',
        categoryHi: 'हाइपरटेंसिव क्राइसिस!',
        color: const Color(0xFFFF0000),
        icon: Icons.local_hospital_rounded,
        message: '⚠️ EMERGENCY! Seek immediate medical attention.',
        messageHi: '⚠️ आपातकाल! तुरंत अस्पताल जाएं।',
        severity: 1.0,
        tips: [
          '🚨 Call emergency services NOW',
          '🏥 Go to nearest hospital',
          '💺 Sit down and stay calm',
          '🚫 Do NOT take any action on your own',
          '📱 Inform a family member',
        ],
      );
    }
  }

  // Calculate averages for trends
  Map<String, double> _getAverages() {
    if (_history.isEmpty) return {'sys': 0, 'dia': 0, 'pulse': 0};
    final last7 = _history.take(7).toList();
    final avgSys = last7.map((e) => e.systolic).reduce((a, b) => a + b) / last7.length;
    final avgDia = last7.map((e) => e.diastolic).reduce((a, b) => a + b) / last7.length;
    final pulseRecords = last7.where((e) => e.pulse != null).toList();
    final avgPulse = pulseRecords.isEmpty
        ? 0.0
        : pulseRecords.map((e) => e.pulse!).reduce((a, b) => a + b) / pulseRecords.length;
    return {'sys': avgSys, 'dia': avgDia, 'pulse': avgPulse};
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.background, Color(0xFF0F1630), Color(0xFF1A1F38)],
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
                      _buildInputSection(),
                      const SizedBox(height: 16),
                      _buildTimeOfDaySelector(),
                      const SizedBox(height: 16),
                      _buildNotesInput(),
                      const SizedBox(height: 20),
                      _buildCheckButton(),
                      if (_result != null) ...[
                        const SizedBox(height: 24),
                        _buildGaugeCard(),
                        const SizedBox(height: 20),
                        _buildResultCard(),
                        const SizedBox(height: 20),
                        _buildHealthTips(),
                      ],
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildAveragesCard(),
                        const SizedBox(height: 16),
                        _buildTrendChart(),
                      ],
                      const SizedBox(height: 24),
                      _buildHistorySection(),
                      const SizedBox(height: 24),
                      _buildBpRangeChart(),
                      const SizedBox(height: 24),
                      _buildDisclaimerCard(),
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
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF00CEC9)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BP Checker', style: AppTypography.heading3.copyWith(fontSize: 18)),
                Text('ब्लड प्रेशर चेकर',
                    style: TextStyle(
                        color: const Color(0xFF00B894).withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Pulsing heart
          AnimatedBuilder(
            animation: _heartAnimation,
            builder: (ctx, child) {
              return Transform.scale(
                scale: _heartAnimation.value,
                child: child,
              );
            },
            child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B6B), size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B6B), size: 20),
              const SizedBox(width: 8),
              Text('Enter your BP readings', style: AppTypography.labelLarge.copyWith(fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('mmHg', style: TextStyle(color: Color(0xFF00B894), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _bpInputField(
                  controller: _systolicController,
                  label: 'Systolic (ऊपर)',
                  hint: '120',
                  color: const Color(0xFFFF6B6B),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Center(
                        child: Text('/', style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.w300)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _bpInputField(
                  controller: _diastolicController,
                  label: 'Diastolic (नीचे)',
                  hint: '80',
                  color: const Color(0xFF6C5CE7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _bpInputField(
            controller: _pulseController,
            label: 'Pulse / Heart Rate (optional)',
            hint: '72 bpm',
            color: const Color(0xFF00CEC9),
          ),
        ],
      ),
    );
  }

  Widget _bpInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.3), fontSize: 20),
            filled: true,
            fillColor: color.withValues(alpha: 0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color.withValues(alpha: 0.15))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color.withValues(alpha: 0.15))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeOfDaySelector() {
    final options = ['Morning', 'Afternoon', 'Evening', 'Night'];
    final icons = [Icons.wb_sunny_rounded, Icons.wb_cloudy_rounded, Icons.nights_stay_rounded, Icons.bedtime_rounded];
    final colors = [const Color(0xFFFDCB6E), const Color(0xFF74B9FF), const Color(0xFFE17055), const Color(0xFF6C5CE7)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Time of reading', style: TextStyle(color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(4, (i) {
              final isSelected = _selectedTimeOfDay == options[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTimeOfDay = options[i]);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? colors[i].withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? colors[i].withValues(alpha: 0.5) : AppColors.glassBorder),
                    ),
                    child: Column(
                      children: [
                        Icon(icons[i], color: isSelected ? colors[i] : AppColors.textHint, size: 18),
                        const SizedBox(height: 3),
                        Text(
                          options[i].substring(0, 3),
                          style: TextStyle(color: isSelected ? colors[i] : AppColors.textHint, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 1,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Add a note (optional)... e.g., after exercise',
          hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.4), fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.textHint, size: 18),
        ),
      ),
    );
  }

  Widget _buildCheckButton() {
    return GestureDetector(
      onTap: _checkBP,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF00CEC9)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: const Color(0xFF00B894).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text('Analyze Blood Pressure', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ─── CUSTOM GAUGE ────────────────────────────────────────
  Widget _buildGaugeCard() {
    final r = _result!;
    return AnimatedBuilder(
      animation: _gaugeAnimation,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: r.color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: CustomPaint(
                  size: const Size(280, 180),
                  painter: _BpGaugePainter(
                    progress: r.severity * _gaugeAnimation.value,
                    color: r.color,
                    systolic: int.tryParse(_systolicController.text) ?? 0,
                    diastolic: int.tryParse(_diastolicController.text) ?? 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Category labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _gaugeLabelDot('Low', const Color(0xFF74B9FF)),
                  _gaugeLabelDot('Normal', const Color(0xFF00B894)),
                  _gaugeLabelDot('Elevated', const Color(0xFFFDCB6E)),
                  _gaugeLabelDot('High', const Color(0xFFE17055)),
                  _gaugeLabelDot('Crisis', const Color(0xFFFF0000)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _gaugeLabelDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 8, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    return SlideTransition(
      position: _resultSlideAnimation,
      child: FadeTransition(
        opacity: _resultSlideController,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: r.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: r.color.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: r.color.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: r.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: r.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(r.icon, color: r.color, size: 22),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.category, style: TextStyle(color: r.color, fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(r.categoryHi, style: TextStyle(color: r.color.withValues(alpha: 0.7), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Big reading
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_systolicController.text, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800)),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(' / ', style: TextStyle(color: Colors.white30, fontSize: 28, fontWeight: FontWeight.w300)),
                  ),
                  Text(_diastolicController.text, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800)),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10, left: 4),
                    child: Text('mmHg', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                  ),
                ],
              ),
              if (_pulseController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B6B), size: 14),
                      const SizedBox(width: 4),
                      Text('${_pulseController.text} bpm',
                          style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Text(
                        _getPulseCategory(int.tryParse(_pulseController.text) ?? 0),
                        style: const TextStyle(color: AppColors.textHint, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(r.message, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(r.messageHi, style: TextStyle(color: r.color.withValues(alpha: 0.7), fontSize: 12, height: 1.5), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPulseCategory(int pulse) {
    if (pulse < 60) return '(Slow)';
    if (pulse <= 100) return '(Normal)';
    return '(Fast)';
  }

  // ─── HEALTH TIPS ─────────────────────────────────────────
  Widget _buildHealthTips() {
    final r = _result!;
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
          Row(
            children: [
              Icon(Icons.tips_and_updates_rounded, color: r.color, size: 20),
              const SizedBox(width: 8),
              Text('Health Tips', style: AppTypography.labelLarge.copyWith(fontSize: 14)),
              const SizedBox(width: 6),
              Text('(स्वास्थ्य सुझाव)', style: TextStyle(color: r.color.withValues(alpha: 0.7), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 14),
          ...r.tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.substring(0, 2), style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tip.substring(2).trim(),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── 7-DAY AVERAGES ──────────────────────────────────────
  Widget _buildAveragesCard() {
    final avg = _getAverages();
    final sysResult = _analyzeBP(avg['sys']!.round(), avg['dia']!.round());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sysResult.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: AppColors.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text('7-Day Average', style: AppTypography.labelLarge.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _avgStatCard('Systolic', avg['sys']!.toStringAsFixed(0), 'mmHg', const Color(0xFFFF6B6B)),
              const SizedBox(width: 10),
              _avgStatCard('Diastolic', avg['dia']!.toStringAsFixed(0), 'mmHg', const Color(0xFF6C5CE7)),
              const SizedBox(width: 10),
              _avgStatCard('Pulse', avg['pulse']! > 0 ? avg['pulse']!.toStringAsFixed(0) : '—', 'bpm', const Color(0xFF00CEC9)),
            ],
          ),
          const SizedBox(height: 12),
          // Average category
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: sysResult.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Avg: ${sysResult.category}',
              style: TextStyle(color: sysResult.color, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avgStatCard(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(unit, style: const TextStyle(color: AppColors.textHint, fontSize: 9)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── TREND CHART ─────────────────────────────────────────
  Widget _buildTrendChart() {
    return GestureDetector(
      onTap: () => setState(() => _showTrends = !_showTrends),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart_rounded, color: AppColors.primaryCyan, size: 20),
                const SizedBox(width: 8),
                Text('BP Trend (Last 10)', style: AppTypography.labelLarge.copyWith(fontSize: 14)),
                const Spacer(),
                Icon(_showTrends ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textHint, size: 20),
              ],
            ),
            if (_showTrends && _history.length >= 2) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width - 80, 160),
                  painter: _TrendChartPainter(
                    records: _history.take(10).toList().reversed.toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _gaugeLabelDot('Systolic', const Color(0xFFFF6B6B)),
                  const SizedBox(width: 16),
                  _gaugeLabelDot('Diastolic', const Color(0xFF6C5CE7)),
                ],
              ),
            ],
            if (_showTrends && _history.length < 2)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Need at least 2 readings to show trend.', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  // ─── BP RANGE REFERENCE CHART ────────────────────────────
  Widget _buildBpRangeChart() {
    final ranges = [
      ('Low', '<90/<60', const Color(0xFF74B9FF)),
      ('Normal', '<120/<80', const Color(0xFF00B894)),
      ('Elevated', '120-129/<80', const Color(0xFFFDCB6E)),
      ('High Stage 1', '130-139/80-89', const Color(0xFFE17055)),
      ('High Stage 2', '≥140/≥90', const Color(0xFFD63031)),
      ('Crisis', '>180/>120', const Color(0xFFFF0000)),
    ];

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
          Row(
            children: [
              const Icon(Icons.table_chart_rounded, color: AppColors.primaryCyan, size: 20),
              const SizedBox(width: 8),
              Text('BP Range Reference', style: AppTypography.labelLarge.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          ...ranges.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(width: 4, height: 28, decoration: BoxDecoration(color: r.$3, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Text(r.$1, style: TextStyle(color: r.$3, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(r.$2, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── HISTORY ─────────────────────────────────────────────
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showHistory = !_showHistory),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: AppColors.primaryCyan, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('History (${_history.length} records)', style: AppTypography.labelLarge.copyWith(fontSize: 14))),
                if (_history.isNotEmpty)
                  GestureDetector(
                    onTap: () => _confirmClearHistory(),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                  ),
                const SizedBox(width: 8),
                Icon(_showHistory ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textHint, size: 20),
              ],
            ),
          ),
        ),
        if (_showHistory && _history.isNotEmpty)
          ...List.generate(_history.length.clamp(0, 30), (i) => _buildHistoryItem(i)),
        if (_showHistory && _history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('No records yet.', style: AppTypography.caption)),
          ),
      ],
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear History?', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete all saved BP records.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textHint))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearHistory();
            },
            child: const Text('Clear All', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(int index) {
    final record = _history[index];
    final result = _analyzeBP(record.systolic, record.diastolic);
    final dateStr = DateFormat('dd MMM yy, hh:mm a').format(record.date);

    return Dismissible(
      key: Key('${record.date.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(top: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_rounded, color: AppColors.error),
      ),
      onDismissed: (_) => _deleteRecord(index),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: result.color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(width: 5, height: 44, decoration: BoxDecoration(color: result.color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${record.systolic}/${record.diastolic}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                      const Text(' mmHg', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
                      if (record.pulse != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.favorite_rounded, color: const Color(0xFFFF6B6B).withValues(alpha: 0.6), size: 10),
                        Text(' ${record.pulse}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(record.category, style: TextStyle(color: result.color, fontSize: 10, fontWeight: FontWeight.w600)),
                      if (record.timeOfDay != null) ...[
                        const SizedBox(width: 6),
                        Text('• ${record.timeOfDay}', style: const TextStyle(color: AppColors.textHint, fontSize: 9)),
                      ],
                    ],
                  ),
                  if (record.notes != null)
                    Text(record.notes!, style: const TextStyle(color: AppColors.textHint, fontSize: 10, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(dateStr, style: const TextStyle(color: AppColors.textHint, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDCB6E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDCB6E).withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFFDCB6E), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '⚠️ This tool is for informational purposes ONLY. It is NOT a medical device and does NOT measure blood pressure. '
              'Always consult a qualified doctor for diagnosis.\n'
              'यह टूल केवल जानकारी के लिए है। सटीक निदान के लिए हमेशा डॉक्टर से मिलें।',
              style: TextStyle(color: const Color(0xFFFDCB6E).withValues(alpha: 0.7), fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CUSTOM GAUGE PAINTER
// ═══════════════════════════════════════════════════════════
class _BpGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final int systolic;
  final int diastolic;

  _BpGaugePainter({required this.progress, required this.color, required this.systolic, required this.diastolic});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width / 2.5;
    const startAngle = pi;
    const sweepAngle = pi;

    // Background arc segments
    final segmentColors = [
      const Color(0xFF74B9FF),
      const Color(0xFF00B894),
      const Color(0xFFFDCB6E),
      const Color(0xFFE17055),
      const Color(0xFFD63031),
      const Color(0xFFFF0000),
    ];
    final segmentSweeps = [0.15, 0.20, 0.15, 0.15, 0.20, 0.15];

    double currentStart = startAngle;
    for (int i = 0; i < segmentColors.length; i++) {
      final segSweep = sweepAngle * segmentSweeps[i];
      final paint = Paint()
        ..color = segmentColors[i].withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentStart,
        segSweep,
        false,
        paint,
      );
      currentStart += segSweep;
    }

    // Active arc
    final activePaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle * progress,
        colors: [color.withValues(alpha: 0.3), color],
        center: Alignment.center,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      activePaint,
    );

    // Needle
    final needleAngle = startAngle + sweepAngle * progress;
    final needleLength = radius - 30;
    final needleEnd = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Center dot
    canvas.drawCircle(center, 8, Paint()..color = color);
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);

    // Needle tip glow
    canvas.drawCircle(needleEnd, 5, Paint()..color = color.withValues(alpha: 0.6));
    canvas.drawCircle(needleEnd, 3, Paint()..color = color);

    // Reading text in center
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$systolic/$diastolic',
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - 35));
  }

  @override
  bool shouldRepaint(covariant _BpGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ═══════════════════════════════════════════════════════════
// TREND CHART PAINTER
// ═══════════════════════════════════════════════════════════
class _TrendChartPainter extends CustomPainter {
  final List<BpRecord> records;

  _TrendChartPainter({required this.records});

  @override
  void paint(Canvas canvas, Size size) {
    if (records.length < 2) return;

    final n = records.length;
    final dx = size.width / (n - 1);

    // Find min/max for scaling
    int minVal = 40, maxVal = 200;
    for (final r in records) {
      if (r.systolic > maxVal) maxVal = r.systolic + 10;
      if (r.diastolic < minVal) minVal = r.diastolic - 10;
    }
    final range = (maxVal - minVal).toDouble();

    double yFor(int val) => size.height - ((val - minVal) / range * size.height);

    // Grid lines
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Normal range band (120/80)
    final normalTop = yFor(120);
    final normalBottom = yFor(80);
    canvas.drawRect(
      Rect.fromLTRB(0, normalTop, size.width, normalBottom),
      Paint()..color = const Color(0xFF00B894).withValues(alpha: 0.06),
    );

    // Systolic line
    _drawLine(canvas, records.map((r) => r.systolic).toList(), dx, minVal, range, size.height, const Color(0xFFFF6B6B));

    // Diastolic line
    _drawLine(canvas, records.map((r) => r.diastolic).toList(), dx, minVal, range, size.height, const Color(0xFF6C5CE7));
  }

  void _drawLine(Canvas canvas, List<int> values, double dx, int minVal, double range, double height, Color color) {
    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final x = dx * i;
      final y = height - ((values[i] - minVal) / range * height);
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = color);
      canvas.drawCircle(p, 2, Paint()..color = Colors.white);
    }

    // Value labels
    for (int i = 0; i < points.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: '${values[i]}', style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 8, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, points[i].dy - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════
class BpResult {
  final String category;
  final String categoryHi;
  final Color color;
  final IconData icon;
  final String message;
  final String messageHi;
  final double severity;
  final List<String> tips;

  BpResult({
    required this.category,
    required this.categoryHi,
    required this.color,
    required this.icon,
    required this.message,
    required this.messageHi,
    required this.severity,
    required this.tips,
  });
}

class BpRecord {
  final int systolic;
  final int diastolic;
  final int? pulse;
  final String category;
  final DateTime date;
  final String? timeOfDay;
  final String? notes;

  BpRecord({
    required this.systolic,
    required this.diastolic,
    this.pulse,
    required this.category,
    required this.date,
    this.timeOfDay,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': pulse,
        'category': category,
        'date': date.toIso8601String(),
        'timeOfDay': timeOfDay,
        'notes': notes,
      };

  factory BpRecord.fromJson(Map<String, dynamic> json) => BpRecord(
        systolic: json['systolic'] as int,
        diastolic: json['diastolic'] as int,
        pulse: json['pulse'] as int?,
        category: json['category'] as String,
        date: DateTime.parse(json['date'] as String),
        timeOfDay: json['timeOfDay'] as String?,
        notes: json['notes'] as String?,
      );
}
