// Social UI Polish Sprint 1 - PostType accent renk mapping refactor testi.
//
// supply -> brandGray
// equipment -> textSecondary
// job -> success
// production / question / groupHighlight sabit.

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostType.accent - Social UI Polish Sprint 1', () {
    test('supply -> brandGray (tedarik)', () {
      expect(PostType.supply.accent, AppColors.brandGray);
    });

    test('equipment -> textSecondary (muted)', () {
      expect(PostType.equipment.accent, AppColors.textSecondary);
    });

    test('job -> success', () {
      expect(PostType.job.accent, AppColors.success);
    });

    test('production -> brandLemonPressed (regression: degismemis)', () {
      expect(PostType.production.accent, AppColors.brandLemonPressed);
    });

    test('question -> info (regression: degismemis)', () {
      expect(PostType.question.accent, AppColors.info);
    });

    test('groupHighlight -> brandLemonPressed (regression: degismemis)',
        () {
      expect(PostType.groupHighlight.accent, AppColors.brandLemonPressed);
    });
  });

  group('PostType.label + icon sanity check', () {
    test('Tum type\'lar non-empty label dondurur', () {
      for (final t in PostType.values) {
        expect(t.label, isNotEmpty);
      }
    });

    test('persistKey round-trip - fromPersistKey idempotent', () {
      for (final t in PostType.values) {
        expect(PostTypeMeta.fromPersistKey(t.persistKey), t);
      }
    });
  });
}
