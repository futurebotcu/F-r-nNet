// FırınNet Data Foundation M8 — controlled job_offer_posts code invariant
// testleri.
//
// Karar:
//   * job_offer_posts.role_code / shift_code / experience_code text
//     nullable + 3 CHECK (17 profession / 4 shift / 4 experience bracket).
//   * Eski role_title (NOT NULL) + shift_type + experience_required text
//     KORUNUR (display fallback + backward compat).
//   * Taxonomy: shifts (4) + experienceBrackets (4) FirinnetTaxonomy'ye
//     eklendi.
//   * UI: JobOfferFormScreen 3 TextField → 3 chip cluster (single-select).
//     Save dual-write (label + code).
//   * Display: _JobOfferCard _formatExperience + _formatShift code-aware.

import 'dart:io';

import 'package:firin_defter/core/data/firinnet_taxonomy.dart';
import 'package:firin_defter/features/jobs/models/job_offer_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M8 — Taxonomy shifts', () {
    test('4 entry: gunduz/gece/vardiyali/esnek', () {
      expect(FirinnetTaxonomy.shifts.keys.toSet(),
          {'gunduz', 'gece', 'vardiyali', 'esnek'});
      expect(FirinnetTaxonomy.shifts['gunduz'], 'Gündüz');
      expect(FirinnetTaxonomy.shifts['vardiyali'], 'Vardiyalı');
    });

    test('shiftLabel ve isValidShiftCode', () {
      expect(FirinnetTaxonomy.shiftLabel('gece'), 'Gece');
      expect(FirinnetTaxonomy.shiftLabel('unknown'), isNull);
      expect(FirinnetTaxonomy.isValidShiftCode(null), isTrue);
      expect(FirinnetTaxonomy.isValidShiftCode('gunduz'), isTrue);
      expect(FirinnetTaxonomy.isValidShiftCode('unknown'), isFalse);
    });
  });

  group('M8 — Taxonomy experienceBrackets', () {
    test('4 entry: none/0_2/3_5/5_plus', () {
      expect(FirinnetTaxonomy.experienceBrackets.keys.toSet(),
          {'none', '0_2', '3_5', '5_plus'});
      expect(FirinnetTaxonomy.experienceBrackets['none'], 'Şart değil');
      expect(FirinnetTaxonomy.experienceBrackets['5_plus'], '5+ yıl');
    });

    test('experienceLabel ve isValidExperienceCode', () {
      expect(FirinnetTaxonomy.experienceLabel('3_5'), '3-5 yıl');
      expect(FirinnetTaxonomy.experienceLabel('unknown'), isNull);
      expect(FirinnetTaxonomy.isValidExperienceCode('none'), isTrue);
      expect(FirinnetTaxonomy.isValidExperienceCode('unknown'), isFalse);
    });
  });

  group('M8 — Migration source', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260524150000_job_offer_codes_m8.sql',
      ).readAsStringSync();
    });

    test('3 yeni nullable code kolonu (additive)', () {
      expect(
          sql.contains(
              'add column if not exists role_code text,\n  add column if not exists shift_code text,\n  add column if not exists experience_code text'),
          isTrue);
    });

    test('role_code CHECK: 17 profession code', () {
      expect(sql.contains('job_offer_posts_role_code_chk'), isTrue);
      // Spot check
      expect(sql.contains("'usta_firinci'"), isTrue);
      expect(sql.contains("'ekipman_satici'"), isTrue);
      expect(sql.contains("'other'"), isTrue);
    });

    test('shift_code CHECK: 4 entry', () {
      expect(sql.contains('job_offer_posts_shift_code_chk'), isTrue);
      expect(
          sql.contains(
              "shift_code in ('gunduz', 'gece', 'vardiyali', 'esnek')"),
          isTrue);
    });

    test('experience_code CHECK: 4 bracket', () {
      expect(sql.contains('job_offer_posts_experience_code_chk'), isTrue);
      expect(
          sql.contains(
              "experience_code in ('none', '0_2', '3_5', '5_plus')"),
          isTrue);
    });

    test('Eski role_title/shift_type/experience_required korunur', () {
      // *_code drop edilebilir rollback'te; ana text kolonlar DROP yok.
      final dropPattern = RegExp(
        r'drop column (role_title|shift_type|experience_required)(?:\s*;|\s+|$)',
        multiLine: true,
      );
      expect(dropPattern.hasMatch(sql), isFalse);
    });
  });

  group('M8 — JobOfferPost model dual-write', () {
    test('3 yeni code alanı default null', () {
      const p = JobOfferPost(title: 'X', roleTitle: 'Y');
      expect(p.roleCode, isNull);
      expect(p.shiftCode, isNull);
      expect(p.experienceCode, isNull);
    });

    test('toInsertRow code\'ları yazar', () {
      const p = JobOfferPost(
        title: 'X',
        roleTitle: 'Usta Fırıncı',
        roleCode: 'usta_firinci',
        shiftType: 'Gece',
        shiftCode: 'gece',
        experienceRequired: '3-5 yıl',
        experienceCode: '3_5',
      );
      final row = p.toInsertRow('owner-id');
      expect(row['role_code'], 'usta_firinci');
      expect(row['shift_code'], 'gece');
      expect(row['experience_code'], '3_5');
      // Eski label'lar da yazılır (dual-write)
      expect(row['role_title'], 'Usta Fırıncı');
      expect(row['shift_type'], 'Gece');
      expect(row['experience_required'], '3-5 yıl');
    });

    test('toInsertRow boş code → field eklenmez', () {
      const p = JobOfferPost(title: 'X', roleTitle: 'Y');
      final row = p.toInsertRow('owner-id');
      expect(row.containsKey('role_code'), isFalse);
      expect(row.containsKey('shift_code'), isFalse);
      expect(row.containsKey('experience_code'), isFalse);
    });

    test('fromRow code\'ları parse eder', () {
      final p = JobOfferPost.fromRow(<String, dynamic>{
        'id': 'p1',
        'title': 'X',
        'role_title': 'Usta Fırıncı',
        'role_code': 'usta_firinci',
        'shift_code': 'gunduz',
        'experience_code': '5_plus',
        'is_active': true,
        'contact_preference': 'in_app',
      });
      expect(p.roleCode, 'usta_firinci');
      expect(p.shiftCode, 'gunduz');
      expect(p.experienceCode, '5_plus');
    });

    test('copyWith code\'ları değiştirir', () {
      const p = JobOfferPost(title: 'X', roleTitle: 'Y', roleCode: 'cirak');
      final c = p.copyWith(
        roleCode: 'usta_firinci',
        shiftCode: 'esnek',
        experienceCode: 'none',
      );
      expect(c.roleCode, 'usta_firinci');
      expect(c.shiftCode, 'esnek');
      expect(c.experienceCode, 'none');
    });
  });

  group('M8 — Repository select clause', () {
    test('SupabaseJobOfferRepository._columns 3 yeni code alanı', () {
      final src = File(
        'lib/features/jobs/repositories/supabase_job_offer_repository.dart',
      ).readAsStringSync();
      expect(src.contains('role_title, role_code'), isTrue);
      expect(src.contains('shift_type, shift_code'), isTrue);
      expect(src.contains('experience_required, experience_code'), isTrue);
    });
  });

  group('M8 — UI source-level', () {
    test('JobOfferFormScreen 3 TextField yok, _CodeChipPicker var', () {
      final src = File(
        'lib/features/jobs/screens/job_offer_form_screen.dart',
      ).readAsStringSync();
      expect(src.contains('final _roleTitle = TextEditingController'), isFalse,
          reason: 'Eski roleTitle controller kaldırılmalı');
      expect(src.contains('final _shiftType = TextEditingController'), isFalse);
      expect(src.contains('final _experience = TextEditingController'),
          isFalse);
      expect(src.contains('_CodeChipPicker'), isTrue);
      // 3 chip picker entry kaynağı taxonomy
      expect(src.contains('FirinnetTaxonomy.professionEntries'), isTrue);
      expect(src.contains('FirinnetTaxonomy.shiftEntries'), isTrue);
      expect(src.contains('FirinnetTaxonomy.experienceEntries'), isTrue);
      // Save dual-write
      expect(src.contains('roleCode: _roleCode'), isTrue);
      expect(src.contains('shiftCode: _shiftCode'), isTrue);
      expect(src.contains('experienceCode: _experienceCode'), isTrue);
    });

    test('jobs_screen _JobOfferCard code-aware display getter\'ları', () {
      final src = File(
        'lib/features/jobs/screens/jobs_screen.dart',
      ).readAsStringSync();
      expect(src.contains('_formatShift()'), isTrue);
      expect(src.contains('FirinnetTaxonomy.experienceLabel'), isTrue);
      expect(src.contains('FirinnetTaxonomy.shiftLabel'), isTrue);
      // shift artık taxonomy üzerinden çiziliyor (eski direkt offer.shiftType
      // kullanımı kaldırıldı).
      expect(src.contains('shift: _formatShift()'), isTrue);
    });
  });
}
