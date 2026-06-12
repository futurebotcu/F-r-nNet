// FırınNet Perf — chat-media signed URL cache.
//
// Sorun: sohbet/grup her açılışında her medya mesajı için createSignedUrl
// çağrılıyordu; aynı resim her açılışta yeniden imzalanıyor (storage maliyeti
// + açılış gecikmesi). Bu cache aynı oturumda aynı storage_path'i yeniden
// imzalamaz.
//
// Güvenlik: private bucket korunur — public URL'ye DÖNÜLMEZ, yalnız signed
// URL cache'lenir. TTL signed-URL ömründen KISA (erken yeniden imzalama →
// expired URL servis edilmez). Logout/kullanıcı değişiminde [clear].

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _Entry {
  _Entry(this.url, this.expiresAtMs);
  final String url;
  final int expiresAtMs;
}

class ChatMediaSignedUrlCache {
  ChatMediaSignedUrlCache._();
  static final ChatMediaSignedUrlCache instance = ChatMediaSignedUrlCache._();

  /// Signed URL geçerlilik süresi (saniye) — storage'a bu süreyle imzalatılır.
  static const int signExpiresSeconds = 3600;

  /// Cache TTL (ms) — signed URL ömründen KISA; URL gerçekten expire olmadan
  /// yeniden imzalanır (saat - 10 dk emniyet payı).
  static const int _ttlMs = (signExpiresSeconds - 600) * 1000;

  /// Bellek koruması — makul üst sınır; aşılırsa en eski temizlenir.
  static const int _maxEntries = 500;

  final Map<String, _Entry> _cache = <String, _Entry>{};

  /// Test/saat enjeksiyonu için; prod'da [DateTime.now] kullanılır.
  int Function() nowMs = () => DateTime.now().millisecondsSinceEpoch;

  /// Cache hit/miss sayaçları (before/after ölçümü + test için).
  int hits = 0;
  int misses = 0;

  /// [storagePath] için geçerli signed URL döner. Cache'te taze varsa onu,
  /// yoksa [sign] ile yeniden imzalar ve cache'ler. Hata olursa rethrow.
  Future<String> resolve(
    String storagePath,
    Future<String> Function(String path) sign,
  ) async {
    final now = nowMs();
    final cached = _cache[storagePath];
    if (cached != null && cached.expiresAtMs > now) {
      hits++;
      return cached.url;
    }
    misses++;
    final url = await sign(storagePath);
    if (_cache.length >= _maxEntries) {
      // En eski (en küçük expiresAt) girişi at.
      String? oldestKey;
      int oldest = 1 << 62;
      for (final e in _cache.entries) {
        if (e.value.expiresAtMs < oldest) {
          oldest = e.value.expiresAtMs;
          oldestKey = e.key;
        }
      }
      if (oldestKey != null) _cache.remove(oldestKey);
    }
    _cache[storagePath] = _Entry(url, now + _ttlMs);
    return url;
  }

  /// Supabase storage kısayolu — `resolve` ile birlikte yaygın kullanım.
  Future<String> resolveWith(
    sb.SupabaseClient client,
    String bucket,
    String storagePath,
  ) {
    return resolve(
      storagePath,
      (p) => client.storage.from(bucket).createSignedUrl(p, signExpiresSeconds),
    );
  }

  /// Logout / kullanıcı değişiminde çağrılır (bayat URL'ler taşınmasın).
  void clear() {
    _cache.clear();
    hits = 0;
    misses = 0;
  }

  int get size => _cache.length;
}
