import 'package:flutter/material.dart';

/// FirinNet white-first identity with a premium lemon accent.
///
/// This file is the single source of truth for app colors. Existing legacy
/// names are kept as aliases so screens can move to the new naming gradually
/// without changing layout, icons, or component structure.
class AppColors {
  const AppColors._();

  // Core brand palette
  static const Color brandLemon = Color(0xFFFFE66D);
  static const Color brandLemonSoft = Color(0xFFFFF4B0);
  static const Color brandLemonPale = Color(0xFFFFFCE8);
  static const Color brandLemonPressed = Color(0xFFE6C84A);
  static const Color brandInk = Color(0xFF111827);
  static const Color brandGray = Color(0xFF6B7280);
  static const Color brandMuted = Color(0xFF9CA3AF);
  static const Color softWhite = Color(0xFFFFFEFB);
  static const Color warmBorder = Color(0xFFF2F2F2);

  static const Color primary = brandLemon;
  static const Color accent = brandLemon;

  // Typography
  static const Color textPrimary = brandInk;
  static const Color textSecondary = brandGray;
  static const Color textMuted = brandMuted;

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface70 = Color(0xB3FFFFFF);
  static const Color surface54 = Color(0x8AFFFFFF);
  static const Color surfaceVariant = softWhite;
  static const Color surfaceContainerLowest = surface;
  static const Color surfaceContainerHighest = softWhite;

  // Cards and elevated layers
  static const Color card = surface;
  static const Color elevatedCard = surface;
  static const Color overlay = surface;

  // Lines and borders
  static const Color surfaceLine = Color(0xFFF6F6F6);
  static const Color borderHairline = warmBorder;
  static const Color borderLight = borderHairline;

  // Decorative light surfaces for a clean social network aesthetic
  static const Color heroFrom = surface;
  static const Color heroTo = brandLemonPale;

  // Legacy aliases used across the app
  static const Color brandYellow = brandLemon;
  static const Color brandYellowPressed = brandLemonPressed;
  static const Color copper = brandLemon;
  static const Color softGold = brandInk;
  static const Color copperMuted = brandLemonSoft;
  static const Color darkAccent = brandInk;
  static const Color darkAccentDeeper = brandInk;

  // Semantic colors
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Background text aliases
  static const Color onBackgroundPrimary = textPrimary;
  static const Color onBackgroundSecondary = textSecondary;
  static const Color onBackgroundMuted = textMuted;

  // Media scrims
  static const Color imageScrimDark = Color(0x8C171717);
  static const Color imageScrimSoft = Color(0x59171717);
}
