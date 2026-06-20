import 'package:flutter/material.dart';

/// Refreshed palette — WhatsApp-inspired dark + vibrant accents.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0B141A);
  static const Color surface = Color(0xFF111B21);
  static const Color surfaceLight = Color(0xFF1F2C34);
  static const Color card = Color(0xFF182229);

  static const Color primaryCyan = Color(0xFF00A884);
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color primaryBlue = Color(0xFF53BDEB);

  static const Color whatsAppGreen = Color(0xFF00A884);
  static const Color whatsAppSentBubble = Color(0xFF005C4B);
  static const Color whatsAppReceivedBubble = Color(0xFF1F2C34);
  static const Color whatsAppChatBg = Color(0xFF0B141A);

  static const Color accentPink = Color(0xFFFF6B9D);
  static const Color accentOrange = Color(0xFFFF9F43);
  static const Color accentYellow = Color(0xFFFFD93D);

  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFAB40);
  static const Color info = Color(0xFF448AFF);

  // Vault advanced gradient
  static const LinearGradient vaultAdvancedGradient = LinearGradient(
    colors: [Color(0xFFFF6B9D), Color(0xFFFF9F43), Color(0xFFFFD93D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Reels gradient
  static const LinearGradient reelsGradient = LinearGradient(
    colors: [Color(0xFFE040FB), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color textPrimary = Color(0xFFE9EDEF);
  static const Color textSecondary = Color(0xFF8696A0);
  static const Color textHint = Color(0xFF667781);

  static Color glassWhite = Colors.white.withValues(alpha: 0.06);
  static Color glassBorder = Colors.white.withValues(alpha: 0.08);
  static Color glassHighlight = Colors.white.withValues(alpha: 0.12);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00A884), Color(0xFF25D366)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sendGradient = LinearGradient(
    colors: [Color(0xFF00A884), Color(0xFF128C7E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient receiveGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF00D4FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00A884)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient vaultGradient = LinearGradient(
    colors: [Color(0xFFFF6B9D), Color(0xFFFF9F43)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0B141A), Color(0xFF111B21)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
