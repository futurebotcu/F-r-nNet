import 'package:flutter/foundation.dart';

/// "Anlaşmalı iş yeri olmak istiyorum" başvuru taslağı.
///
/// requester_id BURADA YOKTUR — server-side auth.uid() ile set edilir
/// (create_partner_business_application RPC'si); client'tan kimlik alınmaz.
@immutable
class PartnerBusinessApplicationDraft {
  const PartnerBusinessApplicationDraft({
    required this.businessName,
    required this.contactName,
    required this.phone,
    required this.city,
    required this.district,
    required this.category,
    this.email = '',
    this.message = '',
  });

  final String businessName;
  final String contactName;
  final String phone;
  final String city;
  final String district;
  final String category;
  final String email;
  final String message;

  /// Zorunlu alanlar dolu mu? (Client validasyonu UX içindir; asıl denetim
  /// RPC'de tekrarlanır.)
  bool get isValid =>
      businessName.trim().isNotEmpty &&
      contactName.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      district.trim().isNotEmpty &&
      category.trim().isNotEmpty;
}
