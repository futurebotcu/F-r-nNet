// B2B Pazar — kampanya modeli (mock preview).
//
// Sosyal post DEĞİL: ticari fırsat kartı. Tedarikçinin bir ürün/kategori
// için açtığı toplu alım fırsatı. Sahiplik [isMine] ile mock işaretlenir →
// "Benim kampanyam" rozeti.
class B2bCampaign {
  const B2bCampaign({
    required this.id,
    required this.title,
    required this.supplierId,
    required this.supplierName,
    required this.category,
    required this.region,
    required this.minPurchase,
    required this.validUntil,
    this.linkedProduct,
    this.isMine = false,
  });

  final String id;
  final String title;
  final String supplierId;
  final String supplierName;
  final String category;

  /// Kampanyanın geçerli olduğu bölge.
  final String region;

  /// Minimum alım koşulu — serbest metin (ör. "100 çuval ve üzeri").
  final String minPurchase;

  /// Geçerlilik tarihi — serbest metin (ör. "30 Haziran 2026").
  final String validUntil;

  /// Bağlı ürün adı (opsiyonel).
  final String? linkedProduct;

  /// Preview tedarikçinin kendi kampanyası mı (mock sahiplik).
  final bool isMine;
}
