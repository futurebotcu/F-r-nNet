/// FırınNet — medya upload boyut sınırları (PR-7, storage kota backstop'u).
///
/// Görseller pick anında zaten `image_picker` `maxWidth` + `imageQuality` ile
/// küçültülür (avatar 1024 / b2b 1280 / chat 1600 / feed-market-story 1920, q85).
/// Bu cap, pathological / manipüle edilmiş / aşırı büyük dosyalara karşı son
/// savunma katmanıdır → storage kota patlamasını engeller.
///
/// b2b ve chat servisleri kendi (5MB / 25MB) limitlerini zaten uygular; bu
/// helper avatar / feed / story / market akışlarına aynı backstop'u getirir.
class MediaLimits {
  const MediaLimits._();

  /// Görsel için üst sınır (resize sonrası bol marj; tipik q85/1920px ~1-2MB).
  static const int maxImageBytes = 5 * 1024 * 1024; // 5 MB

  /// Video için üst sınır (chat ile uyumlu).
  static const int maxVideoBytes = 25 * 1024 * 1024; // 25 MB

  /// Görsel byte uzunluğu sınırı aşıyorsa [MediaTooLargeException] fırlatır.
  static void ensureImageUnderLimit(int byteLength) {
    if (byteLength > maxImageBytes) {
      throw const MediaTooLargeException();
    }
  }
}

/// Yüklenmek istenen medya boyut sınırını aşıyor.
class MediaTooLargeException implements Exception {
  const MediaTooLargeException();

  @override
  String toString() =>
      'Görsel 5 MB sınırını aşıyor. Lütfen daha küçük bir görsel seçin.';
}
