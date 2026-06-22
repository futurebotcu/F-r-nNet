// FırınNet Profile Self-Edit M3 — avatar upload servisi.
//
// Galeriden tek fotoğraf seç → Supabase storage `avatars/` bucket'a
// `<userId>/avatar_<timestamp>.<ext>` path'i ile yükle → public URL döndür.
//
// RLS path-prefix policy `(storage.foldername(name))[1] = auth.uid()::text`
// upload'u sadece owner'a izin verir. Public bucket olduğu için
// `getPublicUrl(path)` URL'i imzasız çalışır; ProfileHeader bu URL'i
// CachedNetworkImage ile render eder.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/services/media_limits.dart';

import '../../../core/config/app_config.dart';

class AvatarUploadResult {
  const AvatarUploadResult({required this.path, required this.publicUrl});

  final String path;
  final String publicUrl;
}

class AvatarUploadService {
  AvatarUploadService(this._client);

  final sb.SupabaseClient _client;

  static const String bucket = 'avatars';

  /// Galeriden tek fotoğraf seçtir. Kullanıcı vazgeçerse null.
  Future<XFile?> pickFromGallery() async {
    final picker = ImagePicker();
    return picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
  }

  /// Seçilen [file]'ı `avatars/<userId>/avatar_<ts>.<ext>` path'ine yükle.
  /// Path prefix'i `userId` ile başlar — RLS bunu zorunlu kılar.
  Future<AvatarUploadResult> upload({
    required String userId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    MediaLimits.ensureImageUnderLimit(bytes.lengthInBytes);
    final ext = _extensionOf(file).toLowerCase();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/avatar_$ts.$ext';
    final mime = _mimeForExt(ext);

    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(contentType: mime, upsert: false),
        );

    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
    return AvatarUploadResult(path: path, publicUrl: publicUrl);
  }

  /// M4 Polish — eski avatar URL'inden bucket-içi göreceli path çıkarır.
  /// Yalnız bizim `avatars/` bucket'ının public URL pattern'ini tanır;
  /// yabancı URL'ler için null döner. Owner-prefix kontrolü çağıran
  /// tarafa bırakılır (path'in ilk segmenti userId ile karşılaştırılır).
  ///
  /// Örnek URL:
  ///   `https://<host>/storage/v1/object/public/avatars/<userId>/avatar_<ts>.jpg`
  ///   → `<userId>/avatar_<ts>.jpg`
  static String? extractStoragePath(String? url) {
    if (url == null || url.isEmpty) return null;
    const marker = '/storage/v1/object/public/$bucket/';
    final i = url.indexOf(marker);
    if (i < 0) return null;
    final tail = url.substring(i + marker.length);
    if (tail.isEmpty) return null;
    // Path traversal koruması — `..` veya leading `/` reddedilir.
    if (tail.startsWith('/') || tail.contains('..')) return null;
    return tail;
  }

  /// M4 Polish — eski avatar dosyasını best-effort sil.
  ///
  /// Owner-prefix guard: path'in ilk klasör segmenti [userId] ile aynı
  /// olmalı. Aksi halde no-op (yabancı kullanıcının dosyasını silmeyiz —
  /// RLS zaten engellerdi, defansif).
  ///
  /// Başarısızlık (network/RLS) sessizce yutulur. Kullanıcı UX bozulmaz;
  /// orphan dosya gelecek cleanup job'una bırakılır.
  Future<void> deleteIfOwned({
    required String userId,
    required String? oldUrl,
  }) async {
    final path = extractStoragePath(oldUrl);
    if (path == null) return;
    final firstSegment = path.split('/').first;
    if (firstSegment != userId) {
      debugPrint(
        '[FirinNet][AvatarUpload] skip cleanup: path owner mismatch '
        '($firstSegment != $userId)',
      );
      return;
    }
    try {
      await _client.storage.from(bucket).remove(<String>[path]);
    } catch (e) {
      debugPrint('[FirinNet][AvatarUpload] cleanup failed: $e');
    }
  }

  static String _extensionOf(XFile file) {
    final name = file.name;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'jpg';
    return name.substring(dot + 1);
  }

  static String _mimeForExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

final avatarUploadServiceProvider = Provider<AvatarUploadService?>((ref) {
  if (!AppConfig.supabaseEnabled) return null;
  return AvatarUploadService(sb.Supabase.instance.client);
});
