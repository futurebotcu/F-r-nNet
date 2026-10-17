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
    this.status = B2bReplyStatus.sent,
    this.createdAt,
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

  /// DB status: sent / accepted / declined. Yalnız b2b_accept_quote_reply
  /// RPC'si değiştirir (sent → accepted/declined). Tedarikçi "Yanıtladıklarım"
  /// kartında durum çipi için.
  final B2bReplyStatus status;

  /// Oluşturulma zamanı (created_at). Mock/yerel veride null.
  final DateTime? createdAt;

  B2bQuoteReply copyWith({bool? accepted, B2bReplyStatus? status}) {
    final acc = accepted ?? this.accepted;
    return B2bQuoteReply(
      id: id,
      requestId: requestId,
      supplierName: supplierName,
      message: message,
      createdAtLabel: createdAtLabel,
      priceHint: priceHint,
      deliveryNote: deliveryNote,
      supplierShopId: supplierShopId,
      accepted: acc,
      // accepted verildiğinde status da tutarlı kalır (yerel repo
      // acceptQuoteReply: seçilen accepted, diğerleri declined).
      status:
          status ??
          (accepted == null
              ? this.status
              : (acc ? B2bReplyStatus.accepted : B2bReplyStatus.declined)),
      createdAt: createdAt,
    );
  }
}

/// Teklif cevabı durumu (DB CHECK: sent / accepted / declined).
enum B2bReplyStatus { sent, accepted, declined }

extension B2bReplyStatusX on B2bReplyStatus {
  static B2bReplyStatus fromText(String? s) {
    switch (s) {
      case 'accepted':
        return B2bReplyStatus.accepted;
      case 'declined':
        return B2bReplyStatus.declined;
      default:
        return B2bReplyStatus.sent;
    }
  }
}
