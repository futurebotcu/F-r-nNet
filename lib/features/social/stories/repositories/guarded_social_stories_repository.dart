// FırınNet Social V2 Commit 2 — Guarded stories dekoratörü.
// Read delege; write `canWriteCheck()` false ise GuestActionRequiredException.

import 'dart:typed_data';

import '../../../auth/services/auth_required_guard.dart';
import '../models/social_story.dart';
import 'social_stories_repository.dart';

class GuardedSocialStoriesRepository implements SocialStoriesRepository {
  GuardedSocialStoriesRepository({
    required this.inner,
    required this.canWriteCheck,
  });

  final SocialStoriesRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  @override
  Future<List<SocialStory>> listFreshStories() => inner.listFreshStories();

  @override
  Future<List<SocialStory>> listFreshStoriesOf(String ownerId) =>
      inner.listFreshStoriesOf(ownerId);

  @override
  Future<SocialStory> createImageStory({
    required Uint8List bytes,
    required String fileExtension,
  }) {
    _requireWrite('hikaye paylaşmak');
    return inner.createImageStory(bytes: bytes, fileExtension: fileExtension);
  }

  @override
  Future<void> deleteStory(String storyId) {
    _requireWrite('hikaye silmek');
    return inner.deleteStory(storyId);
  }

  @override
  Stream<void> watch() => inner.watch();
}
