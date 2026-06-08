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
/// Beyaz zemin için tek gölge dili: çok düşük opaklıklı saf siyah.
class AppShadow {
  const AppShadow._();

  /// Standart kart gölgesi — açık kartlar arasında hafif yükseliş.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x07000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Yumuşak — modal/sheet için biraz daha derin.
  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 3)),
  ];

  /// Sade — neredeyse görünmez, küçük tile için.
  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Yüksek katman / floating panel için.
  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(color: Color(0x0B000000), blurRadius: 14, offset: Offset(0, 4)),
  ];

  /// Featured/elevated card için aynı nötr gölge dili.
  static List<BoxShadow> copper = [
    const BoxShadow(
      color: Color(0x07000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Hero kartlarda da aynı nötr gölge.
  static List<BoxShadow> heroGlow = const [
    BoxShadow(color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 3)),
  ];
}

class AppDuration {
  const AppDuration._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
}
