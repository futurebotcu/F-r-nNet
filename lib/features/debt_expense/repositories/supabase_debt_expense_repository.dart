import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/debt_expense_entry.dart';
import 'debt_expense_repository.dart';

/// Borç & Gider Defteri — Supabase impl. owner-only RLS; bypass yok.
class SupabaseDebtExpenseRepository implements DebtExpenseRepository {
  SupabaseDebtExpenseRepository(this._client);

  final sb.SupabaseClient _client;
  static const String _table = 'debt_expense_entries';

  final StreamController<void> _changes = StreamController<void>.broadcast();
  void _notify() => _changes.add(null);

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }
    return id;
  }

  @override
  Future<List<DebtExpenseEntry>> listEntries({DebtExpenseKind? kind}) async {
    final ownerId = _requireUserId();
    var q = _client.from(_table).select().eq('owner_id', ownerId);
    if (kind != null) q = q.eq('kind', kind.code);
    final rows = await q.order('created_at', ascending: false).limit(500);
    return (rows as List)
        .map((r) => DebtExpenseEntry.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DebtExpenseEntry> addEntry(DebtExpenseEntry entry) async {
    final ownerId = _requireUserId();
    final payload = entry.toInsert()..['owner_id'] = ownerId;
    final row = await _client.from(_table).insert(payload).select().single();
    _notify();
    return DebtExpenseEntry.fromRow(row);
  }

  @override
  Future<void> addPayment(String entryId, double amount) async {
    final ownerId = _requireUserId();
    // Mevcut paid_amount oku → topla → yaz (single-user; double-submit guard
    // mükerrer çağrıyı zaten engeller).
    final cur = await _client
        .from(_table)
        .select('paid_amount')
        .eq('id', entryId)
        .eq('owner_id', ownerId)
        .single();
    final paid = ((cur['paid_amount'] as num?) ?? 0).toDouble() + amount;
    await _client
        .from(_table)
        .update(<String, dynamic>{
          'paid_amount': paid,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', entryId)
        .eq('owner_id', ownerId);
    _notify();
  }

  @override
  Future<void> updateEntry(DebtExpenseEntry entry) async {
    final ownerId = _requireUserId();
    final payload = entry.toInsert()
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client
        .from(_table)
        .update(payload)
        .eq('id', entry.id)
        .eq('owner_id', ownerId);
    _notify();
  }

  @override
  Future<void> deleteEntry(String id) async {
    final ownerId = _requireUserId();
    await _client.from(_table).delete().eq('id', id).eq('owner_id', ownerId);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;

  @override
  void dispose() => _changes.close();
}
