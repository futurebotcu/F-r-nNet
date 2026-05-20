// FırınNet Market V1 Commit M1 — schema + repository genişletme testleri.
//
// Kapsam:
//   * Migration dosyası: yeni kolonlar + CHECK constraints + RLS +
//     market_listing_media + market_listing_saves + market-media bucket.
//   * MarketListing model genişletme (status, is_deleted, equipment +
//     bakery transfer alanları, media/isSavedByMe).
//   * MarketFilters: copyWith + equality + activeCount.
//   * Repository interface 13 method.
//   * Supabase impl: .select('id') empty → StateError pattern (sosyal
//     sprint dersi); media/saves cross-check; storage rollback path.
//   * Local impl: filter + media + saves davranışı.
//   * Guarded delegator: guest write guard.
//   * Third-party Bagisto attribution.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/features/marketplace/models/market_filters.dart';
import 'package:firin_defter/features/marketplace/models/market_listing.dart';
import 'package:firin_defter/features/marketplace/repositories/local_market_listing_repository.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('M1 — Migration dosyası', () {
    final src = File(
      'supabase/migrations/20260520140000_market_v1_listings_expansion.sql',
    ).readAsStringSync();

    test('listing_type CHECK sadece equipment_sale + bakery_transfer', () {
      // Pozitif kontrol: CHECK string aynen tanımlandığı gibi.
      expect(
        src.contains("check (listing_type in ('equipment_sale', 'bakery_transfer'))"),
        isTrue,
      );
      // Negatif kontrol: ALTER TABLE add constraint bloklarında
      // 'product'/'service'/'equipment' (jenerik tipler) yok.
      // (Rationale 'comment on column' içinde tarihi referans olabilir.)
      final addConstraintBlocks = RegExp(
        r"add constraint market_listings_listing_type_check\s*\n?\s*check[^;]+;",
        multiLine: true,
      ).allMatches(src);
      for (final m in addConstraintBlocks) {
        final body = m.group(0)!;
        expect(body.contains("'product'"), isFalse,
            reason: 'CHECK constraint listing_type only has new V1 values');
        expect(body.contains("'service'"), isFalse);
        expect(body.contains("'equipment'") && !body.contains("'equipment_sale'"), isFalse);
      }
    });

    test('Default listing_type = equipment_sale', () {
      expect(
        src.contains("alter column listing_type set default 'equipment_sale'"),
        isTrue,
      );
    });

    test('status CHECK + is_deleted + classified marketplace kolonları', () {
      expect(
        src.contains("check (status in ('active', 'sold', 'paused'))"),
        isTrue,
      );
      expect(
        src.contains('is_deleted boolean not null default false'),
        isTrue,
      );
      expect(src.contains('equipment_category text'), isTrue);
      expect(src.contains("currency text not null default 'TRY'"), isTrue);
      expect(src.contains('rent_price numeric'), isTrue);
      expect(src.contains('transfer_price numeric'), isTrue);
      expect(src.contains('contact_phone text'), isTrue);
      expect(src.contains('contact_whatsapp text'), isTrue);
      expect(src.contains('view_count int not null default 0'), isTrue);
    });

    test('SELECT policy soft-delete RETURNING dersini uygular', () {
      expect(
        src.contains(
          "(status = 'active' and is_deleted = false)\n"
          "    or owner_id = auth.uid()",
        ),
        isTrue,
      );
    });

    test('market_listing_media SELECT EXISTS parent listing aktif', () {
      // owner her zaman görür + media.is_deleted=false + parent
      // listing active+is_deleted=false
      expect(src.contains('exists (\n        select 1 from public.market_listings ml'), isTrue);
      expect(src.contains("ml.status = 'active'"), isTrue);
      expect(src.contains('ml.is_deleted = false'), isTrue);
    });

    test('market_listing_media + saves FK profiles(id)', () {
      // owner_id ve user_id profiles'a referans — market_listings.owner_id
      // de profiles olduğu için tutarlı.
      expect(
        src.contains(
          'references public.profiles(id) on delete cascade',
        ),
        isTrue,
      );
    });

    test('market-media bucket public + path prefix RLS', () {
      expect(
        src.contains("'market-media', 'market-media', true"),
        isTrue,
      );
      expect(
        src.contains('(storage.foldername(name))[1] = auth.uid()::text'),
        isTrue,
      );
    });

    test('Indexler tanımlı', () {
      expect(
        src.contains('market_listings_status_deleted_created_idx'),
        isTrue,
      );
      expect(src.contains('market_listings_type_city_idx'), isTrue);
      expect(src.contains('market_listings_owner_created_idx'), isTrue);
      expect(src.contains('market_listing_media_listing_idx'), isTrue);
    });
  });

  group('M1 — MarketListing model expansion', () {
    test('Yeni alanlar default değerleri ile', () {
      const m = MarketListing(title: 't', category: 'ekipman');
      expect(m.listingType, 'equipment_sale');
      expect(m.status, 'active');
      expect(m.isDeleted, isFalse);
      expect(m.currency, 'TRY');
      expect(m.negotiable, isFalse);
      expect(m.viewCount, 0);
      expect(m.mediaList, isEmpty);
      expect(m.isSavedByMe, isFalse);
    });

    test('isEquipmentSale / isBakeryTransfer helper', () {
      const eq = MarketListing(
        title: 't',
        category: 'ekipman',
        listingType: 'equipment_sale',
      );
      const bt = MarketListing(
        title: 't',
        category: 'devren_firin',
        listingType: 'bakery_transfer',
      );
      expect(eq.isEquipmentSale, isTrue);
      expect(eq.isBakeryTransfer, isFalse);
      expect(bt.isBakeryTransfer, isTrue);
      expect(bt.isEquipmentSale, isFalse);
    });

    test('toInsertRow yalnız dolu alanları gönderir', () {
      const m = MarketListing(
        title: 'Mikser',
        category: 'ekipman',
        listingType: 'equipment_sale',
        price: 25000,
        city: 'Istanbul',
      );
      final row = m.toInsertRow('owner-uuid');
      expect(row['title'], 'Mikser');
      expect(row['listing_type'], 'equipment_sale');
      expect(row['price'], 25000);
      expect(row['city'], 'Istanbul');
      // Doldurulmayan optional alanlar map'te yok
      expect(row.containsKey('rent_price'), isFalse);
      expect(row.containsKey('brand'), isFalse);
    });

    test('fromRow yeni alanları doğru parse eder', () {
      final m = MarketListing.fromRow(<String, dynamic>{
        'id': 'l1',
        'owner_id': 'u1',
        'title': 'Devren Fırın',
        'category': 'devren_firin',
        'listing_type': 'bakery_transfer',
        'status': 'active',
        'is_deleted': false,
        'rent_price': 15000,
        'transfer_price': 500000,
        'area_m2': 120,
        'currency': 'TRY',
        'negotiable': true,
        'created_at': '2026-05-20T12:00:00Z',
        'updated_at': '2026-05-20T12:00:00Z',
      });
      expect(m.listingType, 'bakery_transfer');
      expect(m.rentPrice, 15000);
      expect(m.transferPrice, 500000);
      expect(m.areaM2, 120);
      expect(m.negotiable, isTrue);
      expect(m.isBakeryTransfer, isTrue);
    });
  });

  group('M1 — MarketFilters', () {
    test('Empty + activeCount 0', () {
      const f = MarketFilters();
      expect(f.isEmpty, isTrue);
      expect(f.activeCount, 0);
    });

    test('Filter setleri + activeCount', () {
      // V1 M2 controlled-data fix: city aktif sayımı cityCode'a bağlandı
      // (display label 'city' tek başına aktif sayılmaz; picker zorunlu).
      const f = MarketFilters(
        listingType: 'equipment_sale',
        cityCode: '34',
        city: 'İstanbul',
        minPrice: 1000,
        maxPrice: 50000,
      );
      expect(f.isEmpty, isFalse);
      expect(f.activeCount, 3); // type + city (code) + price range (tek slot)
    });

    test('copyWith clear* flag\'leri', () {
      const f = MarketFilters(
        listingType: 'equipment_sale',
        cityCode: '34',
        city: 'İstanbul',
      );
      final cleared = f.copyWith(clearListingType: true);
      expect(cleared.listingType, isNull);
      // V1 M2: clearCity flag'i atılmadıkça city + cityCode taşınır.
      expect(cleared.cityCode, '34');
      expect(cleared.city, 'İstanbul');
    });

    test('Equality + hashCode (provider family cache key)', () {
      const a = MarketFilters(listingType: 'equipment_sale', city: 'Ankara');
      const b = MarketFilters(listingType: 'equipment_sale', city: 'Ankara');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('M1 — Repository interface 13 method', () {
    test('Interface tüm V1 + V2 method\'larını tanımlar', () {
      final src = _strip(
        File(
          'lib/features/marketplace/repositories/'
          'market_listing_repository.dart',
        ).readAsStringSync(),
      );
      // V1 backward
      expect(src.contains('Future<List<MarketListing>> listActive'), isTrue);
      expect(src.contains('Future<List<MarketListing>> listMine'), isTrue);
      expect(src.contains('Future<MarketListing?> getListing'), isTrue);
      expect(src.contains('Future<MarketListing> upsertListing'), isTrue);
      expect(src.contains('Future<void> setActive'), isTrue);
      expect(src.contains('Future<void> deleteListing'), isTrue);
      // V2 expansion
      expect(src.contains('Future<List<MarketListing>> listFiltered'), isTrue);
      expect(src.contains('Future<void> softDeleteListing'), isTrue);
      expect(src.contains('Future<void> setStatus'), isTrue);
      expect(src.contains('Future<MarketListingMedia> uploadListingImage'), isTrue);
      expect(src.contains('Future<List<MarketListingMedia>> listListingMedia'),
          isTrue);
      expect(src.contains('Future<void> deleteListingMedia'), isTrue);
      expect(src.contains('Future<void> saveListing'), isTrue);
      expect(src.contains('Future<void> unsaveListing'), isTrue);
      expect(src.contains('Future<List<MarketListing>> listSavedListings'),
          isTrue);
      expect(src.contains('Future<Set<String>> savedListingIdsSet'), isTrue);
    });
  });

  group('M1 — Supabase impl hardening (sosyal sprint dersi)', () {
    final src = _strip(
      File(
        'lib/features/marketplace/repositories/'
        'supabase_market_listing_repository.dart',
      ).readAsStringSync(),
    );

    test('softDeleteListing .select(id) + StateError on empty', () {
      final start = src.indexOf('Future<void> softDeleteListing');
      expect(start, greaterThan(0));
      final next = src.indexOf('Future<', start + 30);
      final body = src.substring(start, next);
      expect(body.contains(".select('id')"), isTrue);
      expect(body.contains('(rows as List).isEmpty'), isTrue);
      expect(body.contains('StateError'), isTrue);
    });

    test('setStatus .select(id) + StateError on empty', () {
      final start = src.indexOf('Future<void> setStatus');
      expect(start, greaterThan(0));
      final next = src.indexOf('Future<', start + 30);
      final body = src.substring(start, next);
      expect(body.contains(".select('id')"), isTrue);
      expect(body.contains('(rows as List).isEmpty'), isTrue);
    });

    test('uploadListingImage storage rollback path', () {
      expect(src.contains(".storage.from('market-media')"), isTrue);
      expect(src.contains('uploadBinary('), isTrue);
      expect(src.contains('.storage.from(\'market-media\').remove'), isTrue);
    });

    test('saveListing 23505 idempotent yutma', () {
      expect(src.contains("if (e.code != '23505') rethrow"), isTrue);
    });

    test('listFiltered defansif status+is_deleted client filtresi', () {
      final start = src.indexOf('Future<List<MarketListing>> listFiltered');
      expect(start, greaterThan(0));
      final next = src.indexOf('Future<', start + 30);
      final body = src.substring(start, next);
      expect(body.contains(".eq('status', 'active')"), isTrue);
      expect(body.contains(".eq('is_deleted', false)"), isTrue);
    });
  });

  group('M1 — Local impl davranışı', () {
    test('Filter + media + saved cross-check', () async {
      final repo = LocalMarketListingRepository(currentUserId: 'me');
      // 2 listing ekle
      final l1 = await repo.upsertListing(const MarketListing(
        title: 'Hamur Karıştırıcı',
        category: 'ekipman',
        listingType: 'equipment_sale',
        equipmentCategory: 'mixer',
        city: 'Istanbul',
        price: 5000,
      ));
      final l2 = await repo.upsertListing(const MarketListing(
        title: 'Devren Fırın',
        category: 'devren_firin',
        listingType: 'bakery_transfer',
        city: 'Ankara',
        transferPrice: 250000,
      ));
      // Save l1
      await repo.saveListing(l1.id!);
      // Filter: equipment_sale
      final eqOnly = await repo.listFiltered(
        const MarketFilters(listingType: 'equipment_sale'),
      );
      expect(eqOnly, hasLength(1));
      expect(eqOnly.first.id, l1.id);
      expect(eqOnly.first.isSavedByMe, isTrue);
      // Filter: bakery_transfer
      final btOnly = await repo.listFiltered(
        const MarketFilters(listingType: 'bakery_transfer'),
      );
      expect(btOnly, hasLength(1));
      expect(btOnly.first.id, l2.id);
      // Saved list
      final saved = await repo.listSavedListings();
      expect(saved.map((m) => m.id), contains(l1.id));
    });

    test('Soft-delete owner-only + status update + image upload', () async {
      final repo = LocalMarketListingRepository(currentUserId: 'me');
      final l = await repo.upsertListing(const MarketListing(
        title: 'Test',
        category: 'ekipman',
      ));
      // Image upload
      final media = await repo.uploadListingImage(
        listingId: l.id!,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileExtension: 'jpg',
      );
      expect(media.listingId, l.id);
      expect(media.sortOrder, 0);
      // setStatus
      await repo.setStatus(l.id!, 'paused');
      final after = await repo.getListing(l.id!);
      expect(after?.status, 'paused');
      // Active list paused olanı göstermez
      final activeList = await repo.listActive();
      expect(activeList.map((m) => m.id), isNot(contains(l.id)));
      // Soft-delete
      await repo.softDeleteListing(l.id!);
      final afterDel = await repo.getListing(l.id!);
      expect(afterDel?.isDeleted, isTrue);
    });

    test('Non-owner softDelete → StateError', () {
      final repo = LocalMarketListingRepository(currentUserId: 'me');
      expect(
        () => repo.softDeleteListing('not_exist'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('M1 — Guarded delegator guest guards', () {
    final src = _strip(
      File(
        'lib/features/marketplace/repositories/'
        'guarded_market_listing_repository.dart',
      ).readAsStringSync(),
    );

    test('Tüm write method\'lar _requireWrite çağrısı', () {
      // 8 yeni/eski write method'unun _requireWrite var
      expect(src.contains("_requireWrite('market ilanı kaydetmek')"), isTrue);
      expect(src.contains("_requireWrite('market ilanını silmek')"), isTrue);
      expect(
        src.contains("_requireWrite('market ilanı durumunu güncellemek')"),
        isTrue,
      );
      expect(
        src.contains("_requireWrite('market ilanına görsel eklemek')"),
        isTrue,
      );
      expect(
        src.contains("_requireWrite('market ilan görselini silmek')"),
        isTrue,
      );
      expect(
        src.contains("_requireWrite('market ilanını kaydetmek')"),
        isTrue,
      );
      expect(
        src.contains("_requireWrite('market ilanı kaydını kaldırmak')"),
        isTrue,
      );
    });

    test('Read method\'lar guard\'sız delege', () {
      expect(src.contains('inner.listFiltered('), isTrue);
      expect(src.contains('inner.listSavedListings()'), isTrue);
      expect(src.contains('inner.savedListingIdsSet('), isTrue);
      expect(src.contains('inner.getListing('), isTrue);
    });
  });

  group('M1 — Bagisto attribution', () {
    test('third_party/bagisto/LICENSE + THIRD_PARTY_NOTICES.md update', () {
      final license = File(
        'third_party/bagisto_opensource_ecommerce_mobile_app/LICENSE',
      );
      expect(license.existsSync(), isTrue);
      final body = license.readAsStringSync();
      expect(body.contains('MIT License'), isTrue);
      expect(body.contains('Bagisto'), isTrue);

      final notices =
          File('THIRD_PARTY_NOTICES.md').readAsStringSync();
      expect(
        notices.contains('bagisto/opensource-ecommerce-mobile-app'),
        isTrue,
      );
      // Substantially modified clause
      expect(
        notices.contains('Bagisto BLoC → FırınNet Riverpod'),
        isTrue,
      );
      // Kapsam dışı patternler net
      expect(notices.contains('Cart / checkout / order / payment'), isTrue);
    });
  });
}
