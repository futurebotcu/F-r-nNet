/// Hesaplama servisleri için ortak güvenli normalizasyon yardımcıları.
///
/// Tüm modüller bu fonksiyonları kullanarak NaN / Infinity / negatif /
/// sıfıra bölme durumlarını tek noktada eler. Böylece hiçbir servis sonsuz
/// ya da tanımsız değer üretmez.
library;

/// Negatifi ve NaN'ı 0'a indirger (miktar/fiyat gibi non-negatif girişler).
double nonNeg(double v) => (v.isNaN || v < 0) ? 0.0 : v;

/// Değeri en az [min] yapar (NaN da [min]'e çekilir).
double atLeast(double v, double min) => (v.isNaN || v < min) ? min : v;

/// Güvenli bölme — payda 0 / NaN ise 0 döner; sonuç daima sonludur.
double safeDiv(double a, double b) {
  if (a.isNaN || b.isNaN || b == 0) return 0.0;
  final r = a / b;
  return r.isFinite ? r : 0.0;
}

/// Bir double'ı her durumda sonlu yapar (NaN/Infinity → 0).
double finiteOrZero(double v) => v.isFinite ? v : 0.0;

/// Sıcaklık gibi negatif olabilen değerleri yalnız NaN/Infinity'den korur.
double finiteTemp(double v) => v.isFinite ? v : 0.0;
