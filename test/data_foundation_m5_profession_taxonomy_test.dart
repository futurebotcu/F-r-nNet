// FırınNet Data Foundation M5 — profession taxonomy invariant testleri.
//
// Karar:
//   * Tek doğruluk kaynağı `FirinnetTaxonomy.professions` (17 entry).
//   * RoleBadges + WorkerProfileScreen + JobSeekPostFormScreen + Create/
//     EditProfile hardcoded liste tüketmez; hepsi taxonomy'den beslenir.
//   * DB tarafında profession_badge_code yeni nullable + CHECK constraint;
//     eski profession_badge text kolonları korunur (display fallback).
//   * public_profile_detail RPC profession_badge_code döndürür; UI
//     effectiveProfessionBadge code öncelikli (label fallback).

import 'dart:io';

import 'package:firin_defter/core/data/firinnet_taxonomy.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/models/public_profile_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M5 — FirinnetTaxonomy.professions invariant', () {
    test('Map boş değil, 17 entry içerir', () {
      expect(FirinnetTaxonomy.professions, isNotEmpty);
      expect(FirinnetTaxonomy.professions.length, 17);
    });

    test('Beklenen code → label eşleşmeleri', () {
      expect(FirinnetTaxonomy.professions['usta_firinci'], 'Usta Fırıncı');
      expect(FirinnetTaxonomy.professions['mayaci'], 'Mayacı');
      expect(FirinnetTaxonomy.professions['hamurcu'], 'Hamurcu');
      expect(FirinnetTaxonomy.professions['firin_sahibi'], 'Fırın Sahibi');
      expect(FirinnetTaxonomy.professions['ekipman_satici'],
          'Ekipman Satıcısı');
      expect(FirinnetTaxonomy.professions['other'], 'Diğer');
    });

    test('professionLabel ve professionCodeFromLabel round-trip', () {
      expect(FirinnetTaxonomy.professionLabel('usta_firinci'),
          'Usta Fırıncı');
      expect(FirinnetTaxonomy.professionCodeFromLabel('Usta Fırıncı'),
          'usta_firinci');
      // Case-insensitive + trim
      expect(
          FirinnetTaxonomy.professionCodeFromLabel('  usta fırıncı  '),
          'usta_firinci');
    });

    test('isValidProfessionCode — null/boş geçerli; bilinmeyen reddedilir',
        () {
      expect(FirinnetTaxonomy.isValidProfessionCode(null), isTrue);
      expect(FirinnetTaxonomy.isValidProfessionCode(''), isTrue);
      expect(FirinnetTaxonomy.isValidProfessionCode('usta_firinci'), isTrue);
      expect(FirinnetTaxonomy.isValidProfessionCode('unknown_code'), isFalse);
    });

    test('professionCodesForAccountType — 3 rol subset listesi', () {
      final commercial =
          FirinnetTaxonomy.professionCodesForAccountType(AccountType.commercial);
      expect(commercial.contains('usta_firinci'), isTrue);
      expect(commercial.contains('firin_sahibi'), isTrue);
      expect(commercial.last, 'other');

      final individual =
          FirinnetTaxonomy.professionCodesForAccountType(AccountType.individual);
      expect(individual.contains('mayaci'), isTrue);
      expect(individual.contains('cirak'), isTrue);
      expect(individual.last, 'other');

      final wholesaler =
          FirinnetTaxonomy.professionCodesForAccountType(AccountType.wholesaler);
      expect(wholesaler.contains('toptanci'), isTrue);
      expect(wholesaler.contains('uncu'), isTrue);
      expect(wholesaler.last, 'other');
    });
  });

  group('M5 — Migration source whitelist + backfill + CHECK', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260523150000_profession_taxonomy_codes.sql',
      ).readAsStringSync();
    });

    test('3 yeni profession_badge_code kolonu eklendi', () {
      expect(
          sql.contains(
              'alter table public.profiles\n  add column if not exists profession_badge_code text'),
          isTrue);
      expect(
          sql.contains(
              'alter table public.worker_profiles\n  add column if not exists profession_badge_code text'),
          isTrue);
      expect(
          sql.contains(
              'alter table public.job_seek_posts\n  add column if not exists profession_badge_code text'),
          isTrue);
    });

    test('Backfill: label → code map içeriyor', () {
      expect(sql.contains("'usta fırıncı'"), isTrue);
      expect(sql.contains("'usta_firinci'"), isTrue);
      expect(sql.contains("'mayacı'"), isTrue);
      expect(sql.contains("'mayaci'"), isTrue);
      // Legacy fallbacks
      expect(sql.contains("'çalışan/usta'"), isTrue);
      expect(sql.contains("'pastacı'"), isTrue);
    });

    test('CHECK constraint allowed codes içerir (3 tabloda)', () {
      expect(
          sql.contains('profiles_profession_badge_code_chk'), isTrue);
      expect(
          sql.contains('worker_profiles_profession_badge_code_chk'),
          isTrue);
      expect(
          sql.contains('job_seek_posts_profession_badge_code_chk'),
          isTrue);
      // Sample allowed codes
      expect(sql.contains("'usta_firinci'"), isTrue);
      expect(sql.contains("'ekipman_satici'"), isTrue);
      expect(sql.contains("'other'"), isTrue);
    });

    test('public_profile_detail RPC profession_badge_code whitelist\'te', () {
      expect(
          sql.contains(
              'profession_badge, profession_badge_code, city'),
          isTrue,
          reason: 'profile select clause code\'u içermeli');
      expect(
          sql.contains(
              'profession_badge, profession_badge_code, experience_years'),
          isTrue,
          reason: 'worker select clause code\'u içermeli');
    });

    test('Eski profession_badge text kolonları DROP edilmiyor', () {
      expect(sql.contains('drop column profession_badge '), isFalse);
      expect(sql.toLowerCase().contains('drop column profession_badge\n'),
          isFalse);
    });
  });

  group('M5 — RoleBadges taxonomy delegasyonu', () {
    late String src;
    setUpAll(() {
      src = File('lib/core/constants/app_products.dart').readAsStringSync();
    });

    test('Hardcoded "Usta Fırıncı" literal listesi yok', () {
      // RoleBadges artık FirinnetTaxonomy.professions üzerinden derive.
      // Eski 'static const List<String> commercial = [...]' pattern'ı
      // kaldırıldı; sadece getter\'lar kaldı.
      expect(
          src.contains(
              'static const List<String> commercial = <String>['),
          isFalse,
          reason: 'commercial getter olmalı, const list değil');
      expect(src.contains('FirinnetTaxonomy.professions'), isTrue);
    });
  });

  group('M5 — UI: WorkerProfileScreen + JobSeekPostFormScreen', () {
    test('WorkerProfileScreen hardcoded _professions kullanmıyor', () {
      final src = File(
        'lib/features/worker/screens/worker_profile_screen.dart',
      ).readAsStringSync();
      expect(
          src.contains('static const List<String> _professions ='),
          isFalse);
      expect(src.contains('FirinnetTaxonomy.professionCodes'), isTrue);
      // Save'de dual-write (code + label).
      expect(src.contains('professionBadgeCode: code'), isTrue);
    });

    test('JobSeekPostFormScreen hardcoded _professions kullanmıyor', () {
      final src = File(
        'lib/features/worker/screens/job_seek_post_form_screen.dart',
      ).readAsStringSync();
      expect(
          src.contains('static const List<String> _professions ='),
          isFalse);
      expect(src.contains('FirinnetTaxonomy.professionCodes'), isTrue);
      expect(src.contains('professionBadgeCode: code'), isTrue);
    });

    test('CreateProfileScreen save\'de roleBadgeCode yazılıyor', () {
      final src = File(
        'lib/features/profile/screens/create_profile_screen.dart',
      ).readAsStringSync();
      expect(src.contains('FirinnetTaxonomy.professionCodeFromLabel'),
          isTrue);
      expect(src.contains('roleBadgeCode: badgeCode'), isTrue);
    });

    test('ProfileEditSheet taxonomy\'den besleniyor + chip section var',
        () {
      final src = File(
        'lib/features/profile/widgets/profile_edit_sheet.dart',
      ).readAsStringSync();
      expect(src.contains('FirinnetTaxonomy.professionEntries'), isTrue);
      expect(src.contains('profileEditProfessionLabel'), isTrue);
      // Save'de dual-write.
      expect(src.contains('roleBadgeCode: pCode'), isTrue);
      expect(src.contains('roleBadge: pLabel'), isTrue);
    });
  });

  group('M5 — PublicProfileDetail effectiveProfessionBadge code-aware', () {
    test('Worker code öncelikli → taxonomy label', () {
      final d = PublicProfileDetail.fromRpcJson(<String, dynamic>{
        'profile': {
          'id': 'u1',
          'profession_badge': 'Eski Label',
          'profession_badge_code': 'firin_sahibi',
        },
        'worker': {
          'profession_badge': 'Worker Eski Label',
          'profession_badge_code': 'usta_firinci',
        },
      });
      expect(d, isNotNull);
      expect(d!.effectiveProfessionBadge, 'Usta Fırıncı');
    });

    test('Worker code yoksa header code → taxonomy label', () {
      final d = PublicProfileDetail.fromRpcJson(<String, dynamic>{
        'profile': {
          'id': 'u1',
          'profession_badge_code': 'mayaci',
        },
        'worker': {
          // code yok, sadece label var
          'profession_badge': 'Worker Eski',
        },
      });
      expect(d!.effectiveProfessionBadge, 'Mayacı');
    });

    test('Code hiç yoksa eski label fallback (backward compat)', () {
      final d = PublicProfileDetail.fromRpcJson(<String, dynamic>{
        'profile': {
          'id': 'u1',
          'profession_badge': 'Eski Türkçe Label',
        },
      });
      expect(d!.effectiveProfessionBadge, 'Eski Türkçe Label');
    });

    test('Bilinmeyen code → taxonomy label null → label fallback', () {
      final d = PublicProfileDetail.fromRpcJson(<String, dynamic>{
        'profile': {
          'id': 'u1',
          'profession_badge': 'Fallback Label',
          'profession_badge_code': 'unknown_code',
        },
      });
      // unknown_code → null label → header label fallback
      expect(d!.effectiveProfessionBadge, 'Fallback Label');
    });
  });

  group('M5 — BakeryProfile.roleBadgeCode + copyWith sentinel', () {
    test('Yeni alan opsiyonel; default null', () {
      const p = BakeryProfile(
        displayName: 'H',
        accountType: AccountType.individual,
        city: 'İst',
        roleBadge: 'X',
        email: '',
      );
      expect(p.roleBadgeCode, isNull);
    });

    test('copyWith default → roleBadgeCode korunur', () {
      const p = BakeryProfile(
        displayName: 'H',
        accountType: AccountType.individual,
        city: 'İst',
        roleBadge: 'X',
        email: '',
        roleBadgeCode: 'usta_firinci',
      );
      final c = p.copyWith(city: 'Bursa');
      expect(c.roleBadgeCode, 'usta_firinci');
    });

    test('copyWith null geçince → roleBadgeCode null\'a düşer (sentinel)',
        () {
      const p = BakeryProfile(
        displayName: 'H',
        accountType: AccountType.individual,
        city: 'İst',
        roleBadge: 'X',
        email: '',
        roleBadgeCode: 'usta_firinci',
      );
      final c = p.copyWith(roleBadgeCode: null);
      expect(c.roleBadgeCode, isNull);
    });
  });
}
