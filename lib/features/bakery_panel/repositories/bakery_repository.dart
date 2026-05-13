import '../models/daily_summary.dart';
import '../models/dealer_delivery_entry.dart';
import '../models/production_entry.dart';
import '../models/waste_entry.dart';

/// Fırın paneli verilerine soyut erişim.
///
/// V1: [LocalBakeryRepository] (in-memory) ile çalışır.
/// V2: SupabaseBakeryRepository — yalnızca aynı yüzeyi uyarlayacak,
///       UI ve servis katmanı değişmeyecek.
abstract class BakeryRepository {
  // Production
  Future<List<ProductionEntry>> listProduction({DateTime? day});
  Future<void> addProduction(ProductionEntry entry);

  // Dealer
  Future<List<DealerDeliveryEntry>> listDeliveries({DateTime? day});
  Future<void> addDelivery(DealerDeliveryEntry entry);

  // Waste
  Future<List<WasteEntry>> listWastes({DateTime? day});
  Future<void> addWaste(WasteEntry entry);

  // Aggregated
  Future<DailySummary> dailySummary(DateTime day);

  /// Repository içeriği değiştiğinde yayın.
  /// Provider seviyesinde stream'lemek için.
  Stream<void> watch();
}
