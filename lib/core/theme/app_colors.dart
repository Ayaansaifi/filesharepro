import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Base Dark Theme ─────────────────────────────────────
  static const Color background = Color(0xFF0A0E21);
  static const Color surface = Color(0xFF1A1F38);
  static const Color surfaceLight = Color(0xFF242A45);
  static const Color card = Color(0xFF1E2340);

  // ─── Primary Gradient ────────────────────────────────────
  static const Color primaryCyan = Color(0xFF00D4FF);
  static const Color primaryPurple = Color(0xFF7B2FFF);
  static const Color primaryBlue = Color(0xFF4A6CF7);

  // ─── Secondary Accent ────────────────────────────────────
  static const Color accentPink = Color(0xFFFF6B9D);
  static const Color accentOrange = Color(0xFFFF8A50);

  // ─── Semantic Colors ─────────────────────────────────────
  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFAB40);
  static const Color info = Color(0xFF448AFF);

  // ─── Text Colors ─────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8B95A5);
  static const Color textHint = Color(0xFF5A6478);

  // ─── Glass Effect ────────────────────────────────────────
  static Color glassWhite = Colors.white.withValues(alpha: 0.05);
  static Color glassBorder = Colors.white.withValues(alpha: 0.1);
  static Color glassHighlight = Colors.white.withValues(alpha: 0.15);

  // ─── Gradients ───────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sendGradient = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF4A6CF7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient receiveGradient = LinearGradient(
    colors: [Color(0xFF7B2FFF), Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient vaultGradient = LinearGradient(
    colors: [Color(0xFFFF6B9D), Color(0xFFFF8A50)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, Color(0xFF0F1630)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
