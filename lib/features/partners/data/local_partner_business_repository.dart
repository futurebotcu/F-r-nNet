import '../models/partner_business.dart';
import '../models/partner_business_application.dart';
import 'partner_business_repository.dart';

/// In-memory Anlaşmalı İş Yerleri reposu — testler ve Supabase kapalı
/// geliştirme için. Server kurallarının davranışsal aynası: yalnız aktif
/// kayıtlar listelenir, zorunlu alanlar reddedilir, mail hatası başvuruyu
/// bozmaz ([failMail] ile simüle edilir).
class LocalPartnerBusinessRepository implements PartnerBusinessRepository {
  LocalPartnerBusinessRepository({bool seed = false}) {
    if (seed) _seed();
  }

  final List<PartnerBusiness> partners = [];
  final List<PartnerBusinessApplicationDraft> submittedApplications = [];

  /// Aktif olmayan kayıtlar (RLS aynası: hiç dönmezler).
  final List<PartnerBusiness> inactivePartners = [];

  /// true → mail bildirimi başarısız olur; başvuru YİNE başarılı kalmalı.
  bool failMail = false;

  /// Mail bildirimi kaç kez denendi (testler için).
  int mailAttempts = 0;

  int _idSeq = 0;

  void _seed() {
    partners.addAll(const [
      PartnerBusiness(
        id: 'partner-1',
        name: 'Fırın Makina Servis',
        category: 'Teknik servis',
        city: 'Ankara',
        district: 'Çankaya',
        address: 'Sanayi Cad. No:12',
        phone: '0312 111 11 11',
        benefitSummary: 'FırınNet üyelerine bakımda %15 indirim',
        description: 'Fırın ve unlu mamul ekipmanlarında yetkili servis.',
        mapUrl: 'https://maps.example.com/firin-makina',
      ),
      PartnerBusiness(
        id: 'partner-2',
        name: 'Un Deposu Toptan',
        category: 'Hammadde / tedarik',
        city: 'Ankara',
        district: 'Keçiören',
        phone: '0312 222 22 22',
        benefitSummary: 'İlk siparişte kargo bizden',
        websiteUrl: 'https://undeposu.example.com',
      ),
      PartnerBusiness(
        id: 'partner-3',
        name: 'Marmara Ambalaj',
        category: 'Paketleme',
        city: 'İstanbul',
        district: 'Bayrampaşa',
        benefitSummary: 'Toplu alımda özel fiyat',
      ),
    ]);
    inactivePartners.add(
      const PartnerBusiness(
        id: 'partner-passive',
        name: 'Pasif İş Yeri',
        category: 'Lojistik',
        city: 'Ankara',
        district: 'Çankaya',
      ),
    );
  }

  @override
  Future<List<PartnerBusiness>> activePartners({int limit = 50}) async {
    final sorted = List.of(partners)
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });
    return sorted.take(limit).toList(growable: false);
  }

  @override
  Future<PartnerBusiness?> partnerById(String id) async {
    for (final p in partners) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<String> submitApplication(
    PartnerBusinessApplicationDraft draft,
  ) async {
    // Server-side validasyonun aynası.
    if (!draft.isValid) throw StateError('Başvuru gönderilemedi. Tekrar dene.');
    submittedApplications.add(draft);
    final id = 'application-${++_idSeq}';
    // Mail best-effort: başarısızlık başvuruyu GERİ ALMAZ.
    mailAttempts++;
    if (failMail) {
      // sessizce yut (Supabase reposundaki catch'in aynası).
    }
    return id;
  }
}
