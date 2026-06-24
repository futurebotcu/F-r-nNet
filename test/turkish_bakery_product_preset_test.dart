import 'package:firin_defter/features/bakery_panel/calculators/models/turkish_bakery_product_preset.dart';
import 'package:firin_defter/features/bakery_panel/calculators/services/dough_water_ratio_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TurkishBakeryProducts kataloğu', () {
    final all = TurkishBakeryProducts.all;

    test('beklenen ürünler katalogda var', () {
      final ids = all.map((p) => p.id).toSet();
      expect(
        ids,
        containsAll(<String>{
          'somun_250',
          'somun_300',
          'tam_bugday',
          'sandvic',
          'hamburger',
          'tost',
          'ramazan_pidesi',
          'pide',
          'lavas',
          'bazlama',
          'simit',
          'acma',
          'pogaca',
          'tuzlu_kurabiye',
          'manual',
        }),
      );
      expect(all.length, 15);
    });

    test('id\'ler tekildir', () {
      final ids = all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('tek bir manuel giriş vardır', () {
      expect(all.where((p) => p.isManual).length, 1);
      expect(TurkishBakeryProducts.manual.id, 'manual');
    });

    test('ürün değerleri pozitif ve mantıklı aralıkta (manuel hariç)', () {
      for (final p in all.where((p) => !p.isManual)) {
        expect(p.defaultDoughWeightG, greaterThan(0), reason: p.id);
        expect(p.defaultHydrationPct, inInclusiveRange(20, 120), reason: p.id);
        expect(p.defaultBakeLossPct, inInclusiveRange(0, 30), reason: p.id);
      }
    });

    test('manuel girişin varsayılanları 0 (alan doldurmaz)', () {
      final m = TurkishBakeryProducts.manual;
      expect(m.defaultDoughWeightG, 0);
      expect(m.defaultHydrationPct, 0);
      expect(m.defaultBakeLossPct, 0);
    });

    test(
      'kıvam grupları geçerli band taşır (stiff ≤ idealLow < idealHigh)',
      () {
        for (final g in TurkishBakeryProducts.hydrationGroups) {
          final b = g.hydrationBand;
          expect(b, isNotNull, reason: g.name);
          expect(b!.stiffBelow, lessThanOrEqualTo(b.idealLow), reason: g.name);
          expect(b.idealLow, lessThan(b.idealHigh), reason: g.name);
          expect(b.stiffBelow, greaterThan(0), reason: g.name);
        }
        expect(BakeryProductGroup.manual.hydrationBand, isNull);
      },
    );
  });

  group('Grup bandı → DoughWaterRatioCalculator eşiği (formül aynı)', () {
    DoughWaterRatioCalculator calcFor(BakeryProductGroup g) {
      final b = g.hydrationBand!;
      return DoughWaterRatioCalculator(
        stiffBelow: b.stiffBelow,
        lowWaterBelow: b.idealLow,
        idealBelow: b.idealHigh,
      );
    }

    test('simit grubunda %52 ideal sayılır', () {
      final r = calcFor(
        BakeryProductGroup.simit,
      ).evaluate(flourKg: 50, waterKg: 26); // %52
      expect(r.ratioPct, closeTo(52, 1e-9));
      expect(r.band, DoughHydrationBand.ideal);
    });

    test('genel/somun ekmekte %52 sert sayılır', () {
      final r = calcFor(
        BakeryProductGroup.genelEkmek,
      ).evaluate(flourKg: 50, waterKg: 26); // %52
      expect(r.band, DoughHydrationBand.tooStiff);
    });

    test('ürün seçilmezse genel varsayılan eşik korunur (60/65/70)', () {
      const def = DoughWaterRatioCalculator();
      // %67 → genel varsayılanda ideal (65–70).
      final r = def.evaluate(flourKg: 50, waterKg: 33.5);
      expect(r.ratioPct, closeTo(67, 1e-9));
      expect(r.band, DoughHydrationBand.ideal);
    });
  });
}
