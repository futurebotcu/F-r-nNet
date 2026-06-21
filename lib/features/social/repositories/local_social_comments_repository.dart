import 'dart:async';

import '../models/social_comment.dart';
import 'social_comments_repository.dart';

/// In-memory parite. Test / Supabase disabled / guest mode için.
///
/// PR #2: yoruma beğeni (tek kullanıcı modeli — likeCount 0↔1) + tek-seviye
/// cevap + üst yorum silinince cevapların cascade soft-delete'i (server
/// trigger paritesi).
class LocalSocialCommentsRepository implements SocialCommentsRepository {
  LocalSocialCommentsRepository({
    String currentUserId = 'me_misafir',
    String currentUserName = 'Misafir',
    String currentUserRole = 'Üye',
  })  : _meId = currentUserId,
        _meName = currentUserName,
        _meRole = currentUserRole;

  final String _meId;
  final String _meName;
  final String _meRole;

  final Map<String, List<SocialComment>> _byPostId =
      <String, List<SocialComment>>{};

  // Benzersiz id: ardışık eklemeler aynı mikrosaniyede çakışmasın.
  int _seq = 0;

  final StreamController<void> _changes = StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  SocialComment? _findById(String id) {
    for (final entry in _byPostId.entries) {
      for (final c in entry.value) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  @override
  Future<List<SocialComment>> listComments(String postId) async {
    final list = _byPostId[postId] ?? const <SocialComment>[];
    final visible = list.where((c) => !c.isDeleted).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(visible);
  }

  @override
  Future<SocialComment> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) async {
    if (parentCommentId != null) {
      final parent = _findById(parentCommentId);
      // Tek-seviye: parent görünür bir ÜST yorum (cevap değil) ve aynı post.
      if (parent == null ||
          parent.isDeleted ||
          parent.isReply ||
          parent.postId != postId) {
        throw StateError('Cevap yalnızca üst yoruma yazılabilir.');
      }
    }
    final now = DateTime.now();
    final comment = SocialComment(
      id: 'sc_${_seq++}_${now.microsecondsSinceEpoch}',
      postId: postId,
      ownerId: _meId,
      text: text.trim(),
      authorName: _meName,
      authorRole: _meRole,
      isDeleted: false,
      createdAt: now,
      likeCount: 0,
      isLiked: false,
      parentCommentId: parentCommentId,
    );
    (_byPostId[postId] ??= <SocialComment>[]).add(comment);
    _notify();
    return comment;
  }

  @override
  Future<bool> toggleCommentLike(String commentId) async {
    for (final entry in _byPostId.entries) {
      final i = entry.value.indexWhere((c) => c.id == commentId);
      if (i >= 0) {
        final c = entry.value[i];
        final newLiked = !c.isLiked;
        final newCount =
            newLiked ? c.likeCount + 1 : (c.likeCount > 0 ? c.likeCount - 1 : 0);
        entry.value[i] = c.copyWith(isLiked: newLiked, likeCount: newCount);
        _notify();
        return newLiked;
      }
    }
    return false;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    for (final entry in _byPostId.entries) {
      final i = entry.value.indexWhere((c) => c.id == commentId);
      if (i >= 0) {
        final old = entry.value[i];
        if (old.isDeleted || old.ownerId != _meId) return;
        entry.value[i] = old.copyWith(isDeleted: true);
        // Cascade: üst yorum silinince bağlı cevaplar da soft-delete olur.
        if (old.parentCommentId == null) {
          for (var j = 0; j < entry.value.length; j++) {
            final r = entry.value[j];
            if (r.parentCommentId == commentId && !r.isDeleted) {
              entry.value[j] = r.copyWith(isDeleted: true);
            }
          }
        }
        _notify();
        return;
      }
    }
  }

  @override
  Stream<void> watch() => _changes.stream;
}
