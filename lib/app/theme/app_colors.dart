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

  /// Ana sayfa zemini — sıcak ama ferah ivory krem.
  /// Color Tune Sprint: #F7EEDF → #FAF5ED — referansa göre fazla bej/sarı
  /// yoğun duran zemin açıldı; daha açık, ferah ivory. Hâlâ sıcak (mavi-gri
  /// değil) ama "ağır bej blok" hissi gitti, kartlarla ayrım temiz kaldı.
  static const Color background = Color(0xFFFAF5ED);

  /// İkincil yüzey — bottom nav, input fill, header'ın altındaki strip,
  /// stat şeridi, segment track. Zemin ile kart arasında temiz ara ton.
  /// Color Tune Sprint: #FBF4EA → #FCF7F0 (biraz daha açık/temiz ara ton).
  static const Color surface = Color(0xFFFCF7F0);

  /// Standart kart + post card → sıcak beyaz.
  /// Referans tasarımdaki ana kart hissini buradan alıyor. Zemin ısındığı
  /// için kart, ayrışmayı koruyacak şekilde temiz warm-white'a çekildi
  /// (stark beyaz değil; hafif sıcaklık taşır).
  /// Color Polish Sprint: #FEFAF4 → #FFFCF7.
  static const Color card = Color(0xFFFFFCF7);

  /// Vurgu kartı — hero/featured tile (PremiumCard hero tier) için; ana feed
  /// post kartında kullanılmaz. card'tan ayrışan yumuşak wheat lift: "öne
  /// çıkan" hissi verir ama kaba bej blok değil. Zemin açıldığı için bu da
  /// çok sarılaşmadan hafifçe açıldı (yine surface'ten sıcak/derin → distinct).
  /// Color Tune Sprint: #FBF3E7 → #FBF4E9.
  static const Color elevatedCard = Color(0xFFFBF4E9);

  /// Cream zemin üstündeki ince divider — warm, görünür ama bağırmaz.
  /// Color Tune Sprint: #E8D6BE → #ECDEC8 — açılan zeminde ağırlaşmasın diye
  /// hafifçe açıldı; sıcak kaldı, sert/koyu çizgi hissi yok.
  static const Color surfaceLine = Color(0xFFECDEC8);

  /// Dialog / bottom sheet / snackbar zemini — ana kartlardan ayrı,
  /// soft wheat halo hissi. Color Polish Sprint: #F8EDD8 → #F6E9D2.
  static const Color overlay = Color(0xFFF6E9D2);

  /// Açık kart/zemin üzerinde ince hairline border — warm, soğuk-gri değil;
  /// kart kenarı görünür ama zarif. Color Tune Sprint: #E6D4BC → #EBDCC4 —
  /// açılan zeminde ekranı ağırlaştırmasın diye hafifletildi (sıcak kalır).
  static const Color borderHairline = Color(0xFFEBDCC4);

  /// Geriye dönük uyum için alias — borderHairline ile aynı.
  /// (Bir önceki temadan kalan referansları kırmamak için.)
  static const Color borderLight = Color(0xFFEBDCC4);

  // ─────────────────────────────────────────────────────────────
  // Hero gradient — soft wheat ramp; dekoratif/halo (ana yüzey değil)
  // ─────────────────────────────────────────────────────────────

  /// Hero gradient soft wheat (#F2DFC8) → overlay çizgisinde. Soft wheat
  /// sadece bu dekoratif alanlarda yaşar; ana feed post kartı değil.
  /// Color Polish Sprint: heroTo overlay ile hizalandı (#F8EDD8 → #F6E9D2).
  static const Color heroFrom = Color(0xFFF2DFC8);
  static const Color heroTo = Color(0xFFF6E9D2);

  // ─────────────────────────────────────────────────────────────
  // Vurgular — yumuşak amber paleti
  //   copper      → ana amber (button bg, indicator)
  //   softGold    → deep amber (text/icon emphasis on light)
  //   copperMuted → light amber (yumuşak halo, decoration)
  // ─────────────────────────────────────────────────────────────

  /// Ana vurgu — copper accent. Primary CTA zemini, aktif indicator, seçili
  /// segment dolgusu, focused border, FAB. Eski #C08F63 soluk/sütlü tan idi
  /// (beyaz yazı kontrastı ~2.8:1, referansa göre cansız). Color Polish
  /// Sprint: zengin, motive edici warm copper'a derinleştirildi → beyaz yazı
  /// kontrastı ~4.7:1 (WCAG AA normal text). Çiğ/neon turuncu değil; referans
  /// görseldeki bakır CTA çizgisinde.
  /// Color Polish Sprint: #C08F63 → #A8632C.
  static const Color copper = Color(0xFFA8632C);

  /// Brand brown — vurgu metin/ikon, seçili chip etiketi, section emphasis.
  /// Light kart üstünde çok yüksek kontrast (deep espresso-amber). copper
  /// ailesinin en koyu ucu; "highlight text" rolü. Değer korundu.
  static const Color softGold = Color(0xFF724522);

  /// Light copper — sıcak halo, gradient companion, decoration only.
  /// Zenginleşen copper'a eşlik edecek şekilde hafif doygunlaştırıldı.
  /// Color Polish Sprint: #D6B08C → #D7AC83.
  static const Color copperMuted = Color(0xFFD7AC83);

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

  /// Muted etiket / placeholder / meta. Krem zemin üstünde fazla silik
  /// kalmaması için bir tık güçlendirildi (yine de zarif, baskın değil).
  /// Color Polish Sprint: #8E7864 → #8A7058.
  static const Color textMuted = Color(0xFF8A7058);

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

  // ─────────────────────────────────────────────────────────────
  // Medya scrim — görsel/foto üstünde metin/ikon okunabilirliği
  // ─────────────────────────────────────────────────────────────

  /// Kart/medya görseli üstündeki badge & ikonlar için koyu yarı saydam
  /// scrim (~%55). Color Polish Sprint: saf siyah yerine sıcak espresso
  /// tonlu (#221A13) — soğuk/çiğ siyah overlay yerine premium, palette
  /// uyumlu karartma. Okunabilirlik korunur.
  static const Color imageScrimDark = Color(0x8C221A13);

  /// Daha hafif scrim (~%35) — küçük yuvarlak aksiyon arkalığı için.
  /// Aynı sıcak espresso tonu, düşük alpha.
  static const Color imageScrimSoft = Color(0x59221A13);
}
