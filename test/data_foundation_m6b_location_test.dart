// FırınNet Data Foundation M6B — dealer + job_offer + bakery location
// invariant testleri.
//
// Karar:
//   * dealers, job_offer_posts, bakeries tablolarına city_code +
//     district_code text nullable eklendi (plaka regex + slug + parent
//     CHECK).
//   * Eski city/district/area text alanları KORUNUR.
//   * Dealer + JobOffer model dual-write yapar; AddDealerScreen +
//     JobOfferFormScreen city/district TextField'ları il + ilçe picker'a
//     dönüştü.
//   * Bakery: sadece DB hazırlığı; aktif setup/edit UI yok, model/repo
//     dokunulmadı.

import 'dart:io';

import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/jobs/models/job_offer_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M6B — Migration source', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260523210000_location_codes_m6b.sql',
      ).readAsStringSync();
    });

    test('3 tabloya city_code + district_code eklendi (additive)', () {
      expect(
          sql.contains(
              'alter table public.dealers\n  add column if not exists city_code text,\n  add column if not exists district_code text'),
          isTrue);
      expect(
          sql.contains(
              'alter table public.job_offer_posts\n  add column if not exists city_code text,\n  add column if not exists district_code text'),
          isTrue);
      expect(
          sql.contains(
              'alter table public.bakeries\n  add column if not exists city_code text,\n  add column if not exists district_code text'),
          isTrue);
    });

    test('Regex CHECK plaka 01..81 — 3 tabloda city_code için', () {
      expect(sql.contains('dealers_city_code_chk'), isTrue);
      expect(sql.contains('job_offer_posts_city_code_chk'), isTrue);
      expect(sql.contains('bakeries_city_code_chk'), isTrue);
      expect(
          sql.contains(r"~ '^(0[1-9]|[1-7][0-9]|8[01])$'"), isTrue,
          reason: 'Plaka regex pattern bulunmalı');
    });

    test('district_code slug CHECK + city_code zorunlu (parent check)', () {
      expect(sql.contains('dealers_district_code_chk'), isTrue);
      expect(sql.contains('job_offer_posts_district_code_chk'), isTrue);
      expect(sql.contains('bakeries_district_code_chk'), isTrue);
      expect(
          sql.contains(r"~ '^[a-z0-9]+(-[a-z0-9]+)*$'"), isTrue,
          reason: 'Slug regex pattern bulunmalı');
      expect(sql.contains('city_code is not null'), isTrue,
          reason: 'district→city zorunlu CHECK bulunmalı');
      expect(sql.contains('length(district_code) <= 40'), isTrue);
    });

    test('Eski city/district text kolonları DROP edilmiyor', () {
      // Yalnız `_code` versiyonları rollback yorumunda drop edilebilir;
      // ana text kolonları korunmalı. Pattern: tam kelime + (;| veya satır
      // sonu) — substring match `district_code` ile karışmasın.
      final dropPattern = RegExp(
        r'drop column (city|district)(?:\s*;|\s+|$)',
        multiLine: true,
      );
      expect(dropPattern.hasMatch(sql), isFalse,
          reason: 'Ana city/district text kolonu DROP edilmemeli');
    });
  });

  group('M6B — Dealer model', () {
    test('Yeni alanlar opsiyonel; default null/boş', () {
      final d = Dealer(id: 'd1', name: 'X', createdAt: DateTime.utc(2024));
      expect(d.city, '');
      expect(d.cityCode, isNull);
      expect(d.districtCode, isNull);
    });

    test('copyWith default → cityCode/districtCode korunur', () {
      final d = Dealer(
        id: 'd1',
        name: 'X',
        cityCode: '34',
        districtCode: 'kadikoy',
        createdAt: DateTime.utc(2024),
      );
      final c = d.copyWith(name: 'Y');
      expect(c.cityCode, '34');
      expect(c.districtCode, 'kadikoy');
    });

    test('copyWith null geçince → cityCode null\'a düşer (sentinel)', () {
      final d = Dealer(
        id: 'd1',
        name: 'X',
        cityCode: '34',
        districtCode: 'kadikoy',
        createdAt: DateTime.utc(2024),
      );
      final c = d.copyWith(cityCode: null, districtCode: null);
      expect(c.cityCode, isNull);
      expect(c.districtCode, isNull);
    });
  });

  group('M6B — JobOfferPost model', () {
    test('Yeni alanlar opsiyonel; toInsertRow dual-write', () {
      const p = JobOfferPost(
        title: 'X',
        roleTitle: 'Y',
        city: 'İstanbul',
        district: 'Kadıköy',
        cityCode: '34',
        districtCode: 'kadikoy',
      );
      final row = p.toInsertRow('owner1');
      expect(row['city'], 'İstanbul');
      expect(row['district'], 'Kadıköy');
      expect(row['city_code'], '34');
      expect(row['district_code'], 'kadikoy');
    });

    test('fromRow city_code + district_code parse eder', () {
      final p = JobOfferPost.fromRow(<String, dynamic>{
        'id': 'p1',
        'title': 'X',
        'role_title': 'Y',
        'city_code': '34',
        'district_code': 'kadikoy',
        'is_active': true,
        'contact_preference': 'in_app',
      });
      expect(p.cityCode, '34');
      expect(p.districtCode, 'kadikoy');
    });
  });

  group('M6B — UI source-level checks', () {
    test('AddDealerScreen _area TextField yok, il+ilçe picker var', () {
      final src = File(
        'lib/features/dealers/screens/add_dealer_screen.dart',
      ).readAsStringSync();
      expect(src.contains('final _area = TextEditingController'), isFalse,
          reason: 'Eski area controller kaldırılmalı');
      expect(src.contains('LocationPickerField('), isTrue);
      expect(src.contains('_selectedProvince'), isTrue);
      expect(src.contains('_selectedDistrict'), isTrue);
      // Save'de dual-write
      expect(src.contains('cityCode: province?.code'), isTrue);
      expect(src.contains('districtCode: district?.code'), isTrue);
    });

    test('JobOfferFormScreen city/district TextField yok, picker var', () {
      final src = File(
        'lib/features/jobs/screens/job_offer_form_screen.dart',
      ).readAsStringSync();
      expect(src.contains('final _city = TextEditingController'), isFalse);
      expect(src.contains('final _district = TextEditingController'),
          isFalse);
      expect(src.contains('LocationPickerField('), isTrue);
      expect(src.contains('cityCode: province?.code'), isTrue);
      expect(src.contains('districtCode: district?.code'), isTrue);
      // İlçe picker il seçilmeden enable olmamalı.
      expect(src.contains('_selectedProvince != null'), isTrue);
    });
  });

  group('M6B — Dealer repository select clause city_code/district_code',
      () {
    test('SupabaseDealerRepository._dealerColumns yeni alanları içerir',
        () {
      final src = File(
        'lib/features/dealers/repositories/supabase_dealer_repository.dart',
      ).readAsStringSync();
      expect(src.contains('city_code, district_code'), isTrue);
      expect(src.contains("'city_code': dealer.cityCode"), isTrue);
      expect(src.contains("'district_code': dealer.districtCode"), isTrue);
    });
  });

  group('M6B — JobOffer repository select clause city_code/district_code',
      () {
    test('SupabaseJobOfferRepository._columns yeni alanları içerir', () {
      final src = File(
        'lib/features/jobs/repositories/supabase_job_offer_repository.dart',
      ).readAsStringSync();
      expect(src.contains('city_code, district_code'), isTrue);
    });
  });
}
