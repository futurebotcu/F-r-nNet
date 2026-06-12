// FırınNet Chat Media V1 — media upload servisi (generic + grup chat ortak).
//
// V1: galeri/kameradan resim → validate (≤10MB, jpg/png/webp).
// V1.1: galeri/kameradan video → validate (≤25MB, mp4/mov).
// PRIVATE `chat-media` bucket'a membership-gated path ile yükle →
// storage_path döndür. Render için signed URL [signedUrl] ile üretilir.
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
import 'chat_media_signed_url_cache.dart';

/// Seçilen dosya boyut sınırını aşarsa (image 10 MB / video 25 MB).
class ChatMediaTooLargeException implements Exception {
  const ChatMediaTooLargeException();
}

/// Seçilen dosya türü (uzantı/MIME) desteklenmiyorsa.
class ChatMediaUnsupportedException implements Exception {
  const ChatMediaUnsupportedException();
}

/// V1.1 — sheet'ten seçilen medya türü. Validation/limit/MIME ve
/// attachments.media_type bu enum'dan türetilir.
enum ChatMediaKind { image, video }

class ChatMediaUploadResult {
  const ChatMediaUploadResult({
    required this.storagePath,
    required this.sizeBytes,
    this.mediaType = 'image',
    this.width,
    this.height,
  });

  final String storagePath;
  final int sizeBytes;

  /// `'image'` | `'video'` — attachments.media_type değeri.
  final String mediaType;
  final int? width;
  final int? height;

  /// `messages.attachments` / `group_messages.attachments` jsonb gövdesi.
  Map<String, dynamic> toAttachments() => <String, dynamic>{
        'media_type': mediaType,
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
  // V1.1 — video limiti 25 MB: free-tier storage + mobil veri dengesi;
  // 50 MB upload süresi/battery açısından riskli, duration kontrolü P2.
  static const int maxVideoBytes = 25 * 1024 * 1024;
  static const Set<String> _allowedExt = {'jpg', 'jpeg', 'png', 'webp'};
  static const Set<String> _allowedVideoExt = {'mp4', 'mov'};

  /// Galeri veya kameradan tek resim seçtir. Kullanıcı vazgeçerse null.
  Future<XFile?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    return picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
  }

  /// V1.1 — galeri veya kameradan tek video seçtir/çek. Vazgeçerse null.
  /// `maxDuration` yalnız kamera kaydını sınırlar (galeri seçiminde boyut
  /// limiti devrede); 60 sn ~ 25 MB sınırıyla uyumlu pratik üst sınır.
  Future<XFile?> pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    return picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 60),
    );
  }

  /// Boyut + tür doğrulaması (image). Geçersizse ilgili exception fırlatır.
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

  /// V1.1 — boyut + tür doğrulaması (video, ≤25MB, mp4/mov).
  static Future<int> validateVideoFile(XFile file) async {
    final ext = _extensionOf(file.name).toLowerCase();
    if (!_allowedVideoExt.contains(ext)) {
      throw const ChatMediaUnsupportedException();
    }
    final size = await file.length();
    if (size > maxVideoBytes) {
      throw const ChatMediaTooLargeException();
    }
    return size;
  }

  Future<int> validate(XFile file) => validateFile(file);

  /// Seçilen [file]'ı membership-gated path'e yükler ve sonucu döndürür.
  /// [scope] 'conversations' | 'groups'; [scopeId] conversation/grup id.
  /// [kind] image (default) | video — validation/MIME/media_type belirler.
  Future<ChatMediaUploadResult> upload({
    required String scope,
    required String scopeId,
    required String ownerId,
    required XFile file,
    ChatMediaKind kind = ChatMediaKind.image,
  }) async {
    final isVideo = kind == ChatMediaKind.video;
    final size =
        isVideo ? await validateVideoFile(file) : await validateFile(file);
    final bytes = await file.readAsBytes();
    final ext = _extensionOf(file.name).toLowerCase();
    final ts = DateTime.now().microsecondsSinceEpoch;
    final path = '$scope/$scopeId/$ownerId/m_$ts.$ext';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(
            contentType: isVideo ? _mimeForVideoExt(ext) : _mimeForExt(ext),
            upsert: false,
          ),
        );
    return ChatMediaUploadResult(
      storagePath: path,
      sizeBytes: size,
      mediaType: isVideo ? 'video' : 'image',
    );
  }

  /// Private bucket → render için signed URL üret. Perf: aynı oturumda aynı
  /// path yeniden imzalanmaz (signed URL cache; realtime medya enrich yolu).
  Future<String> signedUrl(String storagePath) {
    return ChatMediaSignedUrlCache.instance
        .resolveWith(_client, bucket, storagePath);
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

  static String _mimeForVideoExt(String ext) {
    switch (ext) {
      case 'mov':
        return 'video/quicktime';
      case 'mp4':
      default:
        return 'video/mp4';
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
