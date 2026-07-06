import '../models/partner_business.dart';
import '../models/partner_business_application.dart';

/// Anlaşmalı İş Yerleri repo sözleşmesi.
///
/// Dizin salt-okunur (yazma yalnız backoffice). Başvuru tek yazma yoludur ve
/// güvenlik server'dadır (SECURITY DEFINER RPC — requester_id = auth.uid(),
/// 5/saat rate limit). Destek maili BEST-EFFORT'tur: gönderilemese de
/// başvuru başarılı sayılır (kullanıcı hata GÖRMEZ).
abstract class PartnerBusinessRepository {
  /// Aktif anlaşmalı iş yerleri (sort_order + ad sıralı, ilk [limit]).
  Future<List<PartnerBusiness>> activePartners({int limit = 50});

  Future<PartnerBusiness?> partnerById(String id);

  /// Başvuruyu kaydeder, ardından destek mailini best-effort tetikler.
  /// Dönen değer başvuru id'sidir; mail hatası exception ÜRETMEZ.
  Future<String> submitApplication(PartnerBusinessApplicationDraft draft);
}
