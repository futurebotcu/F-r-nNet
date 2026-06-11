// FırınNet UGC Safety V1 — Guarded wrapper.
//
// Karar: şikayet ve engelleme AUTH GEREKTİRİR (V1). Guest, write
// aksiyonlarında olduğu gibi AuthRequiredSheet görür — anonim report
// tasarımı (kötüye kullanım riski) bilinçli olarak kapsam dışı.

import '../../auth/services/auth_required_guard.dart';
import '../models/report_models.dart';
import 'safety_repository.dart';

class GuardedSafetyRepository implements SafetyRepository {
  GuardedSafetyRepository({required this.inner, required this.canWriteCheck});

  final SafetyRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  @override
  Future<ReportResult> reportContent({
    required ReportTargetType targetType,
    required String targetId,
    String? reportedUserId,
    required ReportReason reason,
    String? details,
  }) {
    _requireWrite('içerik şikayet etmek');
    return inner.reportContent(
      targetType: targetType,
      targetId: targetId,
      reportedUserId: reportedUserId,
      reason: reason,
      details: details,
    );
  }

  @override
  Future<BlockResult> blockUser(String userId) {
    _requireWrite('kullanıcı engellemek');
    return inner.blockUser(userId);
  }

  @override
  Future<void> unblockUser(String userId) {
    _requireWrite('engel kaldırmak');
    return inner.unblockUser(userId);
  }

  // Read — guard'sız (boş set döner; guest zaten kimseyi engelleyemez).
  @override
  Future<Set<String>> listBlockedUserIds() => inner.listBlockedUserIds();

  @override
  Stream<void> watch() => inner.watch();
}
