// B2B Pazar — teklif cevabı modeli (mock preview).
//
// Bir tedarikçinin bir teklif talebine verdiği cevap. Mock: alıcı tarafında
// "Tekliflerim" altında cevap geldiğinde özet gösterilir. Tedarikçi kimliği
// burada görünür (cevabı veren taraf kendini açar); alıcı kimliği ASLA açılmaz.
class B2bQuoteReply {
  const B2bQuoteReply({
    required this.id,
    required this.requestId,
    required this.supplierName,
    required this.message,
    required this.createdAtLabel,
    this.priceHint,
  });

  final String id;
  final String requestId;
  final String supplierName;
  final String message;

  /// İnsan-okur tarih etiketi (ör. "2 saat önce"). Mock sabit string.
  final String createdAtLabel;

  /// Opsiyonel fiyat ipucu (ör. "≈ ₺640 / çuval").
  final String? priceHint;
}
