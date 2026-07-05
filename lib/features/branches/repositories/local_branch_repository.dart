import 'package:flutter/foundation.dart';

import '../models/branch_activity.dart';
import '../models/branch_models.dart';
import 'branch_repository.dart';

/// In-memory şube reposu — testler ve Supabase kapalı geliştirme için.
///
/// Server-side kuralların (izinli süreç tipi, suspended erişim kaybı,
/// bireysel-hedef, duplicate davet) davranışsal aynası burada da uygulanır
/// ki widget/repo testleri gerçek akışı sınayabilsin. Asıl güvenlik DB'dedir.
class LocalBranchRepository implements BranchRepository {
  LocalBranchRepository({bool seed = false, this.currentUserId = 'owner-1'}) {
    if (seed) _seed();
  }

  /// Aktif kullanıcı: owner-1 (ticari) / staff-1, staff-2 (bireysel).
  /// Testler davet→kabul gibi iki taraflı akışları TEK store üzerinde
  /// sınayabilsin diye değiştirilebilir bırakıldı (yalnız local).
  String currentUserId;

  final _changes = ValueNotifier<int>(0);
  @override
  ValueListenable<int> get changes => _changes;
  void _notify() => _changes.value++;

  final List<_BranchRow> _branches = [];
  final List<_MembershipRow> _memberships = [];
  final List<_InviteRow> _invites = [];
  final List<_ProcessRow> _processes = [];
  final List<BranchActivityEntry> _activity = [];

  /// FN-ID → (userId, accountType) sahte profil rehberi (yalnız local).
  final Map<String, (String, String)> knownProfiles = {
    'FN-2026-000001': ('staff-1', 'individual'),
    'FN-2026-000002': ('staff-2', 'individual'),
    'FN-2026-000003': ('whole-1', 'wholesaler'),
  };

  int _idSeq = 0;
  String _newId(String prefix) => '$prefix-${++_idSeq}';

  void _seed() {
    // Üretilen id'ler ('proc-1' vb.) seed'in sabit id'leriyle ÇAKIŞMASIN:
    // aynı id'li iki satır updateProcess/KPI hesaplarını bozar.
    _idSeq = 100;
    _branches.add(
      _BranchRow(
        id: 'branch-1',
        ownerId: 'owner-1',
        name: 'Merkez Şube',
        address: 'Fırın Cad. No:1',
        phone: '0312 000 00 00',
        isMain: true,
      ),
    );
    _branches.add(
      _BranchRow(id: 'branch-2', ownerId: 'owner-1', name: 'Çarşı Şube'),
    );
    _memberships.add(
      _MembershipRow(
        id: 'member-1',
        branchId: 'branch-1',
        ownerId: 'owner-1',
        userId: 'staff-1',
        role: BranchRole.production,
        permissions: const [
          BranchProcessType.productionNote,
          BranchProcessType.openingCheck,
        ],
      ),
    );
    _processes.add(
      _ProcessRow(
        id: 'proc-1',
        branchId: 'branch-1',
        ownerId: 'owner-1',
        createdBy: 'owner-1',
        type: BranchProcessType.openingCheck,
        title: 'Sabah açılış kontrolü',
      ),
    );
    _processes.add(
      _ProcessRow(
        id: 'proc-2',
        branchId: 'branch-1',
        ownerId: 'owner-1',
        createdBy: 'staff-1',
        type: BranchProcessType.dealerCollection,
        title: 'Bakkal Mehmet tahsilat',
        status: BranchProcessStatus.attention,
      ),
    );
    _activity.insertAll(0, [
      BranchActivityEntry(
        id: 'activity-seed-1',
        branchId: 'branch-1',
        event: BranchActivityEvent.processCreated,
        actorName: _displayName('owner-1'),
        createdAt: DateTime.now(),
      ),
      BranchActivityEntry(
        id: 'activity-seed-2',
        branchId: 'branch-1',
        event: BranchActivityEvent.statusChanged,
        actorName: _displayName('staff-1'),
        note: 'attention',
        createdAt: DateTime.now(),
      ),
    ]);
  }

  bool _isOwner(String branchId) =>
      _branches.any((b) => b.id == branchId && b.ownerId == currentUserId);

  /// Aktif şube sorumlusu mu? (is_active_branch_manager aynası)
  bool _isActiveManager(String branchId) {
    final m = _activeMembership(branchId);
    return m != null && m.role == BranchRole.branchManager;
  }

  /// Server RPC'lerinin activity log append'inin aynası (append-only).
  void _log(String branchId, BranchActivityEvent event, {String note = ''}) {
    _activity.insert(
      0,
      BranchActivityEntry(
        id: _newId('activity'),
        branchId: branchId,
        event: event,
        actorName: _displayName(currentUserId),
        note: note,
        createdAt: DateTime.now(),
      ),
    );
  }

  _MembershipRow? _activeMembership(String branchId) {
    for (final m in _memberships) {
      if (m.branchId == branchId &&
          m.userId == currentUserId &&
          m.status == BranchMembershipStatus.active) {
        return m;
      }
    }
    return null;
  }

  bool _canSee(String branchId) =>
      _isOwner(branchId) || _activeMembership(branchId) != null;

  bool _canWriteType(String branchId, BranchProcessType type) {
    if (_isOwner(branchId)) return true;
    final m = _activeMembership(branchId);
    if (m == null) return false;
    return m.role.hasAllProcessPermissions || m.permissions.contains(type);
  }

  Branch _toBranch(_BranchRow b) {
    final members = _memberships
        .where(
          (m) =>
              m.branchId == b.id && m.status == BranchMembershipStatus.active,
        )
        .toList();
    final open = _processes
        .where((p) => p.branchId == b.id && p.status.isOpen)
        .toList();
    _MembershipRow? manager;
    for (final m in members) {
      if (m.role == BranchRole.branchManager) {
        manager = m;
        break;
      }
    }
    return Branch(
      id: b.id,
      name: b.name,
      address: b.address,
      phone: b.phone,
      isActive: b.isActive,
      isMainBranch: b.isMain,
      memberCount: members.length,
      openProcessCount: open.length,
      attentionCount: open
          .where((p) => p.status == BranchProcessStatus.attention)
          .length,
      managerName: manager == null ? null : _displayName(manager.userId),
    );
  }

  String _displayName(String userId) {
    switch (userId) {
      case 'owner-1':
        return 'Patron';
      case 'staff-1':
        return 'Ahmet Usta';
      case 'staff-2':
        return 'Mehmet Kalfa';
      default:
        return userId;
    }
  }

  @override
  Future<List<Branch>> myBranches() async => _branches
      .where((b) => b.ownerId == currentUserId)
      .map(_toBranch)
      .toList(growable: false);

  @override
  Future<Branch?> branchById(String id) async {
    for (final b in _branches) {
      if (b.id == id && _canSee(id)) return _toBranch(b);
    }
    return null;
  }

  @override
  Future<String> createBranch({
    required String name,
    String address = '',
    String phone = '',
  }) async {
    final id = _newId('branch');
    _branches.add(
      _BranchRow(
        id: id,
        ownerId: currentUserId,
        name: name.trim(),
        address: address.trim(),
        phone: phone.trim(),
      ),
    );
    _notify();
    return id;
  }

  @override
  Future<void> setBranchActive(String id, bool active) async {
    for (final b in _branches) {
      if (b.id == id && b.ownerId == currentUserId) b.isActive = active;
    }
    _notify();
  }

  @override
  Future<BranchOverview> overview() async {
    final mine = _branches.where((b) => b.ownerId == currentUserId).toList();
    final ids = mine.map((b) => b.id).toSet();
    return BranchOverview(
      totalBranches: mine.length,
      activeMembers: _memberships
          .where(
            (m) =>
                ids.contains(m.branchId) &&
                m.status == BranchMembershipStatus.active,
          )
          .length,
      openProcesses: _processes
          .where((p) => ids.contains(p.branchId) && p.status.isOpen)
          .length,
      pendingInvites: _invites
          .where((i) => i.ownerId == currentUserId && i.pending)
          .length,
      attentionProcesses: _processes
          .where(
            (p) =>
                ids.contains(p.branchId) &&
                p.status == BranchProcessStatus.attention,
          )
          .length,
      completedToday: _processes.where((p) {
        if (!ids.contains(p.branchId) || p.completedAt == null) return false;
        final now = DateTime.now();
        final c = p.completedAt!;
        return c.year == now.year && c.month == now.month && c.day == now.day;
      }).length,
    );
  }

  @override
  Future<List<BranchMembership>> branchMembers(String branchId) async {
    // RLS aynası: owner + aktif manager tüm listeyi, normal aktif üye
    // yalnız kendi satırını görür.
    final manages = _isOwner(branchId) || _isActiveManager(branchId);
    if (!manages && _activeMembership(branchId) == null) return const [];
    return _memberships
        .where(
          (m) =>
              m.branchId == branchId &&
              m.status != BranchMembershipStatus.removed &&
              (manages || m.userId == currentUserId),
        )
        .map(
          (m) => BranchMembership(
            id: m.id,
            branchId: m.branchId,
            userId: m.userId,
            role: m.role,
            status: m.status,
            permissions: m.permissions,
            memberName: _displayName(m.userId),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<BranchInvite>> branchPendingInvites(String branchId) async {
    if (!_isOwner(branchId) && !_isActiveManager(branchId)) return const [];
    return _invites
        .where((i) => i.branchId == branchId && i.pending)
        .map(_toInvite)
        .toList(growable: false);
  }

  BranchInvite _toInvite(_InviteRow i) => BranchInvite(
    id: i.id,
    branchId: i.branchId,
    role: i.role,
    branchName: _branches
        .firstWhere(
          (b) => b.id == i.branchId,
          orElse: () => _BranchRow(id: '', ownerId: '', name: '—'),
        )
        .name,
    ownerName: _displayName(i.ownerId),
    invitedName: _displayName(i.invitedUserId),
    permissions: i.permissions,
  );

  @override
  Future<String> createStaffInvite({
    required String branchId,
    required String firinnetId,
    required BranchRole role,
    List<BranchProcessType> permissions = const [],
    String note = '',
  }) async {
    // Server kurallarının aynası — nötr hatalar korunur. V2: aktif
    // branch_manager kendi şubesine yalnız ALT ROL davet edebilir.
    final isOwner = _isOwner(branchId);
    if (!isOwner && !_isActiveManager(branchId)) {
      throw StateError('not branch owner');
    }
    if (!isOwner && role == BranchRole.branchManager) {
      throw StateError('Şube sorumlusu bu rolü veremez.');
    }
    final target = knownProfiles[firinnetId.trim().toUpperCase()];
    if (target == null || target.$2 != 'individual') {
      throw StateError('Davet oluşturulamadı. FırınNet ID\'yi kontrol edin.');
    }
    final (targetId, _) = target;
    if (_memberships.any(
      (m) =>
          m.branchId == branchId &&
          m.userId == targetId &&
          m.status == BranchMembershipStatus.active,
    )) {
      throw StateError('Bu kullanıcı zaten şube personeli.');
    }
    if (_invites.any(
      (i) => i.branchId == branchId && i.invitedUserId == targetId && i.pending,
    )) {
      throw StateError('Bu kullanıcı için bekleyen davet var.');
    }
    final id = _newId('invite');
    _invites.add(
      _InviteRow(
        id: id,
        branchId: branchId,
        // Davetin sahibi her zaman şube sahibidir (manager davetinde de).
        ownerId: _branches.firstWhere((b) => b.id == branchId).ownerId,
        invitedBy: currentUserId,
        invitedUserId: targetId,
        role: role,
        permissions: List.of(permissions),
      ),
    );
    _log(branchId, BranchActivityEvent.inviteCreated);
    _notify();
    return id;
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    for (final i in _invites) {
      if (i.id == inviteId &&
          (i.ownerId == currentUserId ||
              (i.invitedBy == currentUserId && _isActiveManager(i.branchId)))) {
        i.pending = false;
      }
    }
    _notify();
  }

  /// Üyelik üzerinde işlem yetkisi: owner tam; aktif manager yalnız kendi
  /// şubesinin non-manager, kendisi olmayan üyeleri (server aynası).
  _MembershipRow _requireManageableMembership(String membershipId) {
    for (final m in _memberships) {
      if (m.id != membershipId) continue;
      if (m.ownerId == currentUserId) return m;
      if (_isActiveManager(m.branchId) &&
          m.userId != currentUserId &&
          m.role != BranchRole.branchManager) {
        return m;
      }
    }
    throw StateError('membership not found');
  }

  @override
  Future<void> setMembershipStatus(
    String membershipId,
    BranchMembershipStatus status,
  ) async {
    final m = _requireManageableMembership(membershipId);
    m.status = status;
    _log(
      m.branchId,
      BranchActivityEvent.membershipChanged,
      note: status.persistKey,
    );
    _notify();
  }

  @override
  Future<void> updateMembershipPermissions(
    String membershipId,
    List<BranchProcessType> permissions,
  ) async {
    final m = _requireManageableMembership(membershipId);
    m.permissions
      ..clear()
      ..addAll(permissions);
    _log(
      m.branchId,
      BranchActivityEvent.membershipChanged,
      note: 'permissions',
    );
    _notify();
  }

  @override
  Future<List<BranchActivityEntry>> activity(String branchId) async {
    if (!_canSee(branchId)) return const [];
    return _activity
        .where((a) => a.branchId == branchId)
        .toList(growable: false);
  }

  @override
  Future<List<BranchMembership>> myMemberships() async => _memberships
      .where(
        (m) =>
            m.userId == currentUserId &&
            m.status == BranchMembershipStatus.active,
      )
      .map(
        (m) => BranchMembership(
          id: m.id,
          branchId: m.branchId,
          userId: m.userId,
          role: m.role,
          status: m.status,
          permissions: m.permissions,
          branchName: _branches
              .firstWhere(
                (b) => b.id == m.branchId,
                orElse: () => _BranchRow(id: '', ownerId: '', name: '—'),
              )
              .name,
        ),
      )
      .toList(growable: false);

  @override
  Future<List<BranchInvite>> myPendingInvites() async => _invites
      .where((i) => i.invitedUserId == currentUserId && i.pending)
      .map(_toInvite)
      .toList(growable: false);

  @override
  Future<void> respondInvite(String inviteId, {required bool accept}) async {
    for (final i in _invites) {
      if (i.id != inviteId || i.invitedUserId != currentUserId || !i.pending) {
        continue;
      }
      i.pending = false;
      if (accept) {
        _memberships.removeWhere(
          (m) => m.branchId == i.branchId && m.userId == currentUserId,
        );
        _memberships.add(
          _MembershipRow(
            id: _newId('member'),
            branchId: i.branchId,
            ownerId: i.ownerId,
            userId: currentUserId,
            role: i.role,
            permissions: List.of(i.permissions),
          ),
        );
      }
      _log(
        i.branchId,
        BranchActivityEvent.inviteResponded,
        note: accept ? 'accepted' : 'rejected',
      );
    }
    _notify();
  }

  @override
  Future<List<BranchProcess>> processes(String branchId) async {
    if (!_canSee(branchId)) return const [];
    return _processes
        .where((p) => p.branchId == branchId)
        .map(
          (p) => BranchProcess(
            id: p.id,
            branchId: p.branchId,
            type: p.type,
            title: p.title,
            note: p.note,
            status: p.status,
            createdByName: _displayName(p.createdBy),
            createdAt: p.createdAt,
            completedAt: p.completedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<String> createProcess({
    required String branchId,
    required BranchProcessType type,
    required String title,
    String note = '',
  }) async {
    if (!_canWriteType(branchId, type)) {
      throw StateError('Bu süreç tipi için yetkin yok.');
    }
    final owner = _branches.firstWhere((b) => b.id == branchId).ownerId;
    final id = _newId('proc');
    _processes.add(
      _ProcessRow(
        id: id,
        branchId: branchId,
        ownerId: owner,
        createdBy: currentUserId,
        type: type,
        title: title.trim(),
        note: note.trim(),
      ),
    );
    _log(branchId, BranchActivityEvent.processCreated);
    _notify();
    return id;
  }

  @override
  Future<void> updateProcess(
    String processId, {
    BranchProcessStatus? status,
    String? note,
  }) async {
    for (final p in _processes) {
      if (p.id != processId) continue;
      if (!_canWriteType(p.branchId, p.type)) {
        throw StateError('Bu süreç tipi için yetkin yok.');
      }
      if (status != null) {
        p.status = status;
        p.completedAt = status == BranchProcessStatus.completed
            ? DateTime.now()
            : null;
      }
      if (note != null && note.trim().isNotEmpty) p.note = note.trim();
      _log(
        p.branchId,
        status != null
            ? BranchActivityEvent.statusChanged
            : BranchActivityEvent.processUpdated,
        note: status?.persistKey ?? '',
      );
    }
    _notify();
  }

  @override
  void dispose() => _changes.dispose();
}

class _BranchRow {
  _BranchRow({
    required this.id,
    required this.ownerId,
    required this.name,
    this.address = '',
    this.phone = '',
    this.isMain = false,
  });
  final String id;
  final String ownerId;
  String name;
  String address;
  String phone;
  bool isActive = true;
  final bool isMain;
}

class _MembershipRow {
  _MembershipRow({
    required this.id,
    required this.branchId,
    required this.ownerId,
    required this.userId,
    required this.role,
    List<BranchProcessType> permissions = const [],
  }) : permissions = List.of(permissions);
  final String id;
  final String branchId;
  final String ownerId;
  final String userId;
  final BranchRole role;
  final List<BranchProcessType> permissions;
  BranchMembershipStatus status = BranchMembershipStatus.active;
}

class _InviteRow {
  _InviteRow({
    required this.id,
    required this.branchId,
    required this.ownerId,
    required this.invitedUserId,
    required this.role,
    String? invitedBy,
    this.permissions = const [],
  }) : invitedBy = invitedBy ?? ownerId;
  final String id;
  final String branchId;
  final String ownerId;
  final String invitedBy;
  final String invitedUserId;
  final BranchRole role;
  final List<BranchProcessType> permissions;
  bool pending = true;
}

class _ProcessRow {
  _ProcessRow({
    required this.id,
    required this.branchId,
    required this.ownerId,
    required this.createdBy,
    required this.type,
    required this.title,
    this.note = '',
    this.status = BranchProcessStatus.pending,
  }) : createdAt = DateTime.now();
  final String id;
  final String branchId;
  final String ownerId;
  final String createdBy;
  final BranchProcessType type;
  String title;
  String note;
  BranchProcessStatus status;
  final DateTime createdAt;
  DateTime? completedAt;
}
