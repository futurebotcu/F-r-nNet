class DealerDeliveryEntry {
  const DealerDeliveryEntry({
    required this.id,
    required this.dealerName,
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.deliveryDate,
  });

  final String id;
  final String dealerName;
  final String product;
  final int quantity;
  final double unitPrice;
  final DateTime deliveryDate;

  double get total => quantity * unitPrice;
}
