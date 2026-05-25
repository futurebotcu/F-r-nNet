// Social UI Polish Sprint 1 — PostType accent renk mapping refactor testi.
//
// supply → copper (eski: success)
// equipment → textSecondary (eski: copper)
// job → success (eski: softGold)
// production / question / groupHighlight sabit.

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostType.accent — Social UI Polish Sprint 1', () {
    test('supply → copper (tedarik)', () {
      expect(PostType.supply.accent, AppColors.copper);
    });

    test('equipment → textSecondary (muted)', () {
      expect(PostType.equipment.accent, AppColors.textSecondary);
    });

    test('job → success', () {
      expect(PostType.job.accent, AppColors.success);
    });

    test('production → softGold (regression: değişmemiş)', () {
      expect(PostType.production.accent, AppColors.softGold);
    });

    test('question → info (regression: değişmemiş)', () {
      expect(PostType.question.accent, AppColors.info);
    });

    test('groupHighlight → copper (regression: değişmemiş)', () {
      expect(PostType.groupHighlight.accent, AppColors.copper);
    });
  });

  group('PostType.label + icon sanity check', () {
    test('Tüm type\'lar non-empty label döndürür', () {
      for (final t in PostType.values) {
        expect(t.label, isNotEmpty);
      }
    });

    test('persistKey round-trip — fromPersistKey idempotent', () {
      for (final t in PostType.values) {
        expect(PostTypeMeta.fromPersistKey(t.persistKey), t);
      }
    });
  });
}
