// Adapted from evan361425/flutter-pos-system
// commit 354e0417a3f3c85789084d88ed6ecd2e28d7d73d, Apache-2.0.
// See THIRD_PARTY_LICENSES.md.
//
// Lift-as-is from `lib/helpers/analysis/ema_calculator.dart` (Sprint 3.5,
// 2026-05-24). Donor mantığı birebir korunur — sade EMA hesaplama
// helper'ı, FırınNet'in domain bağlamından bağımsız bir pure-math
// yardımcısıdır. Yorumlar İngilizce'den Türkçe'ye çevrildi; satır
// sayısı/davranış değişmedi.

/// Üstel hareketli ortalama (EMA) hesaplayıcı.
///
/// Sermaye: `weightFactor = 2 / (length + 1)`. Klasik EMA formülü;
/// son değer daha ağırlıklı, eski değerler exponential decay ile sönümlenir.
/// İlk değerle `carry` başlatılır (donor: `if (carry == 0) return value`),
/// sonraki değerler ağırlıklı ortalama olarak feed edilir.
class EMACalculator {
  final double weightFactor;

  final int length;

  const EMACalculator(this.length) : weightFactor = 2 / (length + 1);

  /// Tüm seriyi soldan sağa feed eder; son carry değerini döner.
  double calculate(Iterable<num> data) {
    double carry = 0;

    for (final value in data) {
      carry = feed(value, carry);
    }

    return carry;
  }

  /// Tek değer adımı. `carry == 0` ise serinin ilk değeri olarak kabul
  /// edilir ve doğrudan döner; aksi halde ağırlıklı ortalama hesaplanır.
  double feed(num value, double carry) {
    if (carry == 0) {
      return value.toDouble();
    }

    return value * weightFactor + carry * (1 - weightFactor);
  }
}
