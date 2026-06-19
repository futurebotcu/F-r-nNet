// B2B Pazar — teklif talebi modeli (mock preview).
//
// ÖNEMLİ — ANONİMLİK: Teklif Ağı tedarikçiye alıcının kimliğini AÇMAZ.
// Bu modelde işletme adı, telefon, açık adres, kişi adı ALANI YOKTUR ve
// hiçbir UI yüzeyinde gösterilmez. Yalnız ürün/kategori, miktar, il/ilçe,
// alıcı tipi, teslimat zamanı, kısa not ve durum paylaşılır.

/// Teklif talebi durumu. DB: open / answered / closed / cancelled.
enum B2bQuoteStatus { waiting, replied, closed, cancelled }

extension B2bQuoteStatusX on B2bQuoteStatus {
  String get label {
    switch (this) {
      case B2bQuoteStatus.waiting:
        return 'Bekliyor';
      case B2bQuoteStatus.replied:
        return 'Teklif geldi';
      case B2bQuoteStatus.closed:
        return 'Kapandı';
      case B2bQuoteStatus.cancelled:
        return 'İptal edildi';
    }
  }

  /// Talep aktif mi (yeni teklif kabul eder / kapatılabilir)?
  bool get isActive =>
      this == B2bQuoteStatus.waiting || this == B2bQuoteStatus.replied;

  /// Talep sonlandırılmış mı (kapalı/iptal)?
  bool get isTerminal =>
      this == B2bQuoteStatus.closed || this == B2bQuoteStatus.cancelled;

  /// DB metni.
  String get dbValue {
    switch (this) {
      case B2bQuoteStatus.waiting:
        return 'open';
      case B2bQuoteStatus.replied:
        return 'answered';
      case B2bQuoteStatus.closed:
        return 'closed';
      case B2bQuoteStatus.cancelled:
        return 'cancelled';
    }
  }
}

class B2bQuoteRequest {
  const B2bQuoteRequest({
    required this.id,
    required this.productOrCategory,
    required this.quantity,
    required this.city,
    required this.district,
    required this.buyerType,
    required this.deliveryTime,
    required this.note,
    required this.status,
    this.replyCount = 0,
    this.createdByMe = false,
    this.acceptedReplyId,
  });

  final String id;

  /// İstenen ürün veya kategori.
  final String productOrCategory;

  /// Talep edilen miktar — serbest metin (ör. "300 çuval").
  final String quantity;

  /// İl (anonim konum — açık adres YOK).
  final String city;

  /// İlçe (anonim konum — açık adres YOK).
  final String district;

  /// Alıcı tipi — kategori düzeyinde (ör. "Fırın", "Pastane"). Kimlik DEĞİL.
  final String buyerType;

  /// Tercih edilen teslimat zamanı — serbest metin.
  final String deliveryTime;

  /// Kısa not.
  final String note;

  final B2bQuoteStatus status;

  /// Bu talebe gelen teklif sayısı (mock).
  final int replyCount;

  /// Preview kullanıcının (alıcı) kendi açtığı talep mi → "Tekliflerim".
  final bool createdByMe;

  /// Alıcının "Bu teklifle ilerle" dediği reply id'si (anlaşma). Yoksa null.
  final String? acceptedReplyId;

  /// Bu talepte seçilmiş bir teklif var mı?
  bool get hasAcceptedReply =>
      acceptedReplyId != null && acceptedReplyId!.isNotEmpty;

  B2bQuoteRequest copyWith({
    int? replyCount,
    B2bQuoteStatus? status,
    String? acceptedReplyId,
  }) {
    return B2bQuoteRequest(
      id: id,
      productOrCategory: productOrCategory,
      quantity: quantity,
      city: city,
      district: district,
      buyerType: buyerType,
      deliveryTime: deliveryTime,
      note: note,
      status: status ?? this.status,
      replyCount: replyCount ?? this.replyCount,
      createdByMe: createdByMe,
      acceptedReplyId: acceptedReplyId ?? this.acceptedReplyId,
    );
  }
}
