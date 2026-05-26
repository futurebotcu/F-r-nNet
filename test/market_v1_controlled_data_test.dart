// FırınNet Market V1 M2 — Controlled-data fix invariants.
//
// V1 M2 controlled-data: serbest text yerine sabit taxonomy + il/ilçe
// picker. Bu dosya tüm invariant'ları source-level + behavior-level
// doğrular: 81 il listesi, picker davranışı, form-code/filter-code
// yazımı, taxonomy whitelist.

import 'dart:io';

import 'package:firin_defter/core/data/turkey_locations.dart';
import 'package:firin_defter/features/marketplace/data/marketplace_taxonomy.dart';
import 'package:firin_defter/features/marketplace/models/market_filters.dart';
import 'package:firin_defter/features/marketplace/models/market_listing.dart';
import 'package:firin_defter/features/marketplace/repositories/local_market_listing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TurkeyLocations — 81 il', () {
    test('provinces listesi tam 81 ili kapsar', () {
      expect(TurkeyLocations.provinces.length, 81);
    });

    test('Plaka kodları tekil ve 01..81 aralığında', () {
      final codes = TurkeyLocations.provinces.map((p) => p.code).toSet();
      expect(codes.length, 81, reason: 'Plaka kodları tekil olmalı');
      for (final p in TurkeyLocations.provinces) {
        final n = int.tryParse(p.code);
        expect(n, isNotNull);
        expect(n! >= 1 && n <= 81, isTrue);
        expect(p.code.length, 2, reason: '2 haneli string ("01" formatı)');
      }
    });

    test('Her ilin en az bir ilçesi var', () {
      for (final p in TurkeyLocations.provinces) {
        expect(p.districts.isNotEmpty, isTrue,
            reason: '${p.name} ilçe listesi boş');
      }
    });

    test('İstanbul (34) 39 ilçe içerir', () {
      final i = TurkeyLocations.findProvinceByCode('34');
      expect(i, isNotNull);
      expect(i!.name, 'İstanbul');
      expect(i.districts.length, 39);
    });

    test('Büyük şehirler tanınır', () {
      for (final code in const ['06', '35', '16', '07', '01', '42']) {
        final p = TurkeyLocations.findProvinceByCode(code);
        expect(p, isNotNull, reason: 'Plaka $code bulunamadı');
        expect(p!.districts.isNotEmpty, isTrue);
      }
    });

    test('İlçe code lower-kebab format', () {
      final pattern = RegExp(r'^[a-z0-9][a-z0-9-]*$');
      for (final p in TurkeyLocations.provinces) {
        for (final d in p.districts) {
          expect(pattern.hasMatch(d.code), isTrue,
              reason: '${p.name}/${d.name} → "${d.code}" format dışı');
        }
      }
    });

    test('findDistrict il + ilçe code ile döner', () {
      final d = TurkeyLocations.findDistrict('34', 'kadikoy');
      expect(d, isNotNull);
      expect(d!.name, 'Kadıköy');
    });

    test('findProvinceByCode unknown → null', () {
      expect(TurkeyLocations.findProvinceByCode(null), isNull);
      expect(TurkeyLocations.findProvinceByCode('99'), isNull);
    });
  });

  group('MarketplaceTaxonomy — sabit seçenekler', () {
    test('listingTypes yalnız 2 değer (V1 narrowing)', () {
      expect(MarketplaceTaxonomy.listingTypes.keys.toSet(), {
        'equipment_sale',
        'bakery_transfer',
      });
    });

    test('equipmentCategories 8 sabit kategori', () {
      expect(MarketplaceTaxonomy.equipmentCategories.length, 8);
      expect(
        MarketplaceTaxonomy.equipmentCategories.keys,
        containsAll(<String>[
          'oven',
          'mixer',
          'dough_divider',
          'proofing',
          'refrigerator',
          'display_counter',
          'vehicle',
          'other',
        ]),
      );
    });

    test('conditions: new / used / refurbished', () {
      expect(MarketplaceTaxonomy.conditions.keys.toSet(), {
        'new',
        'used',
        'refurbished',
      });
    });

    test('contactPreferences: in_app / phone / whatsapp', () {
      expect(MarketplaceTaxonomy.contactPreferences.keys.toSet(), {
        'in_app',
        'phone',
        'whatsapp',
      });
    });

    test('currencies: TRY / EUR / USD', () {
      expect(MarketplaceTaxonomy.currencies.keys.toSet(), {
        'TRY',
        'EUR',
        'USD',
      });
      expect(MarketplaceTaxonomy.defaultCurrency, 'TRY');
    });

    test('Validator helper\'ları doğru reddeder', () {
      expect(MarketplaceTaxonomy.isValidListingType('equipment_sale'), isTrue);
      expect(MarketplaceTaxonomy.isValidListingType('product'), isFalse);
      expect(MarketplaceTaxonomy.isValidCondition(null), isTrue);
      expect(MarketplaceTaxonomy.isValidCondition('as_is'), isFalse);
      expect(MarketplaceTaxonomy.isValidCurrency('TRY'), isTrue);
      expect(MarketplaceTaxonomy.isValidCurrency('GBP'), isFalse);
    });
  });

  group('MarketListing model — code alanları', () {
    test('Default countryCode = TR', () {
      const m = MarketListing(title: 't', category: 'ekipman');
      expect(m.countryCode, 'TR');
      expect(m.cityCode, isNull);
      expect(m.districtCode, isNull);
    });

    test('toInsertRow code alanlarını yazar', () {
      const m = MarketListing(
        title: 't',
        category: 'ekipman',
        cityCode: '34',
        city: 'İstanbul',
        districtCode: 'kadikoy',
        district: 'Kadıköy',
      );
      final row = m.toInsertRow('owner1');
      expect(row['country_code'], 'TR');
      expect(row['city_code'], '34');
      expect(row['city'], 'İstanbul');
      expect(row['district_code'], 'kadikoy');
      expect(row['district'], 'Kadıköy');
    });

    test('fromRow code alanlarını okur', () {
      final m = MarketListing.fromRow({
        'title': 't',
        'category': 'ekipman',
        'country_code': 'TR',
        'city_code': '06',
        'district_code': 'cankaya',
      });
      expect(m.countryCode, 'TR');
      expect(m.cityCode, '06');
      expect(m.districtCode, 'cankaya');
    });
  });

  group('MarketFilters — code-based filter', () {
    test('Default empty + activeCount 0', () {
      const f = MarketFilters();
      expect(f.isEmpty, isTrue);
      expect(f.activeCount, 0);
    });

    test('cityCode/districtCode activeCount\'a katkı', () {
      const f = MarketFilters(cityCode: '34', city: 'İstanbul');
      expect(f.activeCount, 1);
      const f2 = MarketFilters(
        cityCode: '34',
        city: 'İstanbul',
        districtCode: 'kadikoy',
        district: 'Kadıköy',
      );
      expect(f2.activeCount, 2);
    });

    test('clearCity hem code hem label\'ı temizler', () {
      const initial = MarketFilters(cityCode: '34', city: 'İstanbul');
      final cleared = initial.copyWith(clearCity: true);
      expect(cleared.cityCode, isNull);
      expect(cleared.city, isNull);
    });

    test('Equality city display label\'a değil koda göre', () {
      // Aynı code, farklı display → eşit kabul (cache key code üzerinden).
      const a = MarketFilters(cityCode: '34', city: 'İstanbul');
      const b = MarketFilters(cityCode: '34', city: 'istanbul');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('LocalMarketListingRepository — code-based listFiltered', () {
    test('cityCode filter sadece eşleşen satırları döner', () async {
      final repo = LocalMarketListingRepository();
      final a = await repo.upsertListing(const MarketListing(
        title: 'A',
        category: 'ekipman',
        listingType: 'equipment_sale',
        cityCode: '34',
        city: 'İstanbul',
      ));
      final b = await repo.upsertListing(const MarketListing(
        title: 'B',
        category: 'ekipman',
        listingType: 'equipment_sale',
        cityCode: '06',
        city: 'Ankara',
      ));
      expect(a.cityCode, '34');
      expect(b.cityCode, '06');
      final ist =
          await repo.listFiltered(const MarketFilters(cityCode: '34'));
      expect(ist.length, 1);
      expect(ist.first.title, 'A');
    });

    test('districtCode filter sadece eşleşen satırları döner', () async {
      final repo = LocalMarketListingRepository();
      await repo.upsertListing(const MarketListing(
        title: 'Kadıköy iş',
        category: 'ekipman',
        listingType: 'equipment_sale',
        cityCode: '34',
        districtCode: 'kadikoy',
      ));
      await repo.upsertListing(const MarketListing(
        title: 'Beşiktaş iş',
        category: 'ekipman',
        listingType: 'equipment_sale',
        cityCode: '34',
        districtCode: 'besiktas',
      ));
      final out = await repo.listFiltered(
        const MarketFilters(cityCode: '34', districtCode: 'kadikoy'),
      );
      expect(out.length, 1);
      expect(out.first.title, 'Kadıköy iş');
    });
  });

  group('Migration dosyası — controlled-data', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260520150000_market_v1_controlled_data_codes.sql',
      ).readAsStringSync();
    });

    test('country_code/city_code/district_code ADD COLUMN var', () {
      expect(sql.contains('country_code'), isTrue);
      expect(sql.contains('city_code'), isTrue);
      expect(sql.contains('district_code'), isTrue);
    });

    test('country_code default \'TR\' + CHECK whitelist', () {
      expect(sql.contains("default 'TR'"), isTrue);
      expect(sql.contains('country_code_check'), isTrue);
    });

    test('Format CHECK regex tanımlı', () {
      expect(sql.contains("city_code ~ '^[0-9]{2}\$'"), isTrue);
      expect(sql.contains("district_code ~ '^[a-z0-9][a-z0-9-]*\$'"), isTrue);
    });

    test('Cross-field: district_code ⇒ city_code', () {
      expect(sql.contains('district_requires_city'), isTrue);
    });

    test('Index: (city_code, district_code) + (listing_type, city_code)',
        () {
      expect(sql.contains('market_listings_city_district_idx'), isTrue);
      // Ana migration `market_listings_type_city_idx` ismini kullanır;
      // 150100 patch dosyası `_type_city_code_idx`'e yeniden adlandırır.
      expect(sql.contains('market_listings_type_city_idx'), isTrue);
    });

    test('Index patch: type_city_code_idx (150100 patch)', () {
      final patchSql = File(
        'supabase/migrations/20260520150100_market_v1_type_city_code_index_fix.sql',
      ).readAsStringSync();
      expect(patchSql.contains('drop index if exists'), isTrue);
      expect(patchSql.contains('market_listings_type_city_code_idx'), isTrue);
      expect(
        patchSql.contains('(listing_type, city_code)'),
        isTrue,
      );
    });
  });

  group('Form — serbest text yok', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/marketplace/screens/market_listing_form_screen.dart',
      ).readAsStringSync();
    });

    test('city/district için TextField/TextEditingController yok', () {
      // _city/_district TextEditingController kaldırıldı; LocationPickerField
      // kullanılır. Yorum satırlarını ayıklayıp kod gövdesinde kontrol et.
      final code = src
          .split('\n')
          .map((l) => l.trimLeft())
          .where((l) => !l.startsWith('//'))
          .join('\n');
      expect(code.contains('TextEditingController _city'), isFalse);
      expect(code.contains('TextEditingController _district'), isFalse);
      expect(code.contains('controller: _city'), isFalse);
      expect(code.contains('controller: _district'), isFalse);
    });

    test('LocationPickerField + LocationPicker.show kullanır', () {
      expect(src.contains('LocationPickerField'), isTrue);
      expect(src.contains('LocationPicker.showProvincePicker'), isTrue);
      expect(src.contains('LocationPicker.showDistrictPicker'), isTrue);
    });

    test('İl değişince ilçe sıfırlanır (state mantığı)', () {
      expect(
        src.contains('_selectedDistrict = null'),
        isTrue,
        reason: 'İl değişimi ilçeyi reset etmeli',
      );
    });

    test('Taxonomy dropdown\'larından beslenir', () {
      expect(src.contains('MarketplaceTaxonomy.listingTypes'), isTrue);
      expect(
          src.contains('MarketplaceTaxonomy.equipmentCategories'), isTrue);
      expect(src.contains('MarketplaceTaxonomy.conditions'), isTrue);
      expect(
          src.contains('MarketplaceTaxonomy.contactPreferences'), isTrue);
      expect(src.contains('MarketplaceTaxonomy.currencies'), isTrue);
    });

    test('Submit cityCode + city + districtCode + district birlikte yazar',
        () {
      expect(src.contains('cityCode: _selectedProvince?.code'), isTrue);
      expect(src.contains('city: _selectedProvince?.name'), isTrue);
      expect(
          src.contains('districtCode: _selectedDistrict?.code'), isTrue);
      expect(src.contains('district: _selectedDistrict?.name'), isTrue);
      expect(src.contains('countryCode: MarketplaceTaxonomy'), isTrue);
    });
  });

  group('Filter sheet — picker entegrasyon', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/marketplace/widgets/marketplace_filters_sheet.dart',
      ).readAsStringSync();
    });

    test('LocationPickerField + LocationPicker.show kullanır', () {
      expect(src.contains('LocationPickerField'), isTrue);
      expect(src.contains('LocationPicker.showProvincePicker'), isTrue);
      expect(src.contains('LocationPicker.showDistrictPicker'), isTrue);
    });

    test('Apply cityCode/districtCode + display label döner', () {
      expect(src.contains('cityCode: _province?.code'), isTrue);
      expect(src.contains('districtCode: _district?.code'), isTrue);
    });

    test('Listing type chip MarketplaceTaxonomy.listingTypes\'tan', () {
      // Multi-line tolerant — bazı for-in satırları wrap olabilir.
      expect(src.contains('MarketplaceTaxonomy.listingTypes'), isTrue);
      expect(src.contains('MarketplaceTaxonomy.equipmentCategories'), isTrue);
      expect(src.contains('MarketplaceTaxonomy.conditions'), isTrue);
    });
  });

  group('Supabase repository — code-based .eq filter', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/marketplace/repositories/supabase_market_listing_repository.dart',
      ).readAsStringSync();
    });

    test('city/district serbest .eq kaldırıldı', () {
      // Eski: q.eq('city', filters.city!) — yeni: q.eq('city_code', ...).
      expect(src.contains("eq('city', filters.city"), isFalse,
          reason: 'Serbest city .eq kaldırıldı');
      expect(src.contains("eq('district', filters.district"), isFalse,
          reason: 'Serbest district .eq kaldırıldı');
    });

    test('city_code/district_code/country_code .eq eklendi', () {
      expect(src.contains("eq('country_code', filters.countryCode"), isTrue);
      expect(src.contains("eq('city_code', filters.cityCode"), isTrue);
      expect(
          src.contains("eq('district_code', filters.districtCode"), isTrue);
    });

    test('SELECT _columns code alanlarını içerir', () {
      expect(src.contains('country_code'), isTrue);
      expect(src.contains('city_code'), isTrue);
      expect(src.contains('district_code'), isTrue);
    });
  });
}
