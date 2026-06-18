// B2B Pazar — lead (ilgi) modeli.
//
// Alıcı, bir teklif cevabına "İlgileniyorum" veya "Uygun değil" der → lead.
// Telefon YALNIZ alıcı açık onay verirse (phoneShared) paylaşılır; aksi halde
// sharedPhone null. Lead, ilgili tedarikçi mağazasıyla bağ kurar; alıcı kimliği
// (ad/açık adres) yine paylaşılmaz — yalnız alıcının yazdığı mesaj + (onaylıysa)
// telefon görünür.

enum B2bLeadStatus { interested, rejected }

extension B2bLeadStatusX on B2bLeadStatus {
  String get dbValue =>
      this == B2bLeadStatus.interested ? 'interested' : 'rejected';

  static B2bLeadStatus fromText(String? s) =>
      s == 'rejected' ? B2bLeadStatus.rejected : B2bLeadStatus.interested;
}

class B2bQuoteLead {
  const B2bQuoteLead({
    required this.id,
    required this.quoteRequestId,
    required this.quoteReplyId,
    required this.supplierShopId,
    required this.status,
    this.supplierName = '',
    this.buyerMessage,
    this.phoneShared = false,
    this.sharedPhone,
    this.createdAtLabel = '',
    // Tedarikçi "İlgilenenler" kartı için talep özeti (opsiyonel).
    this.requestCategory = '',
    this.requestQuantity = '',
    this.requestCity = '',
    this.replyAccepted = false,
  });

  final String id;
  final String quoteRequestId;
  final String quoteReplyId;
  final String supplierShopId;
  final B2bLeadStatus status;

  /// Alıcı tarafı: ilgilenilen teklifin mağaza adı.
  final String supplierName;

  final String? buyerMessage;
  final bool phoneShared;

  /// Yalnız [phoneShared] true ise dolu; aksi halde null.
  final String? sharedPhone;

  final String createdAtLabel;

  // Tedarikçi tarafı talep özeti.
  final String requestCategory;
  final String requestQuantity;
  final String requestCity;

  /// İlgilenilen teklif alıcı tarafından seçildi mi ("Teklifin seçildi").
  final bool replyAccepted;

  bool get isInterested => status == B2bLeadStatus.interested;
  bool get isRejected => status == B2bLeadStatus.rejected;

  B2bQuoteLead copyWith({bool? replyAccepted}) {
    return B2bQuoteLead(
      id: id,
      quoteRequestId: quoteRequestId,
      quoteReplyId: quoteReplyId,
      supplierShopId: supplierShopId,
      status: status,
      supplierName: supplierName,
      buyerMessage: buyerMessage,
      phoneShared: phoneShared,
      sharedPhone: sharedPhone,
      createdAtLabel: createdAtLabel,
      requestCategory: requestCategory,
      requestQuantity: requestQuantity,
      requestCity: requestCity,
      replyAccepted: replyAccepted ?? this.replyAccepted,
    );
  }
}
