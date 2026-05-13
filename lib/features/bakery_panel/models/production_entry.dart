class ProductionEntry {
  const ProductionEntry({
    required this.id,
    required this.product,
    required this.quantity,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String product;
  final int quantity;
  final String note;
  final DateTime createdAt;
}
