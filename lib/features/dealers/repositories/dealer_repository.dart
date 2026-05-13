import '../models/dealer.dart';
import '../models/dealer_note.dart';
import '../models/dealer_price.dart';
import '../models/dealer_transaction.dart';

/// Bayi yönetimi için soyut erişim.
///
/// V1.2:
/// - LocalDealerRepository: in-memory, demo seed; customer_type filtresini
///   destekler (ticari ve toptancı UI'sı aynı arayüzü kullanır).
/// - SupabaseDealerRepository: Migration A sonrası tüm transaction/price/note
///   kalıcı tabloya yazılır. dealer_deliveries + dealer_delivery_items hâlâ
///   teslimat satırı için kullanılır (`type=delivery` okumaları oradan gelir).
abstract class DealerRepository {
  // Dealers
  Future<List<Dealer>> listDealers({
    bool? activeOnly,
    DealerCustomerType? customerType,
  });
  Future<Dealer?> getDealer(String id);
  Future<void> upsertDealer(Dealer dealer);
  Future<void> setActive(String dealerId, {required bool active});

  // Prices
  Future<List<DealerPrice>> listPrices(String dealerId);

  /// Belirli bayi+ürün için "şu an geçerli" fiyat (en son `validFrom`).
  /// Yoksa null.
  Future<DealerPrice?> currentPriceFor({
    required String dealerId,
    required String productName,
  });

  Future<void> addPrice(DealerPrice price);

  // Transactions
  Future<List<DealerTransaction>> listTransactions(String dealerId);
  Future<List<DealerTransaction>> listAllTransactions();
  Future<void> addTransaction(DealerTransaction tx);

  // Notes
  Future<List<DealerNote>> listNotes(String dealerId);
  Future<void> addNote(DealerNote note);

  /// Repository içeriği değiştiğinde yayın.
  Stream<void> watch();
}
