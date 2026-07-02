/// Türkçe'ye duyarlı metin yardımcıları.
///
/// Dart'ın varsayılan [String.toUpperCase] çağrısı Türkçe locale'i bilmez:
/// `i → I` (noktasız) ve `ı → ı` üretir; bu yüzden "için" → "IÇIN" gibi
/// hatalı sonuçlar çıkar. [trUpperCase] noktalı/noktasız i ayrımını koruyarak
/// doğru büyük harfe çevirir: `i → İ`, `ı → I`.
///
/// Yalnız gösterim amaçlıdır (ör. hesaplama sonucu etiketleri); değer/sayı
/// veya iş mantığı değiştirmez.
library;

/// Türkçe kurallarına göre büyük harfe çevirir.
///
/// Önce noktalı `i` → `İ` ve noktasız `ı` → `I` sabitlenir, ardından kalan
/// harfler standart [String.toUpperCase] ile çevrilir (ç→Ç, ş→Ş, ğ→Ğ, ö→Ö,
/// ü→Ü). Zaten büyük harfli bir metni tekrar geçirmek güvenlidir (idempotent).
String trUpperCase(String input) =>
    input.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
