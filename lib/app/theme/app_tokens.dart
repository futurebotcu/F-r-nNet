import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Boşluk skalası — editorial ritim için 4px tabanlı.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Sayfa kenar boşluğu — geniş, sakin.
  static const double pageH = 20;
  static const double pageV = 16;
}

/// Köşe yarıçapları — yumuşak ama yorgun değil.
class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double s = 12;
  static const double m = 16;
  static const double l = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Gölge / yükseltme katmanları.
///
/// Cream zemin üstünde "premium drop shadow" hissini kaldırmak için
/// shadow renkleri saf siyah yerine sıcak espresso tonunda tutuldu;
/// alpha değerleri düşürüldü. Mat, doğal, parlamasız bir yükseliş.
class AppShadow {
  const AppShadow._();

  /// Standart kart gölgesi — açık kartlar arasında hafif yükseliş.
  /// Sıcak kahve tonu, çok düşük alpha — krem zeminde belli belirsiz.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F221A13),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Yumuşak — modal/sheet için biraz daha derin.
  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(
      color: Color(0x18221A13),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  /// Sade — neredeyse görünmez, küçük tile için.
  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A221A13),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Yüksek katman / floating panel için.
  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A221A13),
      blurRadius: 20,
      offset: Offset(0, 10),
    ),
  ];

  /// Yumuşak amber sızıntı — featured/elevated card için.
  /// Glow değil, sıcak duvar yansıması hissi.
  static List<BoxShadow> copper = [
    BoxShadow(
      color: AppColors.copper.withValues(alpha: 0.16),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  /// Hero kartlarda yumuşak sıcaklık — parlamasız, doğal.
  static List<BoxShadow> heroGlow = const [
    BoxShadow(
      color: Color(0x14221A13),
      blurRadius: 14,
      offset: Offset(0, 8),
    ),
  ];
}

class AppDuration {
  const AppDuration._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
}
