import 'package:flutter/material.dart';

/// FırınNet renk paleti — açık, sıcak, samimi bir fırıncı uygulaması.
///
/// Tasarım kararı:
///   • Ekranın büyük kısmı açık krem/bej tonlarında.
///   • Kartlar açık ve sade; ağır gradient ve koyu blok yok.
///   • Koyu kahve sadece ufak vurgu: başlık, ikon, seçili durum.
///   • Ana aksent yumuşak amber — agresif turuncu değil.
///
/// Dağılım: %75 açık krem · %20 sıcak destekleyici · %5 koyu vurgu.
///
/// Tüm yüzeyler "açık" olduğu için artık iki bağlamlı renk sistemine
/// gerek yok: `textPrimary` ve `onBackgroundPrimary` aynı dark coffee
/// değerini taşıyor — kart içinde ve zeminde aynı okunabilirlik.
class AppColors {
  const AppColors._();

  // ─────────────────────────────────────────────────────────────
  // Yüzey hiyerarşisi — açık, sıcak, krem dominant
  // ─────────────────────────────────────────────────────────────

  /// Ana sayfa zemini — en açık, sıcak un beji.
  static const Color background = Color(0xFFFFF8ED);

  /// İkincil yüzey — bottom nav, input fill, header'ın altındaki strip.
  /// Background'tan hafif daha doygun, hiyerarşi için.
  static const Color surface = Color(0xFFF6EFE3);

  /// Standart kart — neredeyse background ile aynı, sadece bir nüans
  /// daha derin. Ağır blok hissi vermeden hairline ile ayrılır.
  static const Color card = Color(0xFFFAF2E6);

  /// Vurgu kartı — hero, featured tile, profil header.
  /// Sıcak bej / hafif buğday; hâlâ açık ama "sıcaklığı" yüksek.
  static const Color elevatedCard = Color(0xFFF3E6D3);

  /// Cream zemin üstündeki ince divider.
  static const Color surfaceLine = Color(0xFFE6D5BA);

  /// Dialog / bottom sheet zemini — kart ile tutarlı sıcak ton.
  static const Color overlay = Color(0xFFEFE0C8);

  /// Açık kart/zemin üzerinde ince hairline border — sıcak kahve.
  static const Color borderHairline = Color(0xFFDFC9A8);

  /// Geriye dönük uyum için alias — borderHairline ile aynı.
  /// (Bir önceki temadan kalan referansları kırmamak için.)
  static const Color borderLight = Color(0xFFDFC9A8);

  // ─────────────────────────────────────────────────────────────
  // Hero gradient — yumuşak sıcak ramp, koyu blok değil
  // ─────────────────────────────────────────────────────────────

  static const Color heroFrom = Color(0xFFF3E6D3);
  static const Color heroTo = Color(0xFFEFE0C8);

  // ─────────────────────────────────────────────────────────────
  // Vurgular — yumuşak amber paleti
  //   copper      → ana amber (button bg, indicator)
  //   softGold    → deep amber (text/icon emphasis on light)
  //   copperMuted → light amber (yumuşak halo, decoration)
  // ─────────────────────────────────────────────────────────────

  /// Ana vurgu — yumuşak amber. Buton zemini, aktif indicator, focused border.
  static const Color copper = Color(0xFFD6A13A);

  /// Deep amber — vurgu metin/ikon. Light kart üstünde okunabilir.
  /// "softGold" ismi widget'lar arasında 100+ yerde — değeri değişti
  /// ama semantik "vurgu" rolü korunuyor.
  static const Color softGold = Color(0xFFB98224);

  /// Light amber — sıcak halo, gradient companion, decoration only.
  static const Color copperMuted = Color(0xFFE8BF63);

  /// Çok seyrek kullanım — koyu kahve aksent (badge bg, dolu ikon vurgusu).
  static const Color darkAccent = Color(0xFF3A2618);

  /// Daha derin koyu kahve aksent — chip/avatar gibi ufak vurgular için.
  static const Color darkAccentDeeper = Color(0xFF4A3020);

  // ─────────────────────────────────────────────────────────────
  // Tipografi — TÜM YÜZEYLER AÇIK, dark coffee text her yerde
  // ─────────────────────────────────────────────────────────────

  /// Ana metin — koyu kahve, saf siyah değil. Tüm açık yüzeylerde okunur.
  static const Color textPrimary = Color(0xFF2B1D14);

  /// İkincil metin — muted koyu kahve.
  static const Color textSecondary = Color(0xFF7A6857);

  /// Muted etiket / placeholder.
  static const Color textMuted = Color(0xFF9C8973);

  /// Alias — `onBackgroundPrimary/Secondary/Muted` semantiği iki-bağlamlı
  /// önceki tema için tutuluyordu; tek bağlam (light) olunca aynı değer.
  /// section_label.dart ve firinnet_header.dart bu isimleri kullanıyor —
  /// değiştirmek zorunda kalmamak için alias.
  static const Color onBackgroundPrimary = textPrimary;
  static const Color onBackgroundSecondary = textSecondary;
  static const Color onBackgroundMuted = textMuted;

  // ─────────────────────────────────────────────────────────────
  // Durum — doğal, doygunluğu düşük (neon değil)
  // ─────────────────────────────────────────────────────────────

  /// Başarı — toprak yeşili.
  static const Color success = Color(0xFF4F7D3A);

  /// Uyarı — sıcak amber (status için, ana aksentten ayrı).
  static const Color warning = Color(0xFFD9A441);

  /// Hata — toprak kızılı.
  static const Color danger = Color(0xFFB84A35);

  /// İpucu / bilgi — mat çelik.
  static const Color info = Color(0xFF6E7F8A);
}
