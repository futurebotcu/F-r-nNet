import 'package:flutter/widgets.dart';

import '../../../profile/models/bakery_profile.dart';
import 'calculator_category.dart';
import 'calculator_role_visibility.dart';

/// Hesaplama merkezindeki tek bir araç (modül) tanımı.
///
/// Saf veri — matematik içermez, UI içermez. Araçlar
/// [CalculatorToolsRegistry] içinde tek noktada tanımlanır; hub ekranı bu
/// listeyi role göre filtreleyip kart olarak çizer.
@immutable
class CalculatorTool {
  const CalculatorTool({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    this.category = CalculatorCategory.dailyQuick,
    this.visibility = CalculatorRoleVisibility.producers,
    this.enabled = true,
  });

  /// Kararlı, benzersiz kimlik (test / analytics / deep-link için).
  final String id;

  final String title;
  final String description;
  final IconData icon;

  /// Aracın tam ekran route'u (`/calculator/...`).
  final String route;

  /// Hub'da hangi bölümde listeleneceği. Bölüm sırası role göre registry'de
  /// belirlenir; kategori-araç eşlemesi tek noktada burada tutulur.
  final CalculatorCategory category;

  /// Hangi hesap türlerine görünür. Görünürlük kararları ileride
  /// değişebilir; sertleştirme registry'de tek noktada yapılır.
  final CalculatorRoleVisibility visibility;

  /// İleride bir aracı geçici kapatmak için (ör. "yakında"). `false` ise
  /// hub aracı listede göstermez.
  final bool enabled;

  bool isVisibleTo(AccountType type) => visibility.isVisibleTo(type);
}
