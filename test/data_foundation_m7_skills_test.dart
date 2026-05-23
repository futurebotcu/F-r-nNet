// FırınNet Data Foundation M7 — controlled worker skill invariant testleri.
//
// Karar:
//   * worker_profiles.skill_codes text[] nullable + array CHECK (cap 14 +
//     null element yok).
//   * Eski skills[] (text[] NOT NULL) KORUNUR (display fallback).
//   * UI: WorkerProfileScreen `_skills` TextField silindi; chip cluster
//     (_SkillsPicker) + bottom sheet (_SkillPickerSheet, 14 entry filter
//     chip multi-select + cap 10 UI limit + onayla CTA).
//   * Save: skill_codes (taxonomy) + skills (label fallback) dual-write.
//   * public_profile_detail RPC whitelist'e skill_codes eklendi.
//   * SocialProfilePage skill chip cluster effectiveSkills'ten beslenir.

import 'dart:io';

import 'package:firin_defter/core/data/firinnet_taxonomy.dart';
import 'package:firin_defter/features/profile/models/public_profile_detail.dart';
import 'package:firin_defter/features/worker/models/worker_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M7 — FirinnetTaxonomy.workerSkills', () {
    test('Map 14 entry içerir', () {
      expect(FirinnetTaxonomy.workerSkills.length, 14);
    });

    test('Beklenen code → label eşleşmeleri', () {
      expect(FirinnetTaxonomy.workerSkills['simit'], 'Simit');
      expect(FirinnetTaxonomy.workerSkills['eksi_maya'], 'Ekşi maya');
      expect(FirinnetTaxonomy.workerSkills['tas_firin'], 'Taş fırın');
      expect(FirinnetTaxonomy.workerSkills['gece_uretimi'], 'Gece üretimi');
      expect(FirinnetTaxonomy.workerSkills['hamur_yogurma'], 'Hamur yoğurma');
      expect(FirinnetTaxonomy.workerSkills['other'], 'Diğer');
    });

    test('workerSkillLabel / workerSkillCodeFromLabel round-trip', () {
      expect(FirinnetTaxonomy.workerSkillLabel('eksi_maya'), 'Ekşi maya');
      expect(FirinnetTaxonomy.workerSkillCodeFromLabel('Ekşi maya'),
          'eksi_maya');
      // Case-insensitive + trim
      expect(
          FirinnetTaxonomy.workerSkillCodeFromLabel('  taş fırın  '),
          'tas_firin');
    });

    test('isValidWorkerSkillCode — null/boş geçerli; bilinmeyen reddedilir',
        () {
      expect(FirinnetTaxonomy.isValidWorkerSkillCode(null), isTrue);
      expect(FirinnetTaxonomy.isValidWorkerSkillCode(''), isTrue);
      expect(FirinnetTaxonomy.isValidWorkerSkillCode('simit'), isTrue);
      expect(FirinnetTaxonomy.isValidWorkerSkillCode('unknown'), isFalse);
    });

    test('workerSkillCodes + Entries iterable', () {
      expect(FirinnetTaxonomy.workerSkillCodes, contains('simit'));
      expect(FirinnetTaxonomy.workerSkillEntries.length, 14);
    });
  });

  group('M7 — Migration source', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260524120000_worker_skill_codes.sql',
      ).readAsStringSync();
    });

    test('skill_codes text[] nullable eklendi', () {
      expect(
          sql.contains(
              'alter table public.worker_profiles\n  add column if not exists skill_codes text[]'),
          isTrue);
    });

    test('Array CHECK — cap 14 + null element yok', () {
      expect(sql.contains('worker_profiles_skill_codes_chk'), isTrue);
      expect(sql.contains('array_length(skill_codes, 1), 0) <= 14'), isTrue);
      expect(sql.contains('array_position(skill_codes, null) is null'),
          isTrue);
    });

    test('Eski skills[] kolonu DROP edilmiyor', () {
      // skill_codes drop edilebilir (yorum'da rollback); ana skills DROP yok.
      final dropPattern = RegExp(
        r'drop column skills(?:\s*;|\s+|$)',
        multiLine: true,
      );
      expect(dropPattern.hasMatch(sql), isFalse);
    });

    test('public_profile_detail RPC skill_codes whitelist\'te', () {
      expect(
          sql.contains('cities, city_codes, skills, skill_codes'),
          isTrue);
    });
  });

  group('M7 — WorkerProfile model dual-write', () {
    test('skillCodes default boş; default skills boş', () {
      const w = WorkerProfile();
      expect(w.skillCodes, isEmpty);
      expect(w.skills, isEmpty);
    });

    test('toInsertRow skill_codes ekler (boş değilse)', () {
      const w = WorkerProfile(skillCodes: <String>['simit', 'eksi_maya']);
      final row = w.toInsertRow('owner-id');
      expect(row['skill_codes'], <String>['simit', 'eksi_maya']);
    });

    test('toInsertRow boş skillCodes → field eklenmez', () {
      const w = WorkerProfile(skills: <String>['Simit']);
      final row = w.toInsertRow('owner-id');
      expect(row.containsKey('skill_codes'), isFalse);
      expect(row['skills'], <String>['Simit']);
    });

    test('fromRow skill_codes parse eder', () {
      final w = WorkerProfile.fromRow(<String, dynamic>{
        'id': 'p1',
        'owner_id': 'o1',
        'cities': <String>[],
        'skills': <String>['Simit'],
        'skill_codes': <String>['simit', 'eksi_maya'],
      });
      expect(w.skillCodes, <String>['simit', 'eksi_maya']);
      expect(w.skills, <String>['Simit']);
    });

    test('copyWith skillCodes değiştirir', () {
      const w = WorkerProfile(skillCodes: <String>['simit']);
      final c = w.copyWith(skillCodes: <String>['pasta', 'borek']);
      expect(c.skillCodes, <String>['pasta', 'borek']);
    });
  });

  group('M7 — PublicWorkerInfo.effectiveSkills', () {
    test('skillCodes varsa taxonomy label listesi (sıra korunur)', () {
      const w = PublicWorkerInfo(
        skills: <String>['Eski Text'],
        skillCodes: <String>['simit', 'eksi_maya'],
      );
      expect(w.effectiveSkills, <String>['Simit', 'Ekşi maya']);
    });

    test('skillCodes boşsa eski skills text fallback', () {
      const w = PublicWorkerInfo(
        skills: <String>['Taş fırın', 'Mayalama'],
      );
      expect(w.effectiveSkills, <String>['Taş fırın', 'Mayalama']);
    });

    test('Bilinmeyen code → code string\'i fallback olarak döner', () {
      const w = PublicWorkerInfo(
        skillCodes: <String>['unknown_skill'],
      );
      expect(w.effectiveSkills, <String>['unknown_skill']);
    });

    test('PublicWorkerInfo.fromJson skill_codes parse eder', () {
      final w = PublicWorkerInfo.fromJson(<String, dynamic>{
        'skills': <String>['Simit'],
        'skill_codes': <String>['simit'],
      });
      expect(w.skillCodes, <String>['simit']);
    });
  });

  group('M7 — Repository select clause', () {
    test('SupabaseWorkerRepository._profileColumns skill_codes içerir', () {
      final src = File(
        'lib/features/worker/repositories/supabase_worker_repository.dart',
      ).readAsStringSync();
      expect(src.contains('skill_codes'), isTrue);
    });
  });

  group('M7 — UI source-level', () {
    test('WorkerProfileScreen _skills TextField yok, _SkillsPicker var', () {
      final src = File(
        'lib/features/worker/screens/worker_profile_screen.dart',
      ).readAsStringSync();
      expect(src.contains('final _skills = TextEditingController'), isFalse,
          reason: 'Eski skills controller kaldırılmalı');
      expect(src.contains('_SkillsPicker'), isTrue);
      expect(src.contains('_SkillPickerSheet'), isTrue);
      // Save dual-write
      expect(src.contains('skillCodes: skillCodes'), isTrue);
      // Cap 10 selection limit
      expect(src.contains('_maxSkillSelection = 10'), isTrue);
    });

    test('SocialProfilePage skill chip cluster effectiveSkills kullanıyor',
        () {
      final src = File(
        'lib/features/social/profile/profile_page.dart',
      ).readAsStringSync();
      expect(src.contains('worker.effectiveSkills'), isTrue);
    });
  });
}
