// B2B Pazar — canlı görsel upload servisi (V1).
//
// Galeriden tek görsel seç → Supabase storage `market-media` (public) bucket'a
// `<uid>/b2b/<kind>_<ts>.<ext>` path'i ile yükle → public URL döndür.
//
// Mevcut app standardı yeniden kullanılır: `market-media` zaten public ve
// storage RLS policy'si `(storage.foldername(name))[1] = auth.uid()::text`
// ile yalnız sahibinin kendi prefix'ine yazmasına izin verir → path'in ilk
// segmenti uid olmalı. Video YOK. jpg/png/webp; makul boyut (image_picker
// maxWidth + quality ile küçültülür).
//
// Local/guest/no-config: bu servis sağlanmaz (provider null) → form mock/no-op
// davranır, Supabase'e yazılmaz.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';

/// Yüklenecek görselin türü → path/folder ayrımı.
enum B2bMediaKind { shopLogo, shopCover, product, campaign }

extension on B2bMediaKind {
  String get slug {
    switch (this) {
      case B2bMediaKind.shopLogo:
        return 'shop-logo';
      case B2bMediaKind.shopCover:
        return 'shop-cover';
      case B2bMediaKind.product:
        return 'product';
      case B2bMediaKind.campaign:
        return 'campaign';
    }
  }
}

class B2bMediaUploadService {
  B2bMediaUploadService(this._client);

  final sb.SupabaseClient _client;

  static const String bucket = 'market-media';
  static const int maxBytes = 5 * 1024 * 1024; // 5MB

  /// Galeriden tek görsel seçtir. Vazgeçilirse null.
  Future<XFile?> pickFromGallery() async {
    final picker = ImagePicker();
    return picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
  }

  /// Storage path'i kur: `<uid>/b2b/<kind>_<ts>.<ext>`. RLS ilk segment=uid.
  static String buildPath({
    required String userId,
    required B2bMediaKind kind,
    required String ext,
    required int timestampMs,
  }) {
    final safeExt = ext.toLowerCase();
    return '$userId/b2b/${kind.slug}_$timestampMs.$safeExt';
  }

  /// Seçilen [file]'ı yükle; public URL döndür. Boyut/aşırı büyük reddedilir.
  Future<String> upload({
    required String userId,
    required B2bMediaKind kind,
    required XFile file,
    int? timestampMs,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > maxBytes) {
      throw const B2bMediaTooLargeException();
    }
    final ext = _extensionOf(file);
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final path = buildPath(
      userId: userId,
      kind: kind,
      ext: ext,
      timestampMs: ts,
    );
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(
            contentType: _mimeForExt(ext),
            upsert: false,
          ),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Public URL'den bucket-içi göreceli path çıkarır (cleanup için).
  static String? extractStoragePath(String? url) {
    if (url == null || url.isEmpty) return null;
    const marker = '/storage/v1/object/public/$bucket/';
    final i = url.indexOf(marker);
    if (i < 0) return null;
    final tail = url.substring(i + marker.length);
    if (tail.isEmpty || tail.startsWith('/') || tail.contains('..')) {
      return null;
    }
    return tail;
  }

  /// Eski görseli best-effort sil (owner-prefix guard). Hata yutulur.
  Future<void> deleteIfOwned({
    required String userId,
    required String? oldUrl,
  }) async {
    final path = extractStoragePath(oldUrl);
    if (path == null) return;
    if (path.split('/').first != userId) return;
    try {
      await _client.storage.from(bucket).remove(<String>[path]);
    } catch (e) {
      debugPrint('[FirinNet][B2bMediaUpload] cleanup failed: $e');
    }
  }

  static String _extensionOf(XFile file) {
    final name = file.name;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'jpg';
    final ext = name.substring(dot + 1).toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp'};
    return allowed.contains(ext) ? ext : 'jpg';
  }

  static String _mimeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

class B2bMediaTooLargeException implements Exception {
  const B2bMediaTooLargeException();
  @override
  String toString() => 'Görsel 5MB sınırını aşıyor.';
}

/// Supabase hazırsa servis; değilse null (guest/Local → upload yok).
final b2bMediaUploadServiceProvider =
    Provider<B2bMediaUploadService?>((ref) {
  if (!AppConfig.supabaseEnabled) return null;
  return B2bMediaUploadService(sb.Supabase.instance.client);
});
