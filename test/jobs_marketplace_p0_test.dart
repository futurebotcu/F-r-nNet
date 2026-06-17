// V1 P0 — Jobs/Marketplace mock temizliği doğrulama testleri.
//
//   1. MarketplaceScreen kaynak kodu artık hardcoded ürün/satıcı listesi
//      içermiyor (Spiral mikser, Konya Değirmen, ₺ 850.000 vb.).
//   2. JobsScreen kaynak kodu artık hardcoded fırın/usta listesi içermiyor
//      (_bakeriesHiring, _bakersLooking, Konak Fırını, Selin Pastane vb.).
//   3. AppShell._tabs Feed / Gruplar / Market / İlanlar / Panel sırasını
//      barındırır. (P0 cleanup'ta gizlenen Market tab, V1 Market M1+M2
//      gerçek backend tamamlandıktan sonra V Nav-Marketplace-Restore ile
//      bottom nav'da 3. konumda geri eklendi.)
//   4. LocalWorkerRepository.listActiveJobSeekPosts() sadece is_active=true
//      satırları döner, limit'e saygı duyar.
//
// Bu testler refactor'ün gelecekteki bir mock'la geri çekilmesini önler.

import 'dart:io';

import 'package:firin_defter/features/worker/models/job_seek_post.dart';
import 'package:firin_defter/features/worker/repositories/local_worker_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Marketplace mock cleanup (P0)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/marketplace/screens/marketplace_screen.dart')
          .readAsStringSync();
    });

    test('mock ürün listeleri kaldırıldı', () {
      // Eski hardcoded items'tan emin bir-iki unique string seç.
      expect(src.contains('Spiral mikser'), isFalse,
          reason: 'MarketplaceScreen hâlâ mock ekipman ürünü içeriyor');
      expect(src.contains('Konya Değirmen'), isFalse,
          reason: 'MarketplaceScreen hâlâ mock satıcı içeriyor');
      expect(src.contains('₺ 850.000'), isFalse,
          reason: 'MarketplaceScreen hâlâ mock fiyat içeriyor');
      expect(src.contains('Devren Fırın'), isFalse,
          reason: 'MarketplaceScreen hâlâ mock filtre çipi içeriyor');
    });

    test('MarketProductCard render edilmiyor', () {
      expect(src.contains('MarketProductCard'), isFalse,
          reason: 'Marketplace artık mock kart render etmemeli');
    });

    test('Gerçek market_listings provider\'a bağlı (V1 sprint sonrası)', () {
      // Bu test başlangıçta "coming-soon ekran kaldı" idi (P0 mock cleanup).
      // "Gerçek olmayan şeyleri gerçek yap" sprint sonrası coming-soon
      // kaldırıldı; ekran gerçek listing provider'a bağlandı. M2'de
      // filter desteği için `activeMarketListingsProvider` yerine
      // `filteredMarketListingsProvider` kullanılıyor; invariant gerçek
      // bir listing provider + coming-soon mock yok.
      final hasRealProvider =
          src.contains('activeMarketListingsProvider') ||
              src.contains('filteredMarketListingsProvider');
      expect(hasRealProvider, isTrue,
          reason:
              'Marketplace artık gerçek `market_listings` provider\'a bağlı olmalı');
      expect(src.contains('marketComingSoonTitle'), isFalse,
          reason: 'Eski coming-soon kart kaldırılmalı');
    });
  });

  group('Jobs mock cleanup (P0)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/jobs/screens/jobs_screen.dart')
          .readAsStringSync();
    });

    test('hardcoded fırın/usta listeleri kaldırıldı', () {
      expect(src.contains('_bakeriesHiring'), isFalse,
          reason: 'Eski hardcoded "_bakeriesHiring" listesi kalmamalı');
      expect(src.contains('_bakersLooking'), isFalse,
          reason: 'Eski hardcoded "_bakersLooking" listesi kalmamalı');
    });

    test('mock işletme isimleri kaldırıldı', () {
      expect(src.contains('Konak Fırını'), isFalse);
      expect(src.contains('Selin Pastane'), isFalse);
      expect(src.contains('Ekmek Sepeti'), isFalse);
      expect(src.contains('Antep Pide Evi'), isFalse);
    });

    test('mock ustalar kaldırıldı', () {
      expect(src.contains('Hasan Kara'), isFalse);
      expect(src.contains('Selin Ateş'), isFalse);
      expect(src.contains('Burak D.'), isFalse);
    });

    test('Provider tabanlı listeye bağlandı', () {
      expect(src.contains('activeJobSeekPostsProvider'), isTrue,
          reason: 'JobsScreen gerçek provider\'a bağlı olmalı');
      expect(src.contains('ConsumerStatefulWidget'), isTrue);
    });

    test('İş Veriyorum tarafı artık gerçek backend (coming-soon yok)', () {
      // V1 messaging sprint sonrası: _HiringComingSoon placeholder ve
      // jobsHiringComingSoon* string'leri kaldırıldı, segment gerçek
      // `activeJobOffersProvider` listesine bağlandı.
      expect(src.contains('jobsHiringComingSoonTitle'), isFalse,
          reason: 'coming-soon placeholder kaldırılmış olmalı');
      expect(src.contains('_HiringComingSoon'), isFalse,
          reason: 'placeholder widget silinmiş olmalı');
      expect(src.contains('activeJobOffersProvider'), isTrue,
          reason: 'gerçek backend listesi kullanılmalı');
    });
  });

  group('AppShell bottom nav', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/dashboard/screens/app_shell.dart')
          .readAsStringSync();
    });

    // Navigation IA Sprint — alt nav: Topluluk · Pazar · İlanlar · Mesajlar ·
    // Panel. Feed+Gruplar → Topluluk; jobs+marketplace → İlanlar; marketplace
    // İlanlar; Pazar → B2B tedarik modülü; Mesajlar alt nav'a çıktı.
    test('5 tab tanımlı: Topluluk, Pazar, İlanlar, Mesajlar, Panel', () {
      expect(src.contains('AppRoutes.community'), isTrue);
      expect(src.contains('AppRoutes.pazar'), isTrue);
      expect(src.contains('AppRoutes.listings'), isTrue);
      expect(src.contains('AppRoutes.messages'), isTrue,
          reason: 'Mesajlar alt nav tab oldu');
      expect(src.contains('AppRoutes.panel'), isTrue);
    });

    test('Pazar tab storefront ikonu (B2B canlı → Yakında rozeti yok)', () {
      expect(src.contains('Icons.storefront_outlined'), isTrue);
      expect(src.contains('Icons.storefront_rounded'), isTrue);
      expect(src.contains('comingSoon'), isFalse,
          reason: 'B2B Pazar\'a bağlandı; Yakında rozeti kaldırıldı');
    });

    test('Mesajlar tab okunmamış sayaç rozetini besler', () {
      expect(src.contains('totalUnreadMessagesProvider'), isTrue);
      expect(src.contains('badgeCount'), isTrue);
    });
  });

  group('LocalWorkerRepository.listActiveJobSeekPosts', () {
    test('sadece is_active=true satırları döner', () async {
      final repo = LocalWorkerRepository();
      // owner_id null olabilir local'de, sadece is_active filtresine bakılıyor.
      await repo.upsertJobSeekPost(const JobSeekPost(
        title: 'Aktif ilan',
        isActive: true,
      ));
      await repo.upsertJobSeekPost(const JobSeekPost(
        title: 'Kapalı ilan',
        isActive: false,
      ));
      await repo.upsertJobSeekPost(const JobSeekPost(
        title: 'Başka aktif ilan',
        isActive: true,
      ));

      final active = await repo.listActiveJobSeekPosts();
      expect(active.length, 2);
      expect(active.every((p) => p.isActive), isTrue);
      final titles = active.map((p) => p.title).toSet();
      expect(titles, {'Aktif ilan', 'Başka aktif ilan'});
    });

    test('limit\'e saygı duyar', () async {
      final repo = LocalWorkerRepository();
      for (var i = 0; i < 5; i++) {
        await repo.upsertJobSeekPost(JobSeekPost(
          title: 'İlan $i',
          isActive: true,
        ));
      }
      final active = await repo.listActiveJobSeekPosts(limit: 2);
      expect(active.length, 2);
    });

    test('boş listede boş döner (empty state için)', () async {
      final repo = LocalWorkerRepository();
      final active = await repo.listActiveJobSeekPosts();
      expect(active, isEmpty);
    });
  });
}
