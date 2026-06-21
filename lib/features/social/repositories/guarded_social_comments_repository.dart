import '../../auth/services/auth_required_guard.dart';
import '../models/social_comment.dart';
import 'social_comments_repository.dart';

/// Guest write korumalı dekoratör.
class GuardedSocialCommentsRepository implements SocialCommentsRepository {
  GuardedSocialCommentsRepository({
    required this.inner,
    required this.canWriteCheck,
  });

  final SocialCommentsRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  @override
  Future<List<SocialComment>> listComments(String postId) =>
      inner.listComments(postId);

  @override
  Future<SocialComment> addComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) {
    _requireWrite(parentCommentId == null ? 'yorum yazmak' : 'cevap yazmak');
    return inner.addComment(
      postId: postId,
      text: text,
      parentCommentId: parentCommentId,
    );
  }

  @override
  Future<bool> toggleCommentLike(String commentId) {
    _requireWrite('yorumu beğenmek');
    return inner.toggleCommentLike(commentId);
  }

  @override
  Future<void> deleteComment(String commentId) {
    _requireWrite('yorum silmek');
    return inner.deleteComment(commentId);
  }

  @override
  Stream<void> watch() => inner.watch();
}
