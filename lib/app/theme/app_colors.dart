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

  /// Ana sayfa zemini — sıcak krem, referans paletten App background.
  /// Color Foundation Sprint: #FFF8ED → #FAF3EA.
  static const Color background = Color(0xFFFAF3EA);

  /// İkincil yüzey — bottom nav, input fill, header'ın altındaki strip.
  /// Background'tan hafif daha açık, hiyerarşi için (warm white altı).
  /// Color Foundation Sprint: #F6EFE3 → #FCF7F1.
  static const Color surface = Color(0xFFFCF7F1);

  /// Standart kart + post card → sıcak beyaz.
  /// Referans tasarımdaki ana kart hissini buradan alıyor.
  /// Color Foundation Sprint: #FAF2E6 → #FEFAF4.
  static const Color card = Color(0xFFFEFAF4);

  /// Vurgu kartı — hero/featured tile için; ana feed post kartında
  /// kullanılmaz (user kararı: post kartları sıcak beyaz kalmalı).
  /// Color Foundation Sprint: #F3E6D3 → #FCF7F1 (surface ile aynı ton,
  /// card'tan bir adım daha doygun ama "kum/bej blok" değil).
  static const Color elevatedCard = Color(0xFFFCF7F1);

  /// Cream zemin üstündeki ince divider.
  /// Color Foundation Sprint: #E6D5BA → #E3D2BF (warm border).
  static const Color surfaceLine = Color(0xFFE3D2BF);

  /// Dialog / bottom sheet / snackbar zemini — ana kartlardan ayrı,
  /// soft wheat halo hissi.
  /// Color Foundation Sprint: #EFE0C8 → #F8EDD8.
  static const Color overlay = Color(0xFFF8EDD8);

  /// Açık kart/zemin üzerinde ince hairline border — warm border.
  /// Color Foundation Sprint: #DFC9A8 → #E3D2BF.
  static const Color borderHairline = Color(0xFFE3D2BF);

  /// Geriye dönük uyum için alias — borderHairline ile aynı.
  /// (Bir önceki temadan kalan referansları kırmamak için.)
  static const Color borderLight = Color(0xFFE3D2BF);

  // ─────────────────────────────────────────────────────────────
  // Hero gradient — soft wheat ramp; dekoratif/halo (ana yüzey değil)
  // ─────────────────────────────────────────────────────────────

  /// Color Foundation Sprint: hero gradient artık soft wheat (#F2DFC8)
  /// → overlay (#F8EDD8) çizgisinde. Soft wheat sadece bu dekoratif
  /// alanlarda yaşar; ana feed post kartı değil.
  static const Color heroFrom = Color(0xFFF2DFC8);
  static const Color heroTo = Color(0xFFF8EDD8);

  // ─────────────────────────────────────────────────────────────
  // Vurgular — yumuşak amber paleti
  //   copper      → ana amber (button bg, indicator)
  //   softGold    → deep amber (text/icon emphasis on light)
  //   copperMuted → light amber (yumuşak halo, decoration)
  // ─────────────────────────────────────────────────────────────

  /// Ana vurgu — copper accent. Buton zemini, aktif indicator, focused
  /// border. Color Foundation Sprint: #D6A13A → #C08F63.
  static const Color copper = Color(0xFFC08F63);

  /// Brand brown — vurgu metin/ikon. Light kart üstünde yüksek kontrast.
  /// "softGold" ismi widget'lar arasında 100+ yerde — değeri değişti
  /// ama semantik "vurgu" rolü korunuyor (rename ileride).
  /// Color Foundation Sprint: #B98224 → #724522.
  static const Color softGold = Color(0xFF724522);

  /// Light copper — sıcak halo, gradient companion, decoration only.
  /// Color Foundation Sprint: #E8BF63 → #D6B08C (copper'ın açık varyantı).
  static const Color copperMuted = Color(0xFFD6B08C);

  /// Çok seyrek kullanım — koyu kahve aksent (badge bg, dolu ikon vurgusu).
  static const Color darkAccent = Color(0xFF3A2618);

  /// Daha derin koyu kahve aksent — chip/avatar gibi ufak vurgular için.
  static const Color darkAccentDeeper = Color(0xFF4A3020);

  // ─────────────────────────────────────────────────────────────
  // Tipografi — TÜM YÜZEYLER AÇIK, dark coffee text her yerde
  // ─────────────────────────────────────────────────────────────

  /// Ana metin — espresso, saf siyah değil. Tüm açık yüzeylerde okunur.
  /// Color Foundation Sprint: #2B1D14 → #221A13.
  static const Color textPrimary = Color(0xFF221A13);

  /// İkincil metin — espresso ile muted arasında brand brown ailesinde
  /// doğal ara ton. Color Foundation Sprint: #7A6857 → #5C4838.
  static const Color textSecondary = Color(0xFF5C4838);

  /// Muted etiket / placeholder.
  /// Color Foundation Sprint: #9C8973 → #8E7864.
  static const Color textMuted = Color(0xFF8E7864);

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
