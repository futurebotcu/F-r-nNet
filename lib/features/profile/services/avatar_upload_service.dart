// FırınNet Profile Self-Edit M3 — avatar upload servisi.
//
// Galeriden tek fotoğraf seç → Supabase storage `avatars/` bucket'a
// `<userId>/avatar_<timestamp>.<ext>` path'i ile yükle → public URL döndür.
//
// RLS path-prefix policy `(storage.foldername(name))[1] = auth.uid()::text`
// upload'u sadece owner'a izin verir. Public bucket olduğu için
// `getPublicUrl(path)` URL'i imzasız çalışır; ProfileHeader bu URL'i
// CachedNetworkImage ile render eder.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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
    final ext = _extensionOf(file).toLowerCase();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/avatar_$ts.$ext';
    final mime = _mimeForExt(ext);

    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(
            contentType: mime,
            upsert: false,
          ),
        );

    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
    return AvatarUploadResult(path: path, publicUrl: publicUrl);
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
