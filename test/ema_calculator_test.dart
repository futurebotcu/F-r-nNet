// Sprint 3.5 — EMACalculator unit tests.
//
// Donor (evan361425/flutter-pos-system, Apache-2.0) mantığı lift-as-is
// kopyalandı. Davranış: `weightFactor = 2/(length+1)`, `calculate`
// iterasyonla feed eder, `feed` carry==0 ise ilk değeri başlangıç
// olarak kabul eder, aksi halde ağırlıklı ortalama.

import 'package:firin_defter/core/util/ema_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EMACalculator', () {
    test('weightFactor = 2/(length+1)', () {
      const c20 = EMACalculator(20);
      // 2 / 21 ≈ 0.0952
      expect(c20.weightFactor, closeTo(2.0 / 21.0, 1e-9));

      const c10 = EMACalculator(10);
      expect(c10.weightFactor, closeTo(2.0 / 11.0, 1e-9));
    });

    test('boş seri → 0', () {
      const c = EMACalculator(20);
      expect(c.calculate(const <num>[]), 0);
    });

    test('tek değer → kendisi (carry==0 başlangıç)', () {
      const c = EMACalculator(20);
      expect(c.calculate(const [42]), 42);
      expect(c.calculate(const [3.14]), closeTo(3.14, 1e-9));
    });

    test('iki değer: ikinci ağırlıklı ortalama', () {
      const c = EMACalculator(20);
      // İlk: carry=0 → carry=10
      // İkinci: 20 * (2/21) + 10 * (19/21)
      final expected = 20.0 * (2.0 / 21.0) + 10.0 * (19.0 / 21.0);
      expect(c.calculate(const [10, 20]), closeTo(expected, 1e-9));
    });

    test('feed adımı bağımsız doğrudur', () {
      const c = EMACalculator(5);
      // carry=0 → return value
      expect(c.feed(7, 0), 7);
      // carry=10, value=20, length=5 → wf=2/6
      final expected = 20.0 * (2.0 / 6.0) + 10.0 * (1 - 2.0 / 6.0);
      expect(c.feed(20, 10), closeTo(expected, 1e-9));
    });

    test('uzun seri converges (sabit değer → o değere yaklaşır)',
        () {
      const c = EMACalculator(20);
      // 30 kere 100 → carry sonunda ≈ 100
      final result = c.calculate(List<num>.filled(30, 100));
      expect(result, closeTo(100, 0.01));
    });

    test('20 değer EMA bilinen hesapla eşleşir', () {
      const c = EMACalculator(20);
      // Seri: 1, 2, ..., 20 — manuel hesap için reduce ile EMA
      final values = List<num>.generate(20, (i) => i + 1);
      double expected = 0;
      for (final v in values) {
        expected = c.feed(v, expected);
      }
      expect(c.calculate(values), closeTo(expected, 1e-12));
    });
  });
}
