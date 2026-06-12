import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/can_write_check_provider.dart';
import '../models/group_category.dart';
import '../models/group_join_request.dart';
import '../models/group_member.dart';
import '../models/group_message.dart';
import '../models/social_group.dart';
import '../repositories/guarded_social_group_repository.dart';
import '../repositories/local_social_group_repository.dart';
import '../repositories/social_group_repository.dart';
import '../repositories/supabase_social_group_repository.dart';
import '../services/group_validator.dart';

/// Sosyal Omurga V1 — Supabase aktif ve oturum varsa gerçek backend; aksi
/// halde LocalSocialGroupRepository.
///
/// Feed ile aynı pattern: guest kullanıcı için Local seed gezme deneyimi
/// sağlanır, login açıldığı an Supabase repository devreye girer ve
/// Guarded wrapper guest yazma aksiyonlarını bloklar.
final socialGroupRepositoryProvider =
    Provider<SocialGroupRepository>((ref) {
  // P0 — yalnız userId izlenir (select). AuthUser'da == override'ı yok;
  // token refresh / app resume her emisyonda yeni instance üretir. Obje
  // izlenince repo (ve içindeki sync joined cache) AYNI kullanıcı için bile
  // sıfırlanıyordu → grup detayı açıkken üye kullanıcının isJoined'ı false'a
  // düşüp composer yerine "Sohbete katıl" görünüyordu. userId değişmeden
  // repo instance'ı stabil kalır; gerçek login/logout'ta yine yenilenir.
  final userId = ref.watch(currentAuthUserProvider.select((u) => u?.id));
  final SocialGroupRepository inner;
  if (AppConfig.supabaseEnabled && userId != null) {
    inner = SupabaseSocialGroupRepository(sb.Supabase.instance.client);
  } else {
    inner = LocalSocialGroupRepository(seed: true);
  }
  if (kDebugMode) {
    debugPrint('[FirinNet][Groups] repo REBUILD uid=$userId '
        'inner=${inner.runtimeType}#${identityHashCode(inner)}');
  }
  final canWrite = ref.watch(canWriteCheckProvider);
  final repo = GuardedSocialGroupRepository(inner: inner, canWriteCheck: canWrite);
  // Provider rebuild'inde (login/logout) eski repo'nun iki broadcast
  // controller'ını kapat (önceki sprint P2: controller close).
  ref.onDispose(repo.dispose);
  return repo;
});

final groupValidatorProvider = Provider<GroupValidator>((ref) {
  return const GroupValidator();
});

/// Repository YAPISAL değişiklik tick'i (join/leave/create/cache).
final groupChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.watch();
});

/// Perf — yalnız MESAJ değişimi tick'i. groupMessagesProvider bunu izler;
/// mesaj gönderimi grup metadata/üye/liste provider'larını recompute etmez
/// (invalidation storm önlenir, mesaj sonrası jank azalır).
final groupMessageChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.watchMessages();
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
  // Perf: yalnız mesaj tick'i + yapısal tick (grup silinince temizlensin).
  // Mesaj gönderiminde SADECE bu provider recompute olur.
  ref.watch(groupMessageChangesProvider);
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

// ─────────────────────────────────────── V1 P1-D — Private join requests

/// Belirli bir grup için geçerli kullanıcının request'i (varsa).
final myJoinRequestProvider = FutureProvider.autoDispose
    .family<GroupJoinRequest?, String>((ref, groupId) async {
  ref.watch(groupChangesProvider);
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.getMyJoinRequest(groupId);
});

/// Bir grubun pending istekleri — yalnız grup owner görür (RLS).
final pendingJoinRequestsProvider = FutureProvider.autoDispose
    .family<List<GroupJoinRequest>, String>((ref, groupId) async {
  ref.watch(groupChangesProvider);
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.listPendingJoinRequests(groupId);
});

/// G.N4 — Bir grubun pending istek SAYISI (count-only).
///
/// Owner kart badge'i için (lightweight; full list yerine sadece sayı).
/// RLS server-side: owner görmüyorsa 0; hata olursa 0 (sessiz fallback).
final pendingJoinRequestCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, groupId) async {
  ref.watch(groupChangesProvider);
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.pendingJoinRequestCount(groupId);
});

/// V1 Sprint 2 — Bir grubun üyeleri (profile snapshot ile).
///
/// Üyeler sheet'i için. RLS server-side gating yapar: katılım onaylı grupta
/// owner+member görür; public grupta authenticated user görür.
final groupMembersProvider = FutureProvider.autoDispose
    .family<List<GroupMemberProfile>, String>((ref, groupId) async {
  ref.watch(groupChangesProvider);
  final repo = ref.watch(socialGroupRepositoryProvider);
  return repo.listMembers(groupId);
});
