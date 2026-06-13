import '../../auth/services/auth_required_guard.dart';
import '../models/debt_expense_entry.dart';
import 'debt_expense_repository.dart';

/// Guest write korumalı [DebtExpenseRepository] dekoratörü (dealer pattern).
class GuardedDebtExpenseRepository implements DebtExpenseRepository {
  GuardedDebtExpenseRepository({
    required this.inner,
    required this.canWriteCheck,
  });

  final DebtExpenseRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  @override
  Future<List<DebtExpenseEntry>> listEntries({DebtExpenseKind? kind}) =>
      inner.listEntries(kind: kind);

  @override
  Future<DebtExpenseEntry> addEntry(DebtExpenseEntry entry) {
    _requireWrite('kayıt eklemek');
    return inner.addEntry(entry);
  }

  @override
  Future<void> addPayment(String entryId, double amount) {
    _requireWrite('ödeme eklemek');
    return inner.addPayment(entryId, amount);
  }

  @override
  Future<void> updateEntry(DebtExpenseEntry entry) {
    _requireWrite('kaydı düzenlemek');
    return inner.updateEntry(entry);
  }

  @override
  Future<void> deleteEntry(String id) {
    _requireWrite('kaydı silmek');
    return inner.deleteEntry(id);
  }

  @override
  Stream<void> watch() => inner.watch();

  @override
  void dispose() => inner.dispose();
}
