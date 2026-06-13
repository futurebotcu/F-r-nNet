import 'dart:async';

import '../models/debt_expense_entry.dart';
import 'debt_expense_repository.dart';

/// Borç & Gider — in-memory impl (guest/offline/test). Kalıcı değil.
class LocalDebtExpenseRepository implements DebtExpenseRepository {
  LocalDebtExpenseRepository();

  final List<DebtExpenseEntry> _entries = <DebtExpenseEntry>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _seq = 0;
  void _notify() => _changes.add(null);

  @override
  Future<List<DebtExpenseEntry>> listEntries({DebtExpenseKind? kind}) async {
    final list = kind == null
        ? _entries
        : _entries.where((e) => e.kind == kind).toList();
    final sorted = [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<DebtExpenseEntry> addEntry(DebtExpenseEntry entry) async {
    final created = entry.id.isEmpty
        ? DebtExpenseEntry(
            id: 'de_${_seq++}',
            kind: entry.kind,
            title: entry.title,
            category: entry.category,
            totalAmount: entry.totalAmount,
            paidAmount: entry.paidAmount,
            dueDate: entry.dueDate,
            staffPaymentType: entry.staffPaymentType,
            note: entry.note,
            createdAt: entry.createdAt,
          )
        : entry;
    _entries.add(created);
    _notify();
    return created;
  }

  @override
  Future<void> addPayment(String entryId, double amount) async {
    final i = _entries.indexWhere((e) => e.id == entryId);
    if (i < 0) return;
    _entries[i] = _entries[i].copyWith(
      paidAmount: _entries[i].paidAmount + amount,
      updatedAt: DateTime.now(),
    );
    _notify();
  }

  @override
  Future<void> updateEntry(DebtExpenseEntry entry) async {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i < 0) return;
    _entries[i] = entry;
    _notify();
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    _notify();
  }

  @override
  Stream<void> watch() => _changes.stream;

  @override
  void dispose() => _changes.close();
}
