// B2B Pazar — ürün modeli (mock preview).
//
// Genel B2B ürün pazarındaki bir tedarikçi ürünü. Fiyat tek tip: "Teklif al"
// (bu sprintte sabit fiyat / sepet / satın al YOK). Sahiplik [isMine] ile
// mock işaretlenir → "Benim ürünüm" rozeti.
class B2bProduct {
  const B2bProduct({
    required this.id,
    required this.name,
    required this.supplierId,
    required this.supplierName,
    required this.category,
    required this.minOrder,
    required this.deliveryRegion,
    this.priceType = 'Teklif al',
    this.isMine = false,
  });

  final String id;
  final String name;
  final String supplierId;
  final String supplierName;
  final String category;

  /// Minimum sipariş — serbest metin (ör. "50 çuval", "200 kg").
  final String minOrder;

  /// Teslimat bölgesi — serbest metin (ör. "Marmara", "Tüm Türkiye").
  final String deliveryRegion;

  /// Fiyat tipi etiketi. Mock'ta daima "Teklif al".
  final String priceType;

  /// Preview tedarikçinin kendi ürünü mü (mock sahiplik).
  final bool isMine;
}
