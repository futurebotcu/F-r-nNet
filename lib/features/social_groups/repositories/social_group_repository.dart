import '../models/group_category.dart';
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

  /// Repository içeriği değiştiğinde yayın.
  Stream<void> watch();
}
