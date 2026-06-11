// FırınNet UGC Safety V1 — in-memory implementasyon (guest/local mod + test).
//
// Supabase ile aynı sözleşme: duplicate report → duplicate, self-target →
// SelfTargetException, duplicate block → alreadyBlocked.

import 'dart:async';

import '../models/report_models.dart';
import 'safety_repository.dart';

class LocalSafetyRepository implements SafetyRepository {
  LocalSafetyRepository({String currentUserId = 'me_misafir'})
      : _meId = currentUserId;

  final String _meId;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// (targetType, targetId) → report edildi.
  final Set<String> _reports = <String>{};
  final Set<String> _blocked = <String>{};

  void _notify() => _changes.add(null);

  String _reportKey(ReportTargetType t, String id) => '${t.persistKey}:$id';

  @override
  Future<ReportResult> reportContent({
    required ReportTargetType targetType,
    required String targetId,
    String? reportedUserId,
    required ReportReason reason,
    String? details,
  }) async {
    if (reportedUserId != null && reportedUserId == _meId) {
      throw const SelfTargetException();
    }
    final key = _reportKey(targetType, targetId);
    if (_reports.contains(key)) return ReportResult.duplicate;
    _reports.add(key);
    return ReportResult.submitted;
  }

  @override
  Future<BlockResult> blockUser(String userId) async {
    if (userId == _meId) throw const SelfTargetException();
    if (_blocked.contains(userId)) return BlockResult.alreadyBlocked;
    _blocked.add(userId);
    _notify();
    return BlockResult.blocked;
  }

  @override
  Future<void> unblockUser(String userId) async {
    if (_blocked.remove(userId)) _notify();
  }

  @override
  Future<Set<String>> listBlockedUserIds() async =>
      Set<String>.unmodifiable(_blocked);

  @override
  Stream<void> watch() => _changes.stream;
}
