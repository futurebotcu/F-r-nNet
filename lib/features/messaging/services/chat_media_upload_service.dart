// FırınNet Chat Media V1 — image upload servisi (generic + grup chat ortak).
//
// Galeri/kameradan resim seç → validate (≤10MB, jpg/png/webp) → PRIVATE
// `chat-media` bucket'a membership-gated path ile yükle → storage_path döndür.
// Render için signed URL [signedUrl] ile üretilir (bucket private).
//
// Path scheme (storage.objects RLS bunu parse eder):
//   conversations/{conversationId}/{ownerId}/m_{ts}.{ext}
//   groups/{groupId}/{ownerId}/m_{ts}.{ext}
//
// Mevcut paketler kullanılır (yeni dependency yok): image_picker, supabase.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';

/// Seçilen dosya 10 MB'ı aşarsa.
class ChatMediaTooLargeException implements Exception {
  const ChatMediaTooLargeException();
}

/// Seçilen dosya türü (uzantı/MIME) desteklenmiyorsa.
class ChatMediaUnsupportedException implements Exception {
  const ChatMediaUnsupportedException();
}

class ChatMediaUploadResult {
  const ChatMediaUploadResult({
    required this.storagePath,
    required this.sizeBytes,
    this.width,
    this.height,
  });

  final String storagePath;
  final int sizeBytes;
  final int? width;
  final int? height;

  /// `messages.attachments` / `group_messages.attachments` jsonb gövdesi.
  Map<String, dynamic> toAttachments() => <String, dynamic>{
        'media_type': 'image',
        'storage_path': storagePath,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'size_bytes': sizeBytes,
      };
}

class ChatMediaUploadService {
  ChatMediaUploadService(this._client);

  final sb.SupabaseClient _client;

  static const String bucket = 'chat-media';
  static const int maxBytes = 10 * 1024 * 1024; // 10 MB (image V1)
  static const Set<String> _allowedExt = {'jpg', 'jpeg', 'png', 'webp'};

  /// Galeri veya kameradan tek resim seçtir. Kullanıcı vazgeçerse null.
  Future<XFile?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    return picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
  }

  /// Boyut + tür doğrulaması. Geçersizse ilgili exception fırlatır.
  /// Client gerektirmez (static) — test edilebilir.
  static Future<int> validateFile(XFile file) async {
    final ext = _extensionOf(file.name).toLowerCase();
    if (!_allowedExt.contains(ext)) {
      throw const ChatMediaUnsupportedException();
    }
    final size = await file.length();
    if (size > maxBytes) {
      throw const ChatMediaTooLargeException();
    }
    return size;
  }

  Future<int> validate(XFile file) => validateFile(file);

  /// Seçilen [file]'ı membership-gated path'e yükler ve sonucu döndürür.
  /// [scope] 'conversations' | 'groups'; [scopeId] conversation/grup id.
  Future<ChatMediaUploadResult> upload({
    required String scope,
    required String scopeId,
    required String ownerId,
    required XFile file,
  }) async {
    final size = await validate(file);
    final bytes = await file.readAsBytes();
    final ext = _extensionOf(file.name).toLowerCase();
    final ts = DateTime.now().microsecondsSinceEpoch;
    final path = '$scope/$scopeId/$ownerId/m_$ts.$ext';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(
            contentType: _mimeForExt(ext),
            upsert: false,
          ),
        );
    return ChatMediaUploadResult(storagePath: path, sizeBytes: size);
  }

  /// Private bucket → render için signed URL üret (varsayılan 1 saat).
  Future<String> signedUrl(String storagePath, {int expiresIn = 3600}) {
    return _client.storage.from(bucket).createSignedUrl(storagePath, expiresIn);
  }

  static String _extensionOf(String name) {
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
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

final chatMediaUploadServiceProvider =
    Provider<ChatMediaUploadService?>((ref) {
  if (!AppConfig.supabaseEnabled) return null;
  return ChatMediaUploadService(sb.Supabase.instance.client);
});

/// Debug yardımcı — picker iptal/izin reddi loglar (UI banner ayrı).
void debugLogMediaPick(String stage, Object? e) {
  debugPrint('[FirinNet][ChatMedia] $stage: $e');
}
