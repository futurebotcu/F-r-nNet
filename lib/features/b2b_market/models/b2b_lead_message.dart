// B2B Pazar — lead takip mesajı modeli.
//
// Genel chat DEĞİL: yalnız ilgili lead bağlamında, alıcı ↔ tedarikçi arasında
// kısa takip mesajları. Telefon/kişisel bilgi otomatik eklenmez. Gönderen rolü
// (buyer/supplier) sunucuda lead üyeliğinden türetilir (UI'dan güvenilmez).

enum B2bLeadSenderRole { buyer, supplier }

extension B2bLeadSenderRoleX on B2bLeadSenderRole {
  static B2bLeadSenderRole fromText(String? s) =>
      s == 'supplier' ? B2bLeadSenderRole.supplier : B2bLeadSenderRole.buyer;
}

class B2bLeadMessage {
  const B2bLeadMessage({
    required this.id,
    required this.leadId,
    required this.senderRole,
    required this.message,
    this.createdAtLabel = '',
  });

  final String id;
  final String leadId;
  final B2bLeadSenderRole senderRole;
  final String message;
  final String createdAtLabel;

  bool get isBuyer => senderRole == B2bLeadSenderRole.buyer;
  bool get isSupplier => senderRole == B2bLeadSenderRole.supplier;
}
