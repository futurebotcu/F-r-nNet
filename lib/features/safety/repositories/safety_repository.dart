// FırınNet UGC Safety V1 — şikayet + engelleme repository sözleşmesi.

import '../models/report_models.dart';

/// Kendi içeriğini şikayet etme / kendini engelleme denemesinde fırlatılır.
/// UI bu durumu hiç sunmamalı (menüde gizli); repo katmanı defense-in-depth.
class SelfTargetException implements Exception {
  const SelfTargetException();
}

abstract class SafetyRepository {
  /// İçeriği şikayet eder. İçerik SİLİNMEZ; moderasyon kuyruğuna düşer.
  /// Aynı hedefe ikinci şikayet [ReportResult.duplicate] döner (hata değil).
  Future<ReportResult> reportContent({
    required ReportTargetType targetType,
    required String targetId,
    String? reportedUserId,
    required ReportReason reason,
    String? details,
  });

  /// Kullanıcıyı engeller. Zaten engelliyse [BlockResult.alreadyBlocked].
  Future<BlockResult> blockUser(String userId);

  /// Engeli kaldırır (yoksa sessiz no-op).
  Future<void> unblockUser(String userId);

  /// Mevcut kullanıcının engellediği user id seti (feed/yorum/grup filtresi).
  Future<Set<String>> listBlockedUserIds();

  /// Block/unblock sonrası tick — provider'lar filtreyi tazeler.
  Stream<void> watch();
}
