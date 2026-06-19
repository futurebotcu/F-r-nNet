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
    this.deliveryNote,
    this.supplierShopId,
    this.accepted = false,
  });

  final String id;
  final String requestId;
  final String supplierName;

  /// Cevaplayan tedarikçi mağaza id'si (alıcı → "Mağazayı gör"). Opsiyonel.
  final String? supplierShopId;
  final String message;

  /// İnsan-okur tarih etiketi (ör. "2 saat önce"). Mock sabit string.
  final String createdAtLabel;

  /// Opsiyonel fiyat ipucu (ör. "≈ ₺640 / çuval").
  final String? priceHint;

  /// Opsiyonel teslimat notu (ör. "Bu hafta teslim").
  final String? deliveryNote;

  /// Alıcı bu teklifi seçti mi ("Bu teklifle ilerle").
  final bool accepted;

  B2bQuoteReply copyWith({bool? accepted}) {
    return B2bQuoteReply(
      id: id,
      requestId: requestId,
      supplierName: supplierName,
      message: message,
      createdAtLabel: createdAtLabel,
      priceHint: priceHint,
      deliveryNote: deliveryNote,
      supplierShopId: supplierShopId,
      accepted: accepted ?? this.accepted,
    );
  }
}
