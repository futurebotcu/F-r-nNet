import 'package:flutter/material.dart';

import 'feed_media.dart';
import 'post_type.dart';

/// Bir kullanıcı paylaşımı veya gruptan öne çıkmış mesaj.
///
/// Supabase şeması:
/// feed_posts(
///   id, type, author_name, author_role, text,
///   tags text[], gradient_seed, like_count, comment_count, created_at,
///   group_id nullable, group_name nullable, group_message_id nullable
/// )
class FeedPost {
  const FeedPost({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.author,
    required this.role,
    required this.text,
    required this.createdAt,
    this.tags = const <String>[],
    required this.gradient,
    this.likeCount = 0,
    this.commentCount = 0,
    this.repostCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isReposted = false,
    this.groupId,
    this.groupName,
    this.mediaList = const <FeedMedia>[],
  });

  final String id;

  /// V1 Feed F1 — Post sahibinin user id'si (`feed_posts.owner_id`).
  /// UI tarafı owner-only aksiyonları (örn. "Gönderiyi sil") bu alana
  /// `currentAuthUserProvider`'ı kıyaslayarak kapatır/açar.
  final String ownerId;

  final PostType type;
  final String author;
  final String role;
  final String text;
  final DateTime createdAt;
  final List<String> tags;
  final List<Color> gradient;
  final int likeCount;
  final int commentCount;

  /// PR — Repost sayısı (`feed_posts.repost_count`, feed_reposts trigger).
  final int repostCount;
  final bool isLiked;
  final bool isSaved;

  /// Mevcut kullanıcı bu gönderiyi repost etti mi (feed_reposts join).
  final bool isReposted;

  /// `groupHighlight` türü için — kaynak grup.
  final String? groupId;
  final String? groupName;

  /// V1 Social S3 — Post'a bağlı medya satırları (image V1; video V1.2).
  /// Boş liste = yalnız metin. UI tarafı `mediaList.isEmpty` ise medya
  /// preview göstermez. V1'de tipik olarak 0 veya 1 eleman.
  final List<FeedMedia> mediaList;

  bool get isGroupHighlight => type == PostType.groupHighlight;
  bool get hasImage => mediaList.any((m) => m.isImage);
  bool get hasVideo => mediaList.any((m) => m.isVideo);
  FeedMedia? get firstImage =>
      mediaList.where((m) => m.isImage).cast<FeedMedia?>().firstWhere(
            (m) => true,
            orElse: () => null,
          );

  /// V2 Social Core Commit 3 — Video post desteği. UI ilk video media'yı
  /// player ile render eder; donor `post_view.dart` `withCustomVideoPlayer`
  /// muadili.
  FeedMedia? get firstVideo =>
      mediaList.where((m) => m.isVideo).cast<FeedMedia?>().firstWhere(
            (m) => true,
            orElse: () => null,
          );

  FeedPost copyWith({
    int? likeCount,
    int? commentCount,
    int? repostCount,
    bool? isLiked,
    bool? isSaved,
    bool? isReposted,
    List<FeedMedia>? mediaList,
  }) {
    return FeedPost(
      id: id,
      ownerId: ownerId,
      type: type,
      author: author,
      role: role,
      text: text,
      createdAt: createdAt,
      tags: tags,
      gradient: gradient,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      repostCount: repostCount ?? this.repostCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isReposted: isReposted ?? this.isReposted,
      groupId: groupId,
      groupName: groupName,
      mediaList: mediaList ?? this.mediaList,
    );
  }
}
