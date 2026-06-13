import '../models/debt_expense_entry.dart';

/// Borç & Gider Defteri V1 erişim arayüzü (dealer pattern'i izler).
///
/// Ödeme = `addPayment` ile `paid_amount` artırımı (V1'de ayrı hareket
/// tablosu yok — finansal doğruluk için en sade yol). remaining/status
/// modelde türetilir.
abstract class DebtExpenseRepository {
  Future<List<DebtExpenseEntry>> listEntries({DebtExpenseKind? kind});
  Future<DebtExpenseEntry> addEntry(DebtExpenseEntry entry);

  /// Mevcut kayda ödeme ekler (paid_amount += amount). Kalan otomatik düşer.
  Future<void> addPayment(String entryId, double amount);

  Future<void> updateEntry(DebtExpenseEntry entry);
  Future<void> deleteEntry(String id);

  /// İçerik (kayıt/ödeme) değişim yayını. (`implements` default body
  /// devralmaz — her impl override eder.)
  Stream<void> watch();

  /// Repo atıldığında controller kapatma kancası (default no-op).
  void dispose() {}
}
