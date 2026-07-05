import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/branch_activity.dart';
import '../models/branch_models.dart';
import 'branch_repository.dart';

/// Supabase şube reposu.
///
/// Tüm yazma yolları SECURITY DEFINER RPC'lere gider (create_branch_invite /
/// respond_branch_invite / cancel_branch_invite / set_branch_membership_status
/// / create_branch_process / update_branch_process); izin ve kimlik denetimi
/// server'dadır. Hata mesajları FN-AUDIT-012 gereği nötrleştirilir — FN-ID
/// var/yok/tip bilgisi client mesajından sızdırılmaz.
class SupabaseBranchRepository implements BranchRepository {
  SupabaseBranchRepository(this._client);

  final sb.SupabaseClient _client;

  final _changes = ValueNotifier<int>(0);
  @override
  ValueListenable<int> get changes => _changes;
  void _notify() => _changes.value++;

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Oturum bulunamadı.');
    return id;
  }

  static const _neutralInviteError =
      'Davet oluşturulamadı. FırınNet ID\'yi kontrol edin.';

  /// Diğer kullanıcıların display_name'i — profiles RLS owner-only olduğu
  /// için embedded join yerine mevcut `public_profile_snapshot` RPC'si
  /// kullanılır (groups V1 kalıbı; yalnız güvenli kolonlar döner).
  /// RPC hatasında sessizce boş map — UI fallback metnini uygular.
  Future<Map<String, String>> _displayNames(Iterable<String> ids) async {
    final unique = ids.toSet().toList(growable: false);
    if (unique.isEmpty) return const {};
    try {
      final rows = await _client.rpc(
        'public_profile_snapshot',
        params: <String, dynamic>{'p_user_ids': unique},
      );
      if (rows is! List) return const {};
      return <String, String>{
        for (final p in rows.cast<Map<String, dynamic>>())
          if (p['display_name'] is String)
            p['id'] as String: p['display_name'] as String,
      };
    } catch (_) {
      return const {};
    }
  }

  // ── Patron tarafı ──

  @override
  Future<List<Branch>> myBranches() async {
    final uid = _requireUserId();
    final rows = await _client
        .from('branches')
        .select('id, name, address, phone, status, is_main_branch')
        .eq('owner_id', uid)
        .order('created_at');
    final members = await _client
        .from('branch_memberships')
        .select('branch_id, user_id, role')
        .eq('owner_id', uid)
        .eq('status', 'active');
    final processes = await _client
        .from('branch_processes')
        .select('branch_id, status')
        .eq('owner_id', uid)
        .neq('status', 'completed');
    final memberRows = (members as List).cast<Map<String, dynamic>>();
    final names = await _displayNames(
      memberRows
          .where((m) => m['role'] == BranchRole.branchManager.persistKey)
          .map((m) => m['user_id'] as String),
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) {
          final id = r['id'] as String;
          final myMembers = memberRows
              .where((m) => m['branch_id'] == id)
              .toList();
          final open = (processes as List)
              .cast<Map<String, dynamic>>()
              .where((p) => p['branch_id'] == id)
              .toList();
          String? manager;
          for (final m in myMembers) {
            if (m['role'] == BranchRole.branchManager.persistKey) {
              manager = names[m['user_id'] as String];
              break;
            }
          }
          return Branch(
            id: id,
            name: r['name'] as String,
            address: (r['address'] as String?) ?? '',
            phone: (r['phone'] as String?) ?? '',
            isActive: r['status'] == 'active',
            isMainBranch: (r['is_main_branch'] as bool?) ?? false,
            memberCount: myMembers.length,
            openProcessCount: open.length,
            attentionCount: open
                .where((p) => p['status'] == 'attention')
                .length,
            managerName: manager,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Branch?> branchById(String id) async {
    final all = await myBranches();
    for (final b in all) {
      if (b.id == id) return b;
    }
    // Üye görünümü (bireysel): tek şube satırı RLS ile gelir.
    final rows = await _client
        .from('branches')
        .select('id, name, address, phone, status, is_main_branch')
        .eq('id', id)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    final r = list.first;
    return Branch(
      id: r['id'] as String,
      name: r['name'] as String,
      address: (r['address'] as String?) ?? '',
      phone: (r['phone'] as String?) ?? '',
      isActive: r['status'] == 'active',
      isMainBranch: (r['is_main_branch'] as bool?) ?? false,
    );
  }

  @override
  Future<String> createBranch({
    required String name,
    String address = '',
    String phone = '',
  }) async {
    final uid = _requireUserId();
    final rows = await _client
        .from('branches')
        .insert(<String, dynamic>{
          'owner_id': uid,
          'name': name.trim(),
          if (address.trim().isNotEmpty) 'address': address.trim(),
          if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        })
        .select('id');
    _notify();
    return (rows as List).cast<Map<String, dynamic>>().first['id'] as String;
  }

  @override
  Future<void> setBranchActive(String id, bool active) async {
    _requireUserId();
    await _client
        .from('branches')
        .update({'status': active ? 'active' : 'passive'})
        .eq('id', id);
    _notify();
  }

  @override
  Future<BranchOverview> overview() async {
    final uid = _requireUserId();
    final branches = await myBranches();
    final invites = await _client
        .from('branch_invites')
        .select('id')
        .eq('owner_id', uid)
        .eq('status', 'pending');
    // Bugün tamamlananlar: gün başlangıcı lokal saatle hesaplanır (UTC'ye
    // çevrilerek sorgulanır) — "bugün" fırıncının günüdür.
    final todayStart = DateTime.now();
    final localMidnight = DateTime(
      todayStart.year,
      todayStart.month,
      todayStart.day,
    );
    final completed = await _client
        .from('branch_processes')
        .select('id')
        .eq('owner_id', uid)
        .eq('status', 'completed')
        .gte('completed_at', localMidnight.toUtc().toIso8601String());
    var members = 0;
    var open = 0;
    var attention = 0;
    for (final b in branches) {
      members += b.memberCount;
      open += b.openProcessCount;
      attention += b.attentionCount;
    }
    return BranchOverview(
      totalBranches: branches.length,
      activeMembers: members,
      openProcesses: open,
      pendingInvites: (invites as List).length,
      attentionProcesses: attention,
      completedToday: (completed as List).length,
    );
  }

  @override
  Future<List<BranchMembership>> branchMembers(String branchId) async {
    _requireUserId();
    final rows = await _client
        .from('branch_memberships')
        .select('id, branch_id, user_id, role, permissions, status')
        .eq('branch_id', branchId)
        .neq('status', 'removed')
        .order('created_at');
    final list = (rows as List).cast<Map<String, dynamic>>();
    final names = await _displayNames(list.map((m) => m['user_id'] as String));
    return list
        .map((r) => _membershipFromRow(r, names: names))
        .toList(growable: false);
  }

  BranchMembership _membershipFromRow(
    Map<String, dynamic> r, {
    Map<String, String> names = const {},
  }) => BranchMembership(
    id: r['id'] as String,
    branchId: r['branch_id'] as String,
    userId: r['user_id'] as String,
    role: BranchRoleMeta.fromKey(r['role'] as String),
    status: BranchMembershipStatusMeta.fromKey(r['status'] as String),
    permissions: _permsFromJson(r['permissions']),
    memberName: names[r['user_id'] as String] ?? '',
    branchName: ((r['branch'] as Map?)?['name'] as String?) ?? '',
  );

  List<BranchProcessType> _permsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map(BranchProcessTypeMeta.fromKey)
        .toList(growable: false);
  }

  @override
  Future<List<BranchInvite>> branchPendingInvites(String branchId) async {
    _requireUserId();
    final rows = await _client
        .from('branch_invites')
        .select('id, branch_id, invited_user_id, role, permissions, created_at')
        .eq('branch_id', branchId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final names = await _displayNames(
      list.map((r) => r['invited_user_id'] as String),
    );
    return list
        .map((r) => _inviteFromRow(r, names: names))
        .toList(growable: false);
  }

  BranchInvite _inviteFromRow(
    Map<String, dynamic> r, {
    Map<String, String> names = const {},
  }) => BranchInvite(
    id: r['id'] as String,
    branchId: r['branch_id'] as String,
    role: BranchRoleMeta.fromKey(r['role'] as String),
    permissions: _permsFromJson(r['permissions']),
    branchName: ((r['branch'] as Map?)?['name'] as String?) ?? '',
    ownerName: names[r['owner_id'] as String?] ?? '',
    invitedName: names[r['invited_user_id'] as String?] ?? '',
    createdAt: DateTime.tryParse((r['created_at'] as String?) ?? ''),
  );

  @override
  Future<String> createStaffInvite({
    required String branchId,
    required String firinnetId,
    required BranchRole role,
    List<BranchProcessType> permissions = const [],
    String note = '',
  }) async {
    _requireUserId();
    try {
      final id = await _client.rpc(
        'create_branch_invite',
        params: <String, dynamic>{
          'p_branch_id': branchId,
          'p_target_firinnet_id': firinnetId,
          'p_role': role.persistKey,
          'p_permissions': permissions
              .map((p) => p.persistKey)
              .toList(growable: false),
          if (note.trim().isNotEmpty) 'p_note': note.trim(),
        },
      );
      _notify();
      return id as String;
    } on sb.PostgrestException catch (e) {
      final m = e.message;
      if (m.contains('too many invites')) {
        throw StateError(
          'Çok fazla davet denemesi. Lütfen biraz sonra tekrar dene.',
        );
      }
      if (m.contains('already a member')) {
        throw StateError('Bu kullanıcı zaten şube personeli.');
      }
      if (m.contains('invite already pending')) {
        throw StateError('Bu kullanıcı için bekleyen davet var.');
      }
      if (m.contains('role not allowed')) {
        throw StateError('Şube sorumlusu bu rolü veremez.');
      }
      // FN-ID var/yok/tip/format → tek nötr mesaj (sızıntı yok).
      throw StateError(_neutralInviteError);
    }
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    _requireUserId();
    await _client.rpc(
      'cancel_branch_invite',
      params: <String, dynamic>{'p_invite_id': inviteId},
    );
    _notify();
  }

  @override
  Future<void> setMembershipStatus(
    String membershipId,
    BranchMembershipStatus status,
  ) async {
    _requireUserId();
    await _client.rpc(
      'set_branch_membership_status',
      params: {'p_membership_id': membershipId, 'p_status': status.persistKey},
    );
    _notify();
  }

  @override
  Future<void> updateMembershipPermissions(
    String membershipId,
    List<BranchProcessType> permissions,
  ) async {
    _requireUserId();
    try {
      await _client.rpc(
        'update_branch_membership_permissions',
        params: <String, dynamic>{
          'p_membership_id': membershipId,
          'p_permissions': permissions
              .map((p) => p.persistKey)
              .toList(growable: false),
        },
      );
      _notify();
    } on sb.PostgrestException {
      throw StateError('İzinler güncellenemedi. Tekrar dene.');
    }
  }

  @override
  Future<List<BranchActivityEntry>> activity(String branchId) async {
    _requireUserId();
    final rows = await _client
        .from('branch_activity_log')
        .select('id, branch_id, actor_id, event_type, note, created_at')
        .eq('branch_id', branchId)
        .order('created_at', ascending: false)
        .limit(100);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final names = await _displayNames(list.map((r) => r['actor_id'] as String));
    return list
        .map(
          (r) => BranchActivityEntry(
            id: r['id'] as String,
            branchId: r['branch_id'] as String,
            event: BranchActivityEventMeta.fromKey(r['event_type'] as String),
            actorName: names[r['actor_id'] as String] ?? '',
            note: (r['note'] as String?) ?? '',
            createdAt: DateTime.tryParse((r['created_at'] as String?) ?? ''),
          ),
        )
        .toList(growable: false);
  }

  // ── Bireysel taraf ──

  @override
  Future<List<BranchMembership>> myMemberships() async {
    final uid = _requireUserId();
    final rows = await _client
        .from('branch_memberships')
        .select(
          'id, branch_id, user_id, role, permissions, status, '
          'branch:branches!branch_id(name)',
        )
        .eq('user_id', uid)
        .eq('status', 'active')
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_membershipFromRow)
        .toList(growable: false);
  }

  @override
  Future<List<BranchInvite>> myPendingInvites() async {
    _requireUserId();
    // Kabul öncesi davetli şube satırını RLS gereği göremez; davet kartı
    // bağlamı (şube adı + davet eden) parametresiz SECURITY DEFINER RPC'den
    // gelir — yalnız çağıranın kendi pending davetleri döner.
    final rows = await _client.rpc('my_branch_invite_contexts');
    if (rows is! List) return const [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(
          (r) => BranchInvite(
            id: r['invite_id'] as String,
            branchId: r['branch_id'] as String,
            role: BranchRoleMeta.fromKey(r['role'] as String),
            permissions: _permsFromJson(r['permissions']),
            branchName: (r['branch_name'] as String?) ?? '',
            ownerName: (r['owner_name'] as String?) ?? '',
            createdAt: DateTime.tryParse((r['created_at'] as String?) ?? ''),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> respondInvite(String inviteId, {required bool accept}) async {
    _requireUserId();
    await _client.rpc(
      'respond_branch_invite',
      params: <String, dynamic>{'p_invite_id': inviteId, 'p_accept': accept},
    );
    _notify();
  }

  // ── Süreçler ──

  @override
  Future<List<BranchProcess>> processes(String branchId) async {
    _requireUserId();
    final rows = await _client
        .from('branch_processes')
        .select(
          'id, branch_id, created_by, type, title, note, status, due_at, '
          'created_at, completed_at',
        )
        .eq('branch_id', branchId)
        .order('created_at', ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final names = await _displayNames(
      list.map((r) => r['created_by'] as String),
    );
    return list
        .map((r) {
          return BranchProcess(
            id: r['id'] as String,
            branchId: r['branch_id'] as String,
            type: BranchProcessTypeMeta.fromKey(r['type'] as String),
            title: r['title'] as String,
            note: (r['note'] as String?) ?? '',
            status: BranchProcessStatusMeta.fromKey(r['status'] as String),
            createdByName: names[r['created_by'] as String] ?? '',
            createdAt: DateTime.tryParse((r['created_at'] as String?) ?? ''),
            dueAt: DateTime.tryParse((r['due_at'] as String?) ?? ''),
            completedAt: DateTime.tryParse(
              (r['completed_at'] as String?) ?? '',
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<String> createProcess({
    required String branchId,
    required BranchProcessType type,
    required String title,
    String note = '',
  }) async {
    _requireUserId();
    try {
      final id = await _client.rpc(
        'create_branch_process',
        params: <String, dynamic>{
          'p_branch_id': branchId,
          'p_type': type.persistKey,
          'p_title': title.trim(),
          if (note.trim().isNotEmpty) 'p_note': note.trim(),
        },
      );
      _notify();
      return id as String;
    } on sb.PostgrestException catch (e) {
      if (e.message.contains('not allowed')) {
        throw StateError('Bu süreç tipi için yetkin yok.');
      }
      throw StateError('Süreç eklenemedi. Tekrar dene.');
    }
  }

  @override
  Future<void> updateProcess(
    String processId, {
    BranchProcessStatus? status,
    String? note,
  }) async {
    _requireUserId();
    try {
      await _client.rpc(
        'update_branch_process',
        params: <String, dynamic>{
          'p_process_id': processId,
          if (status != null) 'p_status': status.persistKey,
          if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
        },
      );
      _notify();
    } on sb.PostgrestException catch (e) {
      if (e.message.contains('not allowed')) {
        throw StateError('Bu süreç tipi için yetkin yok.');
      }
      throw StateError('Süreç güncellenemedi. Tekrar dene.');
    }
  }

  @override
  void dispose() => _changes.dispose();
}
