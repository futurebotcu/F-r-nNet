import 'group_category.dart';

/// Sektör konuşma grubu — kullanıcılar oluşturur, üye olur, mesaj yazar.
///
/// `maxMembers == null` → sınırsız grup, hiçbir zaman dolu olmaz.
/// Aksi halde `currentMemberCount >= maxMembers` ise grup dolu.
///
/// Supabase şeması:
/// social_groups(
///   id, name, description, category, owner_name, owner_id,
///   city, is_private, max_members nullable,
///   current_member_count, tags text[], visual_seed, created_at
/// )
class SocialGroup {
  const SocialGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.ownerName,
    required this.ownerId,
    this.city = '',
    this.isPrivate = false,
    this.maxMembers,
    required this.currentMemberCount,
    required this.createdAt,
    this.tags = const <String>[],
    required this.visualSeed,
  });

  final String id;
  final String name;
  final String description;
  final GroupCategory category;
  final String ownerName;
  final String ownerId;
  final String city;
  final bool isPrivate;

  /// `null` → sınırsız.
  final int? maxMembers;

  final int currentMemberCount;
  final DateTime createdAt;
  final List<String> tags;

  /// Kart placeholder gradient için seed (0..7 → palet).
  final int visualSeed;

  bool get isUnlimited => maxMembers == null;
  bool get isFull =>
      maxMembers != null && currentMemberCount >= maxMembers!;

  /// 0..1 arası doluluk (sınırsız ise daima 0).
  double get fillRatio {
    if (isUnlimited || maxMembers == 0) return 0;
    final r = currentMemberCount / maxMembers!;
    return r.clamp(0.0, 1.0);
  }

  SocialGroup copyWith({
    String? name,
    String? description,
    GroupCategory? category,
    String? city,
    bool? isPrivate,
    int? maxMembers,
    int? currentMemberCount,
    List<String>? tags,
    int? visualSeed,
  }) {
    return SocialGroup(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      ownerName: ownerName,
      ownerId: ownerId,
      city: city ?? this.city,
      isPrivate: isPrivate ?? this.isPrivate,
      maxMembers: maxMembers ?? this.maxMembers,
      currentMemberCount: currentMemberCount ?? this.currentMemberCount,
      createdAt: createdAt,
      tags: tags ?? this.tags,
      visualSeed: visualSeed ?? this.visualSeed,
    );
  }
}
