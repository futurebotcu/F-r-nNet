import 'package:firin_defter/features/partners/data/local_partner_business_repository.dart';
import 'package:firin_defter/features/partners/models/partner_business.dart';
import 'package:firin_defter/features/partners/models/partner_business_application.dart';
import 'package:flutter_test/flutter_test.dart';

/// Anlaşmalı İş Yerleri V1 — model/filtre + Local repo davranış testleri.
/// Local repo server (RLS/RPC) kurallarının aynasıdır; asıl güvenlik DB'de
/// canlı smoke ile doğrulanmıştır (13/13).
void main() {
  const draft = PartnerBusinessApplicationDraft(
    businessName: 'Test Fırın Ekipman',
    contactName: 'Ali Veli',
    phone: '05001112233',
    city: 'Ankara',
    district: 'Çankaya',
    category: 'Teknik servis',
  );

  group('liste + aktiflik', () {
    test('yalnız aktif partnerlar listelenir', () async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      final list = await repo.activePartners();
      expect(list, hasLength(3));
      expect(list.map((p) => p.id), isNot(contains('partner-passive')));
      // Pasif kayıt detayda da dönmez (liste dışı tutulur).
      expect(await repo.partnerById('partner-passive'), isNull);
      expect(await repo.partnerById('partner-1'), isNotNull);
    });

    test('limit uygulanır', () async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      expect(await repo.activePartners(limit: 2), hasLength(2));
    });
  });

  group('PartnerBusinessFilter — şehir/ilçe/kategori/arama', () {
    late List<PartnerBusiness> all;
    setUp(() async {
      all = await LocalPartnerBusinessRepository(seed: true).activePartners();
    });

    test('şehir filtresi', () {
      final f = const PartnerBusinessFilter(city: 'Ankara');
      expect(f.apply(all), hasLength(2));
      expect(
        const PartnerBusinessFilter(city: 'İstanbul').apply(all),
        hasLength(1),
      );
    });

    test('ilçe filtresi', () {
      final f = const PartnerBusinessFilter(district: 'Keçiören');
      expect(f.apply(all).single.name, 'Un Deposu Toptan');
    });

    test('kategori filtresi', () {
      final f = const PartnerBusinessFilter(category: 'Paketleme');
      expect(f.apply(all).single.name, 'Marmara Ambalaj');
    });

    test('arama: ad + avantaj özeti + şehir üzerinden bulur', () {
      expect(
        const PartnerBusinessFilter(query: 'makina').apply(all).single.id,
        'partner-1',
      );
      expect(
        const PartnerBusinessFilter(query: 'kargo').apply(all).single.id,
        'partner-2',
      );
      expect(
        const PartnerBusinessFilter(query: 'istanbul').apply(all),
        hasLength(1),
      );
      expect(
        const PartnerBusinessFilter(query: 'olmayan-şey').apply(all),
        isEmpty,
      );
    });

    test('seçenekler aktif kayıtlardan türetilir; ilçe şehre bağlı', () {
      // Sıra code-unit tabanlıdır (Türkçe collation V1 kapsamı dışı) —
      // içerik doğruluğu sıra bağımsız doğrulanır.
      expect(PartnerBusinessFilter.cityOptions(all).toSet(), {
        'Ankara',
        'İstanbul',
      });
      expect(
        PartnerBusinessFilter.districtOptions(all, city: 'Ankara').toSet(),
        {'Çankaya', 'Keçiören'},
      );
      expect(
        PartnerBusinessFilter.categoryOptions(all),
        containsAll(['Teknik servis', 'Paketleme']),
      );
    });
  });

  group('başvuru (create_partner_business_application aynası)', () {
    test('geçerli başvuru kaydolur', () async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      final id = await repo.submitApplication(draft);
      expect(id, isNotEmpty);
      expect(repo.submittedApplications, hasLength(1));
      expect(
        repo.submittedApplications.single.businessName,
        'Test Fırın Ekipman',
      );
    });

    test('zorunlu alan eksikse reddedilir (server aynası)', () async {
      final repo = LocalPartnerBusinessRepository(seed: true);
      expect(
        () => repo.submitApplication(
          const PartnerBusinessApplicationDraft(
            businessName: '',
            contactName: 'X',
            phone: '05001112233',
            city: 'Ankara',
            district: 'Çankaya',
            category: 'Lojistik',
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(repo.submittedApplications, isEmpty);
    });

    test('mail gönderimi başarısız olsa da başvuru başarılı kalır', () async {
      final repo = LocalPartnerBusinessRepository(seed: true)..failMail = true;
      final id = await repo.submitApplication(draft);
      expect(id, isNotEmpty);
      expect(repo.submittedApplications, hasLength(1));
      expect(repo.mailAttempts, 1);
    });
  });
}
