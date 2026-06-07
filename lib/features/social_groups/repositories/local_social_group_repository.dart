import 'dart:async';

import '../models/group_category.dart';
import '../models/group_join_request.dart';
import '../models/group_member.dart';
import '../models/group_message.dart';
import '../models/social_group.dart';
import '../services/group_join_result.dart';
import 'social_group_repository.dart';

/// Bellek içi sosyal grup repository. Demo seed ile gelir; uygulama yeniden
/// açıldığında veriler sıfırlanır — V1 için yeterli.
///
/// TODO(v2): SupabaseSocialGroupRepository eklenecek.
/// UI ve service katmanı bu sınıfa değil, [SocialGroupRepository] arayüzüne bağlı.
class LocalSocialGroupRepository implements SocialGroupRepository {
  LocalSocialGroupRepository({
    bool seed = true,
    String currentUserId = 'me_misafir',
    String currentUserName = 'Misafir',
  })  : _meId = currentUserId,
        _meName = currentUserName {
    if (seed) _seed();
  }

  final String _meId;
  final String _meName;

  final List<SocialGroup> _groups = <SocialGroup>[];
  final Set<String> _joined = <String>{};
  final List<GroupMessage> _messages = <GroupMessage>[];

  /// V1 Sprint 2 — Tam üye listesi grup başına. Local repo'da test/seed
  /// simulation için. createGroup/joinGroup/approve/leave/remove flow'ları
  /// bu mapi senkron tutar.
  final Map<String, List<GroupMemberProfile>> _membersByGroup =
      <String, List<GroupMemberProfile>>{};

  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  // ─────────────────────────────────────── Listing

  @override
  Future<List<SocialGroup>> listGroups({GroupCategory? category}) async {
    final src = category == null
        ? List<SocialGroup>.from(_groups)
        : _groups.where((g) => g.category == category).toList();
    src.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(src);
  }

  @override
  Future<List<SocialGroup>> listPopular({int limit = 6}) async {
    final src = List<SocialGroup>.from(_groups)
      ..sort((a, b) => b.currentMemberCount.compareTo(a.currentMemberCount));
    return List.unmodifiable(src.take(limit));
  }

  @override
  Future<List<SocialGroup>> listJoined() async {
    final src = _groups.where((g) => _joined.contains(g.id)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(src);
  }

  @override
  Future<SocialGroup?> getGroup(String id) async {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  // ─────────────────────────────────────── Membership

  @override
  bool isJoined(String id) => _joined.contains(id);

  @override
  Future<GroupJoinResult> joinGroup(String id) async {
    final i = _groups.indexWhere((g) => g.id == id);
    if (i == -1) return GroupJoinResult.notFound;
    if (_joined.contains(id)) return GroupJoinResult.alreadyJoined;
    final g = _groups[i];
    // V1 P0 — Private grup direct joinGroup yolundan üye alamaz; üyelik
    // `requestJoinGroup` + onay zinciriyle. Local repo Supabase repo ile
    // davranış paritesi tutar.
    if (g.isPrivate && g.ownerId != _meId) {
      return GroupJoinResult.requiresApproval;
    }
    if (g.isFull) return GroupJoinResult.full;
    _groups[i] = g.copyWith(currentMemberCount: g.currentMemberCount + 1);
    _joined.add(id);
    // Üye listesini senkron tut.
    _membersByGroup
        .putIfAbsent(id, () => <GroupMemberProfile>[])
        .add(GroupMemberProfile(
          userId: _meId,
          displayName: _meName,
          role: 'member',
          joinedAt: DateTime.now(),
        ));
    _notify();
    return GroupJoinResult.success;
  }

  @override
  Future<void> leaveGroup(String id) async {
    if (!_joined.contains(id)) return;
    final i = _groups.indexWhere((g) => g.id == id);
    if (i == -1) return;
    final g = _groups[i];
    final newCount = g.currentMemberCount - 1;
    _groups[i] =
        g.copyWith(currentMemberCount: newCount < 0 ? 0 : newCount);
    _joined.remove(id);
    _membersByGroup[id]?.removeWhere((m) => m.userId == _meId);
    _notify();
  }

  // ─────────────────────────────────────── Create

  @override
  Future<SocialGroup> createGroup({
    required String name,
    required String description,
    required GroupCategory category,
    String city = '',
    bool isPrivate = false,
    int? maxMembers,
    List<String> tags = const <String>[],
  }) async {
    final now = DateTime.now();
    final id = 'g_${now.microsecondsSinceEpoch}';
    final g = SocialGroup(
      id: id,
      name: name.trim(),
      description: description.trim(),
      category: category,
      ownerName: _meName,
      ownerId: _meId,
      city: city.trim(),
      isPrivate: isPrivate,
      maxMembers: maxMembers,
      // owner otomatik üye
      currentMemberCount: 1,
      createdAt: now,
      tags: List.unmodifiable(tags),
      visualSeed: now.microsecondsSinceEpoch % 8,
    );
    _groups.insert(0, g);
    _joined.add(id);
    // Owner'ı tam üye listesine kaydet (kurucu).
    _membersByGroup[id] = <GroupMemberProfile>[
      GroupMemberProfile(
        userId: _meId,
        displayName: _meName,
        role: 'owner',
        joinedAt: now,
      ),
    ];
    _notify();
    return g;
  }

  /// V1 Sprint 2 — Test/seed helper: harici üye ekle.
  ///
  /// Local repo gerçek auth simülasyonu yapmaz; ikinci kullanıcıyı doğrudan
  /// üye listesine eklemek için. Sadece test ve guest seed senaryoları
  /// kullanır; production'da hiçbir yerden çağrılmaz.
  void addMemberDirectly(String groupId, GroupMemberProfile profile) {
    _membersByGroup
        .putIfAbsent(groupId, () => <GroupMemberProfile>[])
        .add(profile);
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i >= 0) {
      _groups[i] = _groups[i].copyWith(
        currentMemberCount: _groups[i].currentMemberCount + 1,
      );
    }
    _notify();
  }

  // ─────────────────────────────────────── Messages

  @override
  Future<List<GroupMessage>> listMessages(String groupId) async {
    final src = _messages.where((m) => m.groupId == groupId).toList();
    src.sort((a, b) {
      // pinned önce
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return List.unmodifiable(src);
  }

  @override
  Future<void> postMessage(GroupMessage m) async {
    _messages.add(m);
    _notify();
  }

  // ─────────────────────────────────────── Private join requests (V1 P1-D)

  final List<GroupJoinRequest> _requests = <GroupJoinRequest>[];

  @override
  Future<GroupJoinRequest> requestJoinGroup(
    String groupId,
    {String? message,}
  ) async {
    final existingIdx = _requests.indexWhere(
      (r) => r.groupId == groupId && r.requesterId == _meId,
    );
    final now = DateTime.now();
    GroupJoinRequest req;
    if (existingIdx >= 0) {
      final old = _requests[existingIdx];
      if (old.status == GroupJoinRequestStatus.pending) {
        return old;
      }
      req = GroupJoinRequest(
        id: old.id,
        groupId: groupId,
        requesterId: _meId,
        status: GroupJoinRequestStatus.pending,
        message: message ?? old.message,
        createdAt: now,
      );
      _requests[existingIdx] = req;
    } else {
      req = GroupJoinRequest(
        id: 'r_${now.microsecondsSinceEpoch}',
        groupId: groupId,
        requesterId: _meId,
        status: GroupJoinRequestStatus.pending,
        message: message,
        createdAt: now,
      );
      _requests.add(req);
    }
    _notify();
    return req;
  }

  @override
  Future<GroupJoinRequest?> getMyJoinRequest(String groupId) async {
    for (final r in _requests) {
      if (r.groupId == groupId && r.requesterId == _meId) return r;
    }
    return null;
  }

  @override
  Future<List<GroupJoinRequest>> listPendingJoinRequests(String groupId) async {
    return List.unmodifiable(
      _requests.where(
        (r) =>
            r.groupId == groupId &&
            r.status == GroupJoinRequestStatus.pending,
      ),
    );
  }

  @override
  Future<int> pendingJoinRequestCount(String groupId) async {
    return _requests
        .where((r) =>
            r.groupId == groupId &&
            r.status == GroupJoinRequestStatus.pending)
        .length;
  }

  @override
  Future<GroupJoinRequest> approveJoinRequest(String requestId) async {
    final i = _requests.indexWhere((r) => r.id == requestId);
    if (i < 0) throw StateError('Request not found: $requestId');
    final old = _requests[i];
    final upd = GroupJoinRequest(
      id: old.id,
      groupId: old.groupId,
      requesterId: old.requesterId,
      status: GroupJoinRequestStatus.approved,
      message: old.message,
      createdAt: old.createdAt,
      decidedAt: DateTime.now(),
    );
    _requests[i] = upd;
    _joined.add(old.groupId);
    final gi = _groups.indexWhere((g) => g.id == old.groupId);
    if (gi >= 0) {
      _groups[gi] = _groups[gi]
          .copyWith(currentMemberCount: _groups[gi].currentMemberCount + 1);
    }
    // Requester'ı tam üye listesine ekle (placeholder profile bilgisiyle).
    _membersByGroup
        .putIfAbsent(old.groupId, () => <GroupMemberProfile>[])
        .add(GroupMemberProfile(
          userId: old.requesterId,
          displayName: 'FırınNet Kullanıcısı',
          role: 'member',
          joinedAt: DateTime.now(),
        ));
    _notify();
    return upd;
  }

  @override
  Future<GroupJoinRequest> rejectJoinRequest(String requestId) async {
    final i = _requests.indexWhere((r) => r.id == requestId);
    if (i < 0) throw StateError('Request not found: $requestId');
    final old = _requests[i];
    final upd = GroupJoinRequest(
      id: old.id,
      groupId: old.groupId,
      requesterId: old.requesterId,
      status: GroupJoinRequestStatus.rejected,
      message: old.message,
      createdAt: old.createdAt,
      decidedAt: DateTime.now(),
    );
    _requests[i] = upd;
    _notify();
    return upd;
  }

  // ─────────────────────────────────────── Sprint 2 — Members management

  @override
  Future<List<GroupMemberProfile>> listMembers(String groupId) async {
    final list = _membersByGroup[groupId];
    if (list == null) return const <GroupMemberProfile>[];
    final sorted = List<GroupMemberProfile>.from(list)
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return List.unmodifiable(sorted);
  }

  @override
  Future<void> removeMember(String groupId, String memberId) async {
    final gi = _groups.indexWhere((g) => g.id == groupId);
    if (gi < 0) throw StateError('group_not_found');
    final g = _groups[gi];
    if (g.ownerId != _meId) throw StateError('not_group_owner');
    if (memberId == g.ownerId) throw StateError('cannot_remove_owner');
    final list = _membersByGroup[groupId];
    if (list == null) throw StateError('member_not_found');
    final before = list.length;
    list.removeWhere((m) => m.userId == memberId);
    if (list.length == before) throw StateError('member_not_found');
    _groups[gi] = g.copyWith(
      currentMemberCount: (g.currentMemberCount - 1).clamp(0, 1 << 30),
    );
    _notify();
  }

  @override
  Future<GroupLeaveOutcome> leaveGroupSafely(String groupId) async {
    final gi = _groups.indexWhere((g) => g.id == groupId);
    if (gi < 0) throw StateError('group_not_found');
    final g = _groups[gi];
    final members = _membersByGroup.putIfAbsent(
      groupId,
      () => <GroupMemberProfile>[],
    );

    // Non-owner: kendisini çıkar.
    if (g.ownerId != _meId) {
      members.removeWhere((m) => m.userId == _meId);
      _joined.remove(groupId);
      _groups[gi] = g.copyWith(
        currentMemberCount: (g.currentMemberCount - 1).clamp(0, 1 << 30),
      );
      _notify();
      return GroupLeaveOutcome.left;
    }

    // Owner: en eski non-owner üyeyi bul.
    final candidates = members.where((m) => m.userId != _meId).toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

    if (candidates.isEmpty) {
      // Tek üye → grup kapatılır.
      _joined.remove(groupId);
      _groups.removeAt(gi);
      _membersByGroup.remove(groupId);
      _notify();
      return GroupLeaveOutcome.closed;
    }

    // Devir: en eski üyeyi owner yap.
    final next = candidates.first;
    final nextIdx = members.indexWhere((m) => m.userId == next.userId);
    members[nextIdx] = next.copyWith(role: 'owner');
    members.removeWhere((m) => m.userId == _meId);
    _joined.remove(groupId);
    _groups[gi] = SocialGroup(
      id: g.id,
      name: g.name,
      description: g.description,
      category: g.category,
      ownerName: next.displayName,
      ownerId: next.userId,
      city: g.city,
      isPrivate: g.isPrivate,
      maxMembers: g.maxMembers,
      currentMemberCount: (g.currentMemberCount - 1).clamp(0, 1 << 30),
      createdAt: g.createdAt,
      tags: g.tags,
      visualSeed: g.visualSeed,
    );
    _notify();
    return GroupLeaveOutcome.transferred;
  }

  @override
  Future<void> closeGroup(String groupId) async {
    final gi = _groups.indexWhere((g) => g.id == groupId);
    if (gi < 0) return;
    final g = _groups[gi];
    if (g.ownerId != _meId) throw StateError('not_group_owner');
    _groups.removeAt(gi);
    _membersByGroup.remove(groupId);
    _joined.remove(groupId);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;

  // ─────────────────────────────────────── Demo seed

  void _seed() {
    final now = DateTime.now();
    DateTime ago(Duration d) => now.subtract(d);

    final seedGroups = <SocialGroup>[
      SocialGroup(
        id: 'g_konya_unciler',
        name: 'Konya Unculer & Fırıncıları',
        description:
            'Konya bölgesinde un tedariği, fiyat değişimleri ve fırıncı '
            'arası bilgi paylaşımı. Yerel pazar için.',
        category: GroupCategory.regional,
        ownerName: 'Hasan Kara',
        ownerId: 'u_hasan',
        city: 'Konya',
        isPrivate: false,
        maxMembers: 250,
        currentMemberCount: 6,
        createdAt: ago(const Duration(days: 240)),
        tags: const ['konya', 'un', 'bölgesel'],
        visualSeed: 0,
      ),
      SocialGroup(
        id: 'g_eksi_maya',
        name: 'Ekşi Maya Atölyesi',
        description:
            'Ekşi maya başlatma, besleme, fermantasyon süreleri ve '
            'sıcaklık eğrileri üzerine deneyim paylaşımı.',
        category: GroupCategory.recipe,
        ownerName: 'Selin Ateş',
        ownerId: 'u_selin',
        city: '',
        isPrivate: false,
        maxMembers: 100,
        currentMemberCount: 4,
        createdAt: ago(const Duration(days: 95)),
        tags: const ['ekşimaya', 'fermantasyon', 'reçete'],
        visualSeed: 1,
      ),
      SocialGroup(
        id: 'g_taşfırın',
        name: 'Taş Fırın Ustaları',
        description:
            'Taş fırın bakımı, sıcaklık yönetimi, gece üretimi ve '
            'farklı ekmek tiplerinde deneyim paylaşımı.',
        category: GroupCategory.bakers,
        ownerName: 'Mehmet Taş Fırın',
        ownerId: 'u_mehmet',
        city: 'Gaziantep',
        isPrivate: false,
        maxMembers: 5,
        currentMemberCount: 5,
        createdAt: ago(const Duration(days: 380)),
        tags: const ['taşfırın', 'usta', 'gaziantep'],
        visualSeed: 2,
      ),
      SocialGroup(
        id: 'g_ekipman_alımsatım',
        name: 'Ekipman Alım & Satım',
        description:
            'Spiral mikser, hamur yoğurma, fırın, tezgah, vitrin — '
            'ikinci el ve sıfır ekipman ilanları, fiyat sorgulama.',
        category: GroupCategory.equipment,
        ownerName: 'Kara Endüstri',
        ownerId: 'u_kara',
        city: '',
        isPrivate: false,
        maxMembers: null, // sınırsız
        currentMemberCount: 8,
        createdAt: ago(const Duration(days: 520)),
        tags: const ['ekipman', 'mikser', 'fırın'],
        visualSeed: 3,
      ),
      SocialGroup(
        id: 'g_un_tip550',
        name: 'Un & Hammadde Pazarı',
        description:
            'Tip 550, ekstra, yeni hasat — analiz raporları, protein/W '
            'değerleri, üretici-fırıncı buluşması.',
        category: GroupCategory.flour,
        ownerName: 'Konya Değirmen',
        ownerId: 'u_kdg',
        city: 'Konya',
        isPrivate: false,
        maxMembers: 250,
        currentMemberCount: 7,
        createdAt: ago(const Duration(days: 180)),
        tags: const ['un', 'hammadde', 'tip550'],
        visualSeed: 4,
      ),
      SocialGroup(
        id: 'g_bayi_dagitim',
        name: 'Bayi & Dağıtım Ağı',
        description:
            'Bayilik, sevkiyat, peşin/vadeli çalışma deneyimi, tahsilat '
            'soruları. Şehirler arası deneyim paylaşımı.',
        category: GroupCategory.dealer,
        ownerName: 'Burak D.',
        ownerId: 'u_burak',
        city: '',
        isPrivate: false,
        maxMembers: 100,
        currentMemberCount: 3,
        createdAt: ago(const Duration(days: 60)),
        tags: const ['bayi', 'dağıtım'],
        visualSeed: 5,
      ),
      SocialGroup(
        id: 'g_usta_ilanlari',
        name: 'Usta Arayan Fırınlar',
        description:
            'Usta arıyor / iş arıyor — günlük ilanlar, gece vardiyası, '
            'taş fırın ustası, pastacı.',
        category: GroupCategory.jobs,
        ownerName: 'Ekmek Sepeti',
        ownerId: 'u_eks',
        city: '',
        isPrivate: false,
        maxMembers: 250,
        currentMemberCount: 5,
        createdAt: ago(const Duration(days: 30)),
        tags: const ['usta', 'iş', 'vardiya'],
        visualSeed: 6,
      ),
      SocialGroup(
        id: 'g_toptanci',
        name: 'Toptan Susam, Maya, Yağ',
        description:
            'Toptan tedarikçilere ulaşma, fiyat sorgulama, lojistik, '
            'minimum sipariş şartları.',
        category: GroupCategory.wholesale,
        ownerName: 'Urfa Susam',
        ownerId: 'u_urfa',
        city: 'Şanlıurfa',
        isPrivate: false,
        maxMembers: 50,
        currentMemberCount: 2,
        createdAt: ago(const Duration(days: 12)),
        tags: const ['susam', 'maya', 'yağ', 'toptan'],
        visualSeed: 7,
      ),
      SocialGroup(
        id: 'g_istanbul_pastane',
        name: 'İstanbul Pastane Topluluğu',
        description:
            'İstanbul içi pastane sahipleri ve usta-yardımcıları. '
            'Tedarik, ekipman, çalışan paylaşımı.',
        category: GroupCategory.regional,
        ownerName: 'Selin Ateş',
        ownerId: 'u_selin',
        city: 'İstanbul',
        isPrivate: true,
        maxMembers: 50,
        currentMemberCount: 3,
        createdAt: ago(const Duration(days: 45)),
        tags: const ['istanbul', 'pastane'],
        visualSeed: 0,
      ),
    ];
    _groups.addAll(seedGroups);

  }
}
