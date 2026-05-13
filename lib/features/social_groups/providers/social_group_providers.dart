import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_category.dart';
import '../models/group_message.dart';
import '../models/social_group.dart';
import '../repositories/local_social_group_repository.dart';
import '../repositories/social_group_repository.dart';
import '../services/group_validator.dart';

/// V1: local + seed.
/// V2: SupabaseSocialGroupRepository — burada swap edilir, UI değişmez.
final socialGroupRepositoryProvider =
    Provider<SocialGroupRepository>((ref) {
  return LocalSocialGroupRepository(seed: true);
});

final groupValidatorProvider = Provider<GroupValidator>((ref) {
  return const GroupValidator();
});

/// Repository değişikliklerini dinleyen tick.
final groupChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.watch();
});

/// Tüm gruplar veya filtreli liste.
final groupsListProvider = FutureProvider.autoDispose
    .family<List<SocialGroup>, GroupCategory?>((ref, category) async {
  ref.watch(groupChangesProvider);
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.listGroups(category: category);
});

/// Popüler gruplar (Feed carousel için).
final popularGroupsProvider =
    FutureProvider.autoDispose<List<SocialGroup>>((ref) async {
  ref.watch(groupChangesProvider);
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.listPopular();
});

/// Mevcut kullanıcının üye olduğu gruplar.
final joinedGroupsProvider =
    FutureProvider.autoDispose<List<SocialGroup>>((ref) async {
  ref.watch(groupChangesProvider);
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.listJoined();
});

final groupByIdProvider =
    FutureProvider.autoDispose.family<SocialGroup?, String>((ref, id) async {
  ref.watch(groupChangesProvider);
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.getGroup(id);
});

final groupMessagesProvider = FutureProvider.autoDispose
    .family<List<GroupMessage>, String>((ref, groupId) async {
  ref.watch(groupChangesProvider);
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.listMessages(groupId);
});

/// "Belirli bir grup üye miyim?" — sync.
final isJoinedProvider = Provider.family<bool, String>((ref, id) {
  ref.watch(groupChangesProvider);
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.isJoined(id);
});
