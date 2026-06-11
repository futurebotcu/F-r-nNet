// FırınNet UGC Safety V1 — Supabase implementasyonu.
//
// content_reports / user_blocks tablolarına yazar (RLS: yalnız kendi adına).
// Duplicate'ler DB unique constraint'ine (23505) güvenilerek ele alınır —
// race-safe; client-side ön kontrol yalnız UX kısayolu.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/report_models.dart';
import 'safety_repository.dart';

class SupabaseSafetyRepository implements SafetyRepository {
  SupabaseSafetyRepository(this._client);

  final sb.SupabaseClient _client;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Sync filtre için cache — [listBlockedUserIds] doldurur,
  /// block/unblock günceller.
  final Set<String> _blockedCache = <String>{};
  bool _blockedLoaded = false;

  void _notify() => _changes.add(null);

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<ReportResult> reportContent({
    required ReportTargetType targetType,
    required String targetId,
    String? reportedUserId,
    required ReportReason reason,
    String? details,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    // Kendi içeriğini şikayet etme guard'ı (UI zaten sunmaz).
    if (reportedUserId != null && reportedUserId == uid) {
      throw const SelfTargetException();
    }
    final trimmed = details?.trim();
    try {
      await _client.from('content_reports').insert(<String, dynamic>{
        'reporter_id': uid,
        if (reportedUserId != null) 'reported_user_id': reportedUserId,
        'target_type': targetType.persistKey,
        'target_id': targetId,
        'reason': reason.persistKey,
        if (trimmed != null && trimmed.isNotEmpty) 'details': trimmed,
      });
    } on sb.PostgrestException catch (e) {
      // unique(reporter, target) → zaten şikayet edilmiş.
      if (e.code == '23505') return ReportResult.duplicate;
      rethrow;
    }
    return ReportResult.submitted;
  }

  @override
  Future<BlockResult> blockUser(String userId) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    if (userId == uid) throw const SelfTargetException();
    try {
      await _client.from('user_blocks').insert(<String, dynamic>{
        'blocker_id': uid,
        'blocked_user_id': userId,
      });
    } on sb.PostgrestException catch (e) {
      if (e.code == '23505') {
        _blockedCache.add(userId);
        return BlockResult.alreadyBlocked;
      }
      rethrow;
    }
    _blockedCache.add(userId);
    _notify();
    return BlockResult.blocked;
  }

  @override
  Future<void> unblockUser(String userId) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_user_id', userId);
    _blockedCache.remove(userId);
    _notify();
  }

  @override
  Future<Set<String>> listBlockedUserIds() async {
    final uid = _uid;
    if (uid == null) return const <String>{};
    final rows = await _client
        .from('user_blocks')
        .select('blocked_user_id')
        .eq('blocker_id', uid);
    // Atomik swap (joined-cache P0 dersi): await sırasında canlı set
    // boşaltılmaz; okuyucular ya eski ya yeni seti görür.
    final next = <String>{
      for (final r in (rows as List))
        (r as Map<String, dynamic>)['blocked_user_id'] as String,
    };
    final changed = next.length != _blockedCache.length ||
        !next.containsAll(_blockedCache);
    _blockedCache
      ..clear()
      ..addAll(next);
    _blockedLoaded = true;
    if (changed) _notify();
    return Set<String>.unmodifiable(next);
  }

  /// Sync convenience — provider zinciri için (loaded değilse boş set).
  Set<String> get blockedCache =>
      _blockedLoaded ? Set<String>.unmodifiable(_blockedCache) : const {};

  @override
  Stream<void> watch() => _changes.stream;
}
