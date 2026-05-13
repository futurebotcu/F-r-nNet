class WasteEntry {
  const WasteEntry({
    required this.id,
    required this.product,
    required this.quantity,
    required this.unitValue,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String product;
  final int quantity;

  /// Birim maliyet veya satış fiyatı (TL).
  final double unitValue;
  final String note;
  final DateTime createdAt;

  double get estimatedLoss => quantity * unitValue;
}
