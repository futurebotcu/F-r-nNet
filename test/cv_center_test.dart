// Unified Professional CV Center Sprint — entry_type + is_public model/mapping,
// visibility toggle davranışı, CV→İş Arıyorum prefill, CV merkez ekranı.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/models/public_profile_detail.dart';
import 'package:firin_defter/features/worker/models/worker_profile.dart';
import 'package:firin_defter/features/worker/repositories/local_worker_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CV Center — WorkerExperience entry_type + is_public', () {
    test('default: individual + public', () {
      const e = WorkerExperience(title: 'Usta');
      expect(e.entryType, 'individual');
      expect(e.isPublic, isTrue);
    });

    test('toInsertRow entry_type + is_public yazar', () {
      const e = WorkerExperience(
        title: 'Ticari geçmiş',
        entryType: 'commercial',
        isPublic: false,
      );
      final row = e.toInsertRow('u1');
      expect(row['entry_type'], 'commercial');
      expect(row['is_public'], false);
      expect(row['title'], 'Ticari geçmiş');
    });

    test('fromRow entry_type + is_public okur; eksikse default', () {
      final full = WorkerExperience.fromRow(<String, dynamic>{
        'id': 'x1',
        'title': 'Toptan',
        'entry_type': 'wholesaler',
        'is_public': false,
      });
      expect(full.entryType, 'wholesaler');
      expect(full.isPublic, isFalse);

      final legacy = WorkerExperience.fromRow(<String, dynamic>{
        'id': 'x2',
        'title': 'Eski kayıt',
      });
      expect(legacy.entryType, 'individual');
      expect(legacy.isPublic, isTrue);
    });
  });

  group('CV Center — PublicWorkerExperience parse', () {
    test('workplace + entry_type + is_public RPC alanları parse edilir', () {
      final e = PublicWorkerExperience.fromJson(<String, dynamic>{
        'id': 'p1',
        'title': 'Taş Fırın Ustası',
        'workplace': 'Konak Fırını',
        'entry_type': 'commercial',
        'is_public': true,
      });
      expect(e.workplace, 'Konak Fırını');
      expect(e.entryType, 'commercial');
      expect(e.isPublic, isTrue);
    });
  });

  group('CV Center — LocalWorkerRepository visibility toggle', () {
    test('setExperienceVisibility kaydın is_public\'ini değiştirir', () async {
      final repo = LocalWorkerRepository();
      final saved = await repo.addExperience(
        const WorkerExperience(title: 'Gizlenecek', isPublic: true),
      );
      await repo.setExperienceVisibility(saved.id!, false);
      final list = await repo.listMyExperiences();
      expect(list.single.isPublic, isFalse);
    });
  });

  group('CV Center — job_seek prefill (kaynak)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/worker/screens/job_seek_post_form_screen.dart')
          .readAsStringSync();
    });

    test('JobSeekPrefill sınıfı + prefill param + _applyPrefill var', () {
      expect(src.contains('class JobSeekPrefill'), isTrue);
      expect(src.contains('this.prefill'), isTrue);
      expect(src.contains('_applyPrefill'), isTrue);
    });

    test('prefill yalnız yeni ilanda (postId null) uygulanır', () {
      expect(
        src.contains('} else if (widget.prefill != null) {'),
        isTrue,
        reason: 'manuel/menü akışı (prefill null) boş form ile korunur',
      );
    });
  });

  group('CV Center — professional_cv_screen (kaynak)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/profile/screens/professional_cv_screen.dart')
          .readAsStringSync();
    });

    test('bio + son durum + CV kayıtları + görünürlük tek ekranda', () {
      expect(src.contains('cvBioLabel'), isTrue);
      expect(src.contains('_derivedStatus'), isTrue);
      expect(src.contains('cvRecordsLabel'), isTrue);
      expect(src.contains('setExperienceVisibility'), isTrue);
    });

    test('CV\'den İş Arıyorum: aktif varsa edit, yoksa prefill ile yeni', () {
      expect(src.contains('JobSeekPrefill'), isTrue);
      expect(src.contains('AppRoutes.jobSeekNew'), isTrue);
      expect(src.contains('/edit'), isTrue,
          reason: 'aktif ilan varsa duplicate yerine düzenleme');
      expect(src.contains('cvOpenJobSeekCta'), isTrue);
    });
  });

  group('CV Center — yeni string\'ler', () {
    test('CV string\'leri boş değil', () {
      expect(AppStrings.cvCenterTitle, isNotEmpty);
      expect(AppStrings.cvBioLabel, isNotEmpty);
      expect(AppStrings.cvRecordsLabel, isNotEmpty);
      expect(AppStrings.cvOpenJobSeekCta, isNotEmpty);
      expect(AppStrings.profileSectionCv, isNotEmpty);
      expect(AppStrings.profileCvEditCta, isNotEmpty);
      expect(AppStrings.cvEntryTypeLabels['commercial'], isNotEmpty);
    });
  });
}
