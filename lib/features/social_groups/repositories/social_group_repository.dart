import '../models/group_category.dart';
import '../models/group_join_request.dart';
import '../models/group_member.dart';
import '../models/group_message.dart';
import '../models/social_group.dart';
import '../services/group_join_result.dart';

/// Sektör grupları için soyut erişim.
///
/// V1: [LocalSocialGroupRepository] (in-memory) ile çalışır, demo seed barındırır.
/// V2: SupabaseSocialGroupRepository — yalnızca aynı yüzeyi uyarlayacak,
///      UI ve servis katmanı değişmeyecek.
abstract class SocialGroupRepository {
  /// Tüm gruplar (opsiyonel kategori filtresi). Owner+createdAt desc.
  Future<List<SocialGroup>> listGroups({GroupCategory? category});

  /// "Bu hafta öne çıkan" — currentMemberCount desc, ilk N.
  Future<List<SocialGroup>> listPopular({int limit = 6});

  /// Mevcut kullanıcının üye olduğu gruplar.
  Future<List<SocialGroup>> listJoined();

  Future<SocialGroup?> getGroup(String id);

  /// Yeni grup oluştur. Owner otomatik joined sayılır,
  /// `currentMemberCount = 1` ile başlar.
  Future<SocialGroup> createGroup({
    required String name,
    required String description,
    required GroupCategory category,
    String city = '',
    bool isPrivate = false,
    int? maxMembers,
    List<String> tags = const <String>[],
  });

  /// Üyelik dene; sonuç enum.
  Future<GroupJoinResult> joinGroup(String id);

  /// Üyelikten çık. NoOp eğer zaten üye değilse.
  Future<void> leaveGroup(String id);

  bool isJoined(String id);

  /// Mesajlar — pinned önce, sonra createdAt desc.
  Future<List<GroupMessage>> listMessages(String groupId);

  Future<void> postMessage(GroupMessage m);

  // ─────────────────────────────────────── Private group join requests (V1 P1-D)

  /// Private gruba katılım isteği gönderir; mevcut pending varsa onu döner.
  /// `request_group_join` RPC üzerinden gerçekleşir.
  Future<GroupJoinRequest> requestJoinGroup(String groupId, {String? message});

  /// Geçerli kullanıcının bu grup için isteği var mı? (status veya null.)
  Future<GroupJoinRequest?> getMyJoinRequest(String groupId);

  /// Bir grubun pending isteklerini owner görür (RLS kontrolü server-side).
  Future<List<GroupJoinRequest>> listPendingJoinRequests(String groupId);

  /// G.N4 — Bir grubun pending istek SAYISI. Owner kart badge'i için.
  /// RLS server tarafında satır filtreler; owner değilse 0 döner.
  /// Hata olursa 0 döner (UI badge gizlenir — sessiz fallback).
  Future<int> pendingJoinRequestCount(String groupId);

  /// Pending isteği approve eder; member olarak ekler + notification atar.
  Future<GroupJoinRequest> approveJoinRequest(String requestId);

  /// Pending isteği reject eder + notification atar.
  Future<GroupJoinRequest> rejectJoinRequest(String requestId);

  // ─────────────────────────────────────── Sprint 2 — Members management

  /// V1 Sprint 2 — Bir grubun üyelerinin profil snapshot listesi.
  /// RLS: katılım onaylı grupta yalnız owner+member görür; public grupta
  /// authenticated user görür.
  Future<List<GroupMemberProfile>> listMembers(String groupId);

  /// V1 Sprint 2 — Owner-only üye çıkarma. `remove_group_member` RPC.
  /// Owner kendisini çıkaramaz (leave_group_safely kullanılmalı).
  Future<void> removeMember(String groupId, String memberId);

  /// V1 Sprint 2 — Atomik çıkış: owner için auto-handoff/close,
  /// non-owner için kendi çıkışı. `leave_group_safely` RPC.
  Future<GroupLeaveOutcome> leaveGroupSafely(String groupId);

  /// V1 Sprint 2 — Owner soft-delete: `social_groups.is_deleted=true`.
  /// RLS update_own zaten owner'a yetki veriyor; RPC gerekmez.
  Future<void> closeGroup(String groupId);

  /// Repository içeriği değiştiğinde yayın.
  Stream<void> watch();

  /// Perf — yalnız MESAJ değişimi tick'i (post). Mesaj gönderimi tüm grup
  /// metadata/üye/liste provider'larını değil, SADECE mesaj listesini
  /// tazeler (invalidation storm önlenir). Default: [watch] (geri uyumlu).
  Stream<void> watchMessages() => watch();

  /// Repo instance atıldığında controller'ları kapatma kancası (default no-op).
  void dispose() {}
}
