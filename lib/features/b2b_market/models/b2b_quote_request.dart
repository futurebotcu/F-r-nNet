// B2B Pazar — teklif talebi modeli (mock preview).
//
// ÖNEMLİ — ANONİMLİK: Teklif Ağı tedarikçiye alıcının kimliğini AÇMAZ.
// Bu modelde işletme adı, telefon, açık adres, kişi adı ALANI YOKTUR ve
// hiçbir UI yüzeyinde gösterilmez. Yalnız ürün/kategori, miktar, il/ilçe,
// alıcı tipi, teslimat zamanı, kısa not ve durum paylaşılır.

/// Teklif talebi durumu.
enum B2bQuoteStatus { waiting, replied, closed }

extension B2bQuoteStatusX on B2bQuoteStatus {
  String get label {
    switch (this) {
      case B2bQuoteStatus.waiting:
        return 'Bekliyor';
      case B2bQuoteStatus.replied:
        return 'Cevap geldi';
      case B2bQuoteStatus.closed:
        return 'Kapandı';
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

  B2bQuoteRequest copyWith({int? replyCount, B2bQuoteStatus? status}) {
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
    );
  }
}
