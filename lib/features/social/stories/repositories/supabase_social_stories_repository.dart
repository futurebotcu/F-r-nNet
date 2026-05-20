// FırınNet Social V2 Commit 2 — Supabase stories impl.
//
// Donor `database_client.createStory + uploadStoryMedia + getStories +
// deleteStory` muadili. FırınNet adaptasyonu:
//   * `feed_stories` table + sıkı RLS (owner_id=auth.uid()).
//   * `story-media` bucket, path `{ownerId}/{storyId}.{ext}`.
//   * Soft-delete + `.select('id')` empty → StateError (P0 hardening).
//   * `expires_at > now()` defansif client filtresi (RLS zaten yapıyor).
//   * RFC-4122 v4 UUID generator (composer image upload pattern'i).

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/social_story.dart';
import 'social_stories_repository.dart';

class SupabaseSocialStoriesRepository implements SocialStoriesRepository {
  SupabaseSocialStoriesRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const String _columns =
      'id, owner_id, content_type, content_url, duration_ms, '
      'is_deleted, created_at, expires_at';

  /// RFC-4122 v4 UUID (uploadFeedImage'da olduğu gibi).
  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String h(int s, int e) => bytes
        .sublist(s, e)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
  }

  static String _mimeForImageExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Future<List<SocialStory>> listFreshStories() async {
    // Client defansif `expires_at > now()` filtresi — server RLS zaten
    // uygular, ama tick race / cache senaryosunda burada da kontrol.
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('feed_stories')
        .select(_columns)
        .eq('is_deleted', false)
        .gt('expires_at', nowIso)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SocialStory.fromRow)
        .toList(growable: false);
  }

  @override
  Future<List<SocialStory>> listFreshStoriesOf(String ownerId) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('feed_stories')
        .select(_columns)
        .eq('owner_id', ownerId)
        .eq('is_deleted', false)
        .gt('expires_at', nowIso)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SocialStory.fromRow)
        .toList(growable: false);
  }

  @override
  Future<SocialStory> createImageStory({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    final storyId = _generateUuidV4();
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    final path = '$userId/$storyId.$ext';
    final mime = _mimeForImageExt(ext);

    // 1) Storage upload — path prefix RLS owner_id=auth.uid().
    await _client.storage.from('story-media').uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(
            contentType: mime,
            upsert: false,
          ),
        );

    final publicUrl = _client.storage.from('story-media').getPublicUrl(path);

    // 2) feed_stories INSERT — RLS owner_id=auth.uid() WITH CHECK.
    // Fail olursa storage objesini geri al (orphan engelle).
    try {
      final row = await _client
          .from('feed_stories')
          .insert(<String, dynamic>{
            'id': storyId,
            'owner_id': userId,
            'content_type': 'image',
            'content_url': publicUrl,
          })
          .select(_columns)
          .single();
      _notify();
      return SocialStory.fromRow(row);
    } catch (e) {
      // Rollback: storage objesini sil.
      try {
        await _client.storage.from('story-media').remove([path]);
      } catch (_) {
        // Best-effort.
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteStory(String storyId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    // P0 RLS RETURNING dersi: SELECT policy owner self soft-deleted'ı
    // görür → RETURNING fail etmez. `.select('id')` empty → StateError.
    final rows = await _client
        .from('feed_stories')
        .update(<String, dynamic>{'is_deleted': true})
        .eq('id', storyId)
        .eq('owner_id', userId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw StateError(
        'Hikaye silinemedi: yetki yok veya kayıt bulunamadı.',
      );
    }
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
