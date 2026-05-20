import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/social_comment.dart';
import 'social_comments_repository.dart';

/// Supabase impl — `feed_comments` tablosuna doğrudan.
///
/// RLS server tarafında:
///   * SELECT visible: is_deleted=false (herkes)
///   * INSERT: owner_id = auth.uid()
///   * UPDATE/DELETE: owner_id = auth.uid()
///
/// `author_name` / `author_role` BEFORE INSERT trigger
/// (`snapshot_feed_comment_author`, SECURITY DEFINER + postgres
/// BYPASSRLS=true) profilden snapshot eder. Client `text` dışında bir
/// şey göndermek zorunda değil.
class SupabaseSocialCommentsRepository implements SocialCommentsRepository {
  SupabaseSocialCommentsRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _notify() => _changes.add(null);

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const String _columns =
      'id, post_id, owner_id, text, author_name, author_role, '
      'is_deleted, created_at';

  @override
  Future<List<SocialComment>> listComments(String postId) async {
    final rows = await _client
        .from('feed_comments')
        .select(_columns)
        .eq('post_id', postId)
        .eq('is_deleted', false)
        .order('created_at', ascending: true)
        .limit(200);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SocialComment.fromRow)
        .toList(growable: false);
  }

  @override
  Future<SocialComment> addComment({
    required String postId,
    required String text,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    final row = await _client
        .from('feed_comments')
        .insert(<String, dynamic>{
          'post_id': postId,
          'owner_id': userId,
          'text': text.trim(),
          // author_name / author_role server-side trigger ile.
        })
        .select(_columns)
        .single();
    _notify();
    return SocialComment.fromRow(row);
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    // V1 P0 Hardening — Supabase `update().eq().eq()` zinciri 0 row
    // affect ettiğinde exception fırlatmıyor → UI sahte başarı snackbar
    // gösteriyor, DB değişmiyor (kullanıcı raporu "buton göründü ama
    // silme çalışmadı"). `.select('id')` ile dönen liste boşsa
    // owner-mismatch / not-found / RLS reddi durumunu üst katmana
    // taşı; comments_page `catch (e)` dalı net hata snackbar'ı gösterir.
    final rows = await _client
        .from('feed_comments')
        .update(<String, dynamic>{'is_deleted': true})
        .eq('id', commentId)
        .eq('owner_id', userId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw StateError(
        'Yorum silinemedi: yetki yok veya kayıt bulunamadı.',
      );
    }
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
