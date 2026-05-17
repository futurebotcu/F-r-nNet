import '../models/group_category.dart';
import '../models/group_join_request.dart';
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

  /// Pending isteği approve eder; member olarak ekler + notification atar.
  Future<GroupJoinRequest> approveJoinRequest(String requestId);

  /// Pending isteği reject eder + notification atar.
  Future<GroupJoinRequest> rejectJoinRequest(String requestId);

  /// Repository içeriği değiştiğinde yayın.
  Stream<void> watch();
}
