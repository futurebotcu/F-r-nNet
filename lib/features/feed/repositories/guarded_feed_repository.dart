import 'dart:typed_data';

import '../../auth/services/auth_required_guard.dart';
import '../models/feed_comment.dart';
import '../models/feed_insight.dart';
import '../models/feed_media.dart';
import '../models/feed_post.dart';
import '../models/post_type.dart';
import 'feed_repository.dart';

/// V1.3.3 — guest write korumalı [FeedRepository] dekoratörü.
///
/// Read metodları doğrudan [inner]'a delege; write metodları
/// `canWriteCheck()` false dönerse [GuestActionRequiredException] atar.
class GuardedFeedRepository implements FeedRepository {
  GuardedFeedRepository({required this.inner, required this.canWriteCheck});

  final FeedRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  // ── Read (delege) ────────────────────────────────────────────

  @override
  Future<List<FeedPost>> listPosts({PostType? type}) =>
      inner.listPosts(type: type);

  @override
  Future<List<FeedPost>> listPostsPage({
    int offset = 0,
    int limit = 20,
    PostType? type,
  }) =>
      inner.listPostsPage(offset: offset, limit: limit, type: type);

  @override
  Future<List<FeedPost>> listPostsByOwner(String ownerId) =>
      inner.listPostsByOwner(ownerId);

  @override
  Future<List<FeedPost>> listPostsByOwnerPage({
    required String ownerId,
    int offset = 0,
    int limit = 20,
  }) =>
      inner.listPostsByOwnerPage(
        ownerId: ownerId,
        offset: offset,
        limit: limit,
      );

  @override
  Future<List<FeedPost>> listPostsPageForFollowing({
    required Set<String> followingIds,
    int offset = 0,
    int limit = 20,
  }) =>
      inner.listPostsPageForFollowing(
        followingIds: followingIds,
        offset: offset,
        limit: limit,
      );

  @override
  Future<List<FeedInsight>> listInsights() => inner.listInsights();

  @override
  Stream<void> watch() => inner.watch();

  @override
  Stream<void> watchContent() => inner.watchContent();

  @override
  void dispose() => inner.dispose();

  // ── Write (guarded) ───────────────────────────────────────────

  @override
  Future<FeedPost> addPost({
    required PostType type,
    required String author,
    required String role,
    required String text,
    List<String> tags = const <String>[],
  }) {
    _requireWrite('feed gönderisi paylaşmak');
    return inner.addPost(
      type: type,
      author: author,
      role: role,
      text: text,
      tags: tags,
    );
  }

  @override
  Future<void> deletePost(String postId) {
    _requireWrite('gönderiyi silmek');
    return inner.deletePost(postId);
  }

  @override
  Future<FeedPost> updatePost({
    required String postId,
    required String text,
    List<String>? tags,
  }) {
    _requireWrite('gönderiyi düzenlemek');
    return inner.updatePost(postId: postId, text: text, tags: tags);
  }

  @override
  Future<FeedMedia> uploadFeedImage({
    required String postId,
    required Uint8List bytes,
    required String fileExtension,
    int? width,
    int? height,
  }) {
    _requireWrite('gönderiye resim eklemek');
    return inner.uploadFeedImage(
      postId: postId,
      bytes: bytes,
      fileExtension: fileExtension,
      width: width,
      height: height,
    );
  }

  @override
  Future<FeedMedia> uploadFeedVideo({
    required String postId,
    required Uint8List bytes,
    required String fileExtension,
    int? width,
    int? height,
    int? durationMs,
  }) {
    _requireWrite('gönderiye video eklemek');
    return inner.uploadFeedVideo(
      postId: postId,
      bytes: bytes,
      fileExtension: fileExtension,
      width: width,
      height: height,
      durationMs: durationMs,
    );
  }

  @override
  Future<FeedPost> toggleLike(String postId) {
    _requireWrite('gönderiyi beğenmek');
    return inner.toggleLike(postId);
  }

  @override
  Future<FeedPost> toggleSave(String postId) {
    _requireWrite('gönderiyi kaydetmek');
    return inner.toggleSave(postId);
  }

  // ── Comments (V1 P1-B) ────────────────────────────────────────

  @override
  Future<List<FeedComment>> listComments(String postId) =>
      inner.listComments(postId);

  @override
  Future<FeedComment> addComment({
    required String postId,
    required String text,
    String? currentAuthorName,
    String? currentAuthorRole,
  }) {
    _requireWrite('yorum yazmak');
    return inner.addComment(
      postId: postId,
      text: text,
      currentAuthorName: currentAuthorName,
      currentAuthorRole: currentAuthorRole,
    );
  }

  @override
  Future<void> deleteComment(String commentId) {
    _requireWrite('yorum silmek');
    return inner.deleteComment(commentId);
  }
}
