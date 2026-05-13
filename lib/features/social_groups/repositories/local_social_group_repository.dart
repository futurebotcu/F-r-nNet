import 'dart:async';

import '../models/group_category.dart';
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
    if (g.isFull) return GroupJoinResult.full;
    _groups[i] = g.copyWith(currentMemberCount: g.currentMemberCount + 1);
    _joined.add(id);
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
    _notify();
    return g;
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
        currentMemberCount: 187,
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
        currentMemberCount: 84,
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
        maxMembers: 100,
        currentMemberCount: 100,
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
        currentMemberCount: 412,
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
        currentMemberCount: 156,
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
        currentMemberCount: 67,
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
        currentMemberCount: 143,
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
        currentMemberCount: 38,
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
        currentMemberCount: 28,
        createdAt: ago(const Duration(days: 45)),
        tags: const ['istanbul', 'pastane'],
        visualSeed: 0,
      ),
    ];
    _groups.addAll(seedGroups);

    // Mevcut kullanıcı 2 gruba zaten üye gibi — ilk açılışta dolu görünür.
    _joined.addAll(['g_eksi_maya', 'g_un_tip550']);

    // Mock mesajlar (3 grup için)
    _messages.addAll([
      GroupMessage(
        id: 'm1',
        groupId: 'g_eksi_maya',
        authorName: 'Hasan Kara',
        authorRole: 'Usta Fırıncı · Konya',
        text: 'Bugün Tip 550 un kullanan var mı? Yeni hasattan numune '
            'aldım, protein 13.2 — ekşi mayada nasıl davranıyor?',
        createdAt: ago(const Duration(hours: 2)),
        isPinned: true,
        reactionCount: 12,
      ),
      GroupMessage(
        id: 'm2',
        groupId: 'g_eksi_maya',
        authorName: 'Selin Ateş',
        authorRole: 'Pastacı · İstanbul',
        text: 'Simitte yaz mayası oranını düşüren oldu mu? %0.8\'e '
            'çekince fermantasyon süresini uzattım, sonuç çok güzel.',
        createdAt: ago(const Duration(hours: 5)),
        reactionCount: 8,
      ),
      GroupMessage(
        id: 'm3',
        groupId: 'g_un_tip550',
        authorName: 'Konya Değirmen',
        authorRole: 'Uncu · Toptan',
        text: 'Yeni hasat ekstra unu çıktı, 25 kg paket toplu alımda '
            'avantajlı. Protein 13.2, glüten W 290.',
        createdAt: ago(const Duration(hours: 8)),
        isPinned: true,
        reactionCount: 21,
      ),
      GroupMessage(
        id: 'm4',
        groupId: 'g_konya_unciler',
        authorName: 'Mehmet Taş Fırın',
        authorRole: 'Fırın Sahibi · Gaziantep',
        text: 'Konya\'dan uygun susam tedarikçisi arıyorum. Kg fiyatı '
            've minimum sipariş bilgisi olan?',
        createdAt: ago(const Duration(hours: 18)),
        reactionCount: 6,
      ),
      GroupMessage(
        id: 'm5',
        groupId: 'g_ekipman_alımsatım',
        authorName: 'Kara Endüstri',
        authorRole: 'Ekipman · İstanbul',
        text: 'Spiral mikser için ikinci el önerisi olan var mı? 80 L, '
            'paslanmaz, 3 hız tercihim.',
        createdAt: ago(const Duration(hours: 22)),
        reactionCount: 4,
      ),
    ]);
  }
}
