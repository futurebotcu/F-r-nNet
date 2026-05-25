import 'package:flutter/material.dart';

import 'app_colors.dart';

/// FırınNet tipografi skalası — Visual North Star Sprint 1A.
///
/// Mevcut Material `TextTheme` yan yana yaşar; bu sınıf domain-spesifik
/// roller için açık skala sağlar. Kademeli rollout: Sprint 1A'da yalnız
/// `TagChip` kullanır; diğer ekranlar mevcut style ile devam eder.
///
/// **Önemli**: Sprint 1A'da broad rollout YOK. Sprint 1B/2'de post card
/// caption, comments preview, type badge, profile header gibi yerler
/// kademeli olarak bu skalaya alınır.
class AppTypography {
  const AppTypography._();

  // ── Display ─────────────────────────────────────────────────────────
  // Onboarding hero, brand splash; ekranda 1-2 satır gerektiren büyük
  // başlık için.

  static const TextStyle displayLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.15,
  );

  static const TextStyle displayMedium = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.2,
  );

  // ── Headline ────────────────────────────────────────────────────────
  // Emphasized KPI, section büyük başlık.

  static const TextStyle headlineSmall = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.25,
  );

  // ── Title ───────────────────────────────────────────────────────────
  // Post header, list başlık.

  static const TextStyle titleLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.15,
    height: 1.35,
  );

  // ── Body ────────────────────────────────────────────────────────────
  // Uzun metin (post caption), genel okuma.

  static const TextStyle bodyLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15.5,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    color: AppColors.textMuted,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  // ── Label ───────────────────────────────────────────────────────────
  // Chip, badge, section etiketi.

  static const TextStyle labelLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  static const TextStyle labelSmall = TextStyle(
    color: AppColors.textMuted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
}
