import 'package:flutter/material.dart';

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
    required this.type,
    required this.author,
    required this.role,
    required this.text,
    required this.createdAt,
    this.tags = const <String>[],
    required this.gradient,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.groupId,
    this.groupName,
  });

  final String id;
  final PostType type;
  final String author;
  final String role;
  final String text;
  final DateTime createdAt;
  final List<String> tags;
  final List<Color> gradient;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isSaved;

  /// `groupHighlight` türü için — kaynak grup.
  final String? groupId;
  final String? groupName;

  bool get isGroupHighlight => type == PostType.groupHighlight;

  FeedPost copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    bool? isSaved,
  }) {
    return FeedPost(
      id: id,
      type: type,
      author: author,
      role: role,
      text: text,
      createdAt: createdAt,
      tags: tags,
      gradient: gradient,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      groupId: groupId,
      groupName: groupName,
    );
  }
}
