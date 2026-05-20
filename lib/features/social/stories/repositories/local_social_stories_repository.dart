// FırınNet Social V2 Commit 2 — Local in-memory stories impl
// (test / guest / Supabase off senaryolarında).

import 'dart:async';
import 'dart:typed_data';

import '../models/social_story.dart';
import 'social_stories_repository.dart';

class LocalSocialStoriesRepository implements SocialStoriesRepository {
  LocalSocialStoriesRepository({
    String currentUserId = 'me_misafir',
  }) : _meId = currentUserId;

  final String _meId;
  final List<SocialStory> _stories = <SocialStory>[];

  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  @override
  Future<List<SocialStory>> listFreshStories() async {
    final now = DateTime.now();
    final src = _stories
        .where((s) => !s.isDeleted && s.expiresAt.isAfter(now))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(src);
  }

  @override
  Future<List<SocialStory>> listFreshStoriesOf(String ownerId) async {
    final now = DateTime.now();
    final src = _stories
        .where(
          (s) =>
              s.ownerId == ownerId &&
              !s.isDeleted &&
              s.expiresAt.isAfter(now),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(src);
  }

  @override
  Future<SocialStory> createImageStory({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final now = DateTime.now();
    final id = 'ss_${now.microsecondsSinceEpoch}';
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    final path = '$_meId/$id.$ext';
    final story = SocialStory(
      id: id,
      ownerId: _meId,
      contentType: 'image',
      contentUrl: 'local://$path',
      isDeleted: false,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
    );
    _stories.insert(0, story);
    _notify();
    return story;
  }

  @override
  Future<void> deleteStory(String storyId) async {
    final i = _stories.indexWhere((s) => s.id == storyId);
    if (i == -1) {
      throw StateError('Hikaye silinemedi: kayıt bulunamadı.');
    }
    final old = _stories[i];
    if (old.ownerId != _meId) {
      throw StateError('Hikaye silinemedi: yetki yok.');
    }
    _stories[i] = SocialStory(
      id: old.id,
      ownerId: old.ownerId,
      contentType: old.contentType,
      contentUrl: old.contentUrl,
      durationMs: old.durationMs,
      isDeleted: true,
      createdAt: old.createdAt,
      expiresAt: old.expiresAt,
    );
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;
}
