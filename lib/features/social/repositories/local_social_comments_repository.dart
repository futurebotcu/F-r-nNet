import 'dart:async';

import '../models/social_comment.dart';
import 'social_comments_repository.dart';

/// In-memory parite. Test / Supabase disabled / guest mode için.
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

  final StreamController<void> _changes = StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

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
  }) async {
    final now = DateTime.now();
    final comment = SocialComment(
      id: 'sc_${now.microsecondsSinceEpoch}',
      postId: postId,
      ownerId: _meId,
      text: text.trim(),
      authorName: _meName,
      authorRole: _meRole,
      isDeleted: false,
      createdAt: now,
    );
    (_byPostId[postId] ??= <SocialComment>[]).add(comment);
    _notify();
    return comment;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    for (final entry in _byPostId.entries) {
      final i = entry.value.indexWhere((c) => c.id == commentId);
      if (i >= 0) {
        final old = entry.value[i];
        if (old.isDeleted || old.ownerId != _meId) return;
        entry.value[i] = SocialComment(
          id: old.id,
          postId: old.postId,
          ownerId: old.ownerId,
          text: old.text,
          authorName: old.authorName,
          authorRole: old.authorRole,
          isDeleted: true,
          createdAt: old.createdAt,
        );
        _notify();
        return;
      }
    }
  }

  @override
  Stream<void> watch() => _changes.stream;
}
