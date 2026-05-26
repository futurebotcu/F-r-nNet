// FırınNet Data Foundation M6A — controlled location invariant testleri.
//
// Karar:
//   * profiles.city_code, worker_profiles.city_codes[],
//     worker_experiences.city_code, job_seek_posts.city_code text nullable
//     + regex CHECK (plaka 01..81).
//   * Eski city/cities text alanları KORUNUR (display fallback).
//   * UI: ProfileEditSheet + CreateProfile + WorkerProfile + JobSeekForm +
//     WorkerExperiences sheet TextField'lar LocationPickerField/picker'a
//     dönüştü.
//   * location_picker `lib/core/widgets/`'a taşındı (marketplace
//     consumer'ları import path'leri güncellendi).
//   * effectiveCity / effectiveCities helper'ları code → label çevirimi
//     yapar, yoksa eski text fallback.

import 'dart:io';

import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/models/public_profile_detail.dart';
import 'package:firin_defter/features/worker/models/worker_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M6A — Migration source', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260523180000_location_codes_m6a.sql',
      ).readAsStringSync();
    });

    test('4 yeni location kolonu eklendi (additive)', () {
      expect(
          sql.contains(
              'alter table public.profiles\n  add column if not exists city_code text'),
          isTrue);
      expect(
          sql.contains(
              'alter table public.worker_profiles\n  add column if not exists city_codes text[]'),
          isTrue);
      expect(
          sql.contains(
              'alter table public.worker_experiences\n  add column if not exists city_code text'),
          isTrue);
      expect(
          sql.contains(
              'alter table public.job_seek_posts\n  add column if not exists city_code text'),
          isTrue);
    });

    test('Regex CHECK constraint (plaka 01..81) 3 scalar kolonda', () {
      expect(sql.contains('profiles_city_code_chk'), isTrue);
      expect(sql.contains('worker_experiences_city_code_chk'), isTrue);
      expect(sql.contains('job_seek_posts_city_code_chk'), isTrue);
      // Regex pattern
      expect(
          sql.contains(r"~ '^(0[1-9]|[1-7][0-9]|8[01])$'"), isTrue,
          reason: 'Plaka regex pattern bulunmalı');
    });

    test('Array CHECK constraint worker_profiles.city_codes — uzunluk + null',
        () {
      expect(sql.contains('worker_profiles_city_codes_chk'), isTrue);
      expect(sql.contains('array_length(city_codes, 1)'), isTrue);
      expect(sql.contains('array_position(city_codes, null) is null'), isTrue);
    });

    test('Eski city/cities text kolonları DROP edilmiyor', () {
      expect(sql.contains('drop column city '), isFalse);
      expect(sql.contains('drop column cities'), isFalse);
    });

    test('public_profile_detail RPC city_code + city_codes whitelist\'te',
        () {
      expect(sql.contains('city, city_code'), isTrue,
          reason: 'profile select clause city_code\'u içermeli');
      expect(sql.contains('cities, city_codes, skills'), isTrue,
          reason: 'worker select clause city_codes\'ı içermeli');
      expect(sql.contains('city, city_code, start_date'), isTrue,
          reason: 'worker_experiences select city_code\'u içermeli');
    });
  });

  group('M6A — location_picker core/widgets\'a taşındı', () {
    test('Yeni path mevcut, eski path silinmiş', () {
      expect(
          File('lib/core/widgets/location_picker.dart').existsSync(),
          isTrue);
      expect(
          File('lib/features/marketplace/widgets/location_picker.dart')
              .existsSync(),
          isFalse);
    });

    test('Marketplace consumer\'ları yeni import path kullanıyor', () {
      final form = File(
        'lib/features/marketplace/screens/market_listing_form_screen.dart',
      ).readAsStringSync();
      expect(form.contains("'../../../core/widgets/location_picker.dart'"),
          isTrue);

      final sheet = File(
        'lib/features/marketplace/widgets/marketplace_filters_sheet.dart',
      ).readAsStringSync();
      expect(sheet.contains("'../../../core/widgets/location_picker.dart'"),
          isTrue);
    });
  });

  group('M6A — BakeryProfile.cityCode + copyWith sentinel', () {
    test('Yeni alan opsiyonel; default null', () {
      const p = BakeryProfile(
        displayName: 'H',
        accountType: AccountType.individual,
        city: 'İstanbul',
        roleBadge: 'X',
        email: '',
      );
      expect(p.cityCode, isNull);
    });

    test('copyWith default → cityCode korunur', () {
      const p = BakeryProfile(
        displayName: 'H',
        accountType: AccountType.individual,
        city: 'İstanbul',
        roleBadge: 'X',
        email: '',
        cityCode: '34',
      );
      final c = p.copyWith(roleBadge: 'Y');
      expect(c.cityCode, '34');
    });

    test('copyWith null geçince → cityCode null\'a düşer (sentinel)', () {
      const p = BakeryProfile(
        displayName: 'H',
        accountType: AccountType.individual,
        city: 'İstanbul',
        roleBadge: 'X',
        email: '',
        cityCode: '34',
      );
      final c = p.copyWith(cityCode: null);
      expect(c.cityCode, isNull);
    });
  });

  group('M6A — WorkerProfile.cityCodes[] + WorkerExperience.cityCode', () {
    test('WorkerProfile.cityCodes default boş liste', () {
      const w = WorkerProfile();
      expect(w.cityCodes, isEmpty);
    });

    test('WorkerProfile.toInsertRow city_codes ekler (boş değilse)', () {
      const w = WorkerProfile(cityCodes: <String>['34', '06']);
      final row = w.toInsertRow('owner-id');
      expect(row['city_codes'], <String>['34', '06']);
    });

    test('WorkerProfile.fromRow city_codes parse eder', () {
      final w = WorkerProfile.fromRow(<String, dynamic>{
        'id': 'p1',
        'owner_id': 'o1',
        'cities': <String>['İstanbul'],
        'city_codes': <String>['34'],
        'skills': <String>[],
      });
      expect(w.cityCodes, <String>['34']);
      expect(w.cities, <String>['İstanbul']);
    });

    test('WorkerExperience.cityCode + toInsertRow', () {
      const exp = WorkerExperience(
        title: 'Pastacı',
        city: 'İstanbul',
        cityCode: '34',
      );
      final row = exp.toInsertRow('o1');
      expect(row['city'], 'İstanbul');
      expect(row['city_code'], '34');
    });
  });

  group('M6A — PublicProfileHeader.effectiveCity', () {
    test('cityCode varsa TurkeyLocations label\'ı döndürür', () {
      const h = PublicProfileHeader(
        id: 'u1',
        city: 'Eski Text',
        cityCode: '34',
      );
      expect(h.effectiveCity, 'İstanbul');
    });

    test('cityCode yoksa eski city text fallback', () {
      const h = PublicProfileHeader(id: 'u1', city: 'Manisa');
      expect(h.effectiveCity, 'Manisa');
    });

    test('Bilinmeyen cityCode → eski text fallback', () {
      const h = PublicProfileHeader(
        id: 'u1',
        city: 'Fallback',
        cityCode: '99',
      );
      expect(h.effectiveCity, 'Fallback');
    });
  });

  group('M6A — PublicWorkerInfo.effectiveCities (multi)', () {
    test('cityCodes varsa label listesi (boş code-name düşürülmez)', () {
      const w = PublicWorkerInfo(
        cities: <String>['Eski Text'],
        cityCodes: <String>['34', '06'],
      );
      expect(w.effectiveCities, <String>['İstanbul', 'Ankara']);
    });

    test('cityCodes boşsa eski cities text fallback', () {
      const w = PublicWorkerInfo(
        cities: <String>['Konya', 'Manisa'],
        cityCodes: <String>[],
      );
      expect(w.effectiveCities, <String>['Konya', 'Manisa']);
    });
  });

  group('M6A — PublicWorkerExperience.effectiveCity', () {
    test('cityCode varsa label', () {
      final e = PublicWorkerExperience.fromJson(<String, dynamic>{
        'id': 'e1',
        'title': 'X',
        'city': 'Eski',
        'city_code': '42',
      });
      expect(e.effectiveCity, 'Konya');
    });

    test('cityCode yoksa eski city', () {
      final e = PublicWorkerExperience.fromJson(<String, dynamic>{
        'id': 'e1',
        'title': 'X',
        'city': 'Bursa',
      });
      expect(e.effectiveCity, 'Bursa');
    });
  });

  group('M6A — UI source-level checks', () {
    test('ProfileEditSheet LocationPickerField kullanıyor', () {
      final src = File(
        'lib/features/profile/widgets/profile_edit_sheet.dart',
      ).readAsStringSync();
      expect(src.contains('LocationPickerField('), isTrue);
      expect(src.contains('_selectedProvince'), isTrue);
      expect(src.contains('cityCode: province?.code'), isTrue);
    });

    test('CreateProfileScreen city TextField yok, picker var', () {
      final src = File(
        'lib/features/profile/screens/create_profile_screen.dart',
      ).readAsStringSync();
      expect(src.contains('_cityCtrl'), isFalse,
          reason: 'Eski city controller kaldırılmalı');
      expect(src.contains('LocationPickerField('), isTrue);
      expect(src.contains("'city_code': cityCode"), isTrue,
          reason: 'signUp metadata city_code göndermeli');
    });

    test('WorkerProfileScreen _cities TextField yok, _CitiesPicker var',
        () {
      final src = File(
        'lib/features/worker/screens/worker_profile_screen.dart',
      ).readAsStringSync();
      expect(src.contains('final _cities = TextEditingController'), isFalse);
      expect(src.contains('_CitiesPicker'), isTrue);
      expect(src.contains('cityCodes: cityCodes'), isTrue);
    });

    test('WorkerExperiencesScreen city TextField yok, picker var', () {
      final src = File(
        'lib/features/worker/screens/worker_experiences_screen.dart',
      ).readAsStringSync();
      expect(src.contains('final _city = TextEditingController'), isFalse);
      expect(src.contains('LocationPickerField('), isTrue);
      expect(src.contains('cityCode: province?.code'), isTrue);
    });

    test('JobSeekPostFormScreen city TextField yok, picker var', () {
      final src = File(
        'lib/features/worker/screens/job_seek_post_form_screen.dart',
      ).readAsStringSync();
      expect(src.contains('final _city = TextEditingController'), isFalse);
      expect(src.contains('LocationPickerField('), isTrue);
      expect(src.contains('cityCode: province?.code'), isTrue);
    });

    test('SocialProfilePage cities chip listesi effectiveCities kullanıyor',
        () {
      final src = File(
        'lib/features/social/profile/profile_page.dart',
      ).readAsStringSync();
      expect(src.contains('worker.effectiveCities'), isTrue);
    });

    test('ProfileHeader city satırı effectiveCity öncelikli', () {
      final src = File(
        'lib/features/social/profile/widgets/profile_header.dart',
      ).readAsStringSync();
      expect(src.contains('detail?.header.effectiveCity'), isTrue);
    });
  });
}
