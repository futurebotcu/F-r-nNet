import 'package:firin_defter/features/bakery_panel/calculators/services/morning_production_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = MorningProductionPlanner();

  group('MorningProductionPlanner', () {
    test('normal: 500 × 250g, fire yok → 77.5 kg un, 500 adet', () {
      final r = planner.plan(count: 500, pieceWeightG: 250);
      expect(r.totalDoughKg, 125);
      expect(r.flourKg, closeTo(77.5, 1e-9));
      expect(r.waterKg, closeTo(48.05, 1e-9));
      expect(r.yeastKg, closeTo(1.7825, 1e-9));
      expect(r.saltKg, closeTo(1.395, 1e-9));
      expect(r.sacks, closeTo(1.55, 1e-9));
      expect(r.expectedPiecesAfterWaste, 500);
      expect(r.capacityExceeded, isFalse);
    });

    test('fire %3 → beklenen adet düşer', () {
      final r = planner.plan(count: 500, pieceWeightG: 250, wastePct: 3);
      expect(r.expectedPiecesAfterWaste, 485);
    });

    test('kapasite aşımı uyarısı', () {
      final r = planner.plan(
        count: 500,
        pieceWeightG: 250,
        mixerCapacityKg: 100,
      );
      expect(r.capacityExceeded, isTrue);
    });

    test('0 değer → her şey 0, sonlu', () {
      final r = planner.plan(count: 0, pieceWeightG: 0);
      expect(r.flourKg, 0);
      expect(r.totalDoughKg, 0);
      expect(r.expectedPiecesAfterWaste, 0);
    });

    test('negatif değerler 0\'a normalize', () {
      final r = planner.plan(count: -100, pieceWeightG: -250, wastePct: -5);
      expect(r.flourKg, 0);
      expect(r.expectedPiecesAfterWaste, 0);
    });

    test('bölme riski: 0 gramaj → adet sonlu (0)', () {
      final r = planner.plan(count: 100, pieceWeightG: 0);
      expect(r.expectedPiecesAfterWaste.isFinite, isTrue);
      expect(r.expectedPiecesAfterWaste, 0);
    });

    test('çok büyük değer → sonuç sonlu', () {
      final r = planner.plan(count: 1e9, pieceWeightG: 1e6);
      expect(r.flourKg.isFinite, isTrue);
      expect(r.totalDoughKg.isFinite, isTrue);
    });
  });
}
