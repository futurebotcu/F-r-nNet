import 'dealer_delivery_entry.dart';
import 'production_entry.dart';
import 'waste_entry.dart';

class DailySummary {
  const DailySummary({
    required this.day,
    required this.production,
    required this.deliveries,
    required this.wastes,
  });

  final DateTime day;
  final List<ProductionEntry> production;
  final List<DealerDeliveryEntry> deliveries;
  final List<WasteEntry> wastes;

  bool get isEmpty =>
      production.isEmpty && deliveries.isEmpty && wastes.isEmpty;

  int get totalProduction =>
      production.fold(0, (sum, e) => sum + e.quantity);

  int get totalDelivered =>
      deliveries.fold(0, (sum, e) => sum + e.quantity);

  double get totalDealerAmount =>
      deliveries.fold(0.0, (sum, e) => sum + e.total);

  int get totalWaste => wastes.fold(0, (sum, e) => sum + e.quantity);

  double get totalEstimatedLoss =>
      wastes.fold(0.0, (sum, e) => sum + e.estimatedLoss);

  /// Net özet: bayi tutarı – tahmini fire zararı.
  double get netAmount => totalDealerAmount - totalEstimatedLoss;
}
