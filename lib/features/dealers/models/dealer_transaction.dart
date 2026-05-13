/// Bayi cari hesabını oynayan tek bir hareket.
enum DealerTransactionType {
  delivery,    // teslimat — bakiyeyi artırır
  returned,    // iade — bakiyeyi azaltır (Dart'ta 'return' rezerve)
  payment,     // ödeme — bakiyeyi azaltır
  adjustment,  // bakiye düzeltmesi (+/-)
}

extension DealerTransactionTypeLabel on DealerTransactionType {
  String get label {
    switch (this) {
      case DealerTransactionType.delivery:
        return 'Teslimat';
      case DealerTransactionType.returned:
        return 'İade';
      case DealerTransactionType.payment:
        return 'Ödeme';
      case DealerTransactionType.adjustment:
        return 'Düzeltme';
    }
  }

  String get persistKey {
    switch (this) {
      case DealerTransactionType.delivery:
        return 'delivery';
      case DealerTransactionType.returned:
        return 'return';
      case DealerTransactionType.payment:
        return 'payment';
      case DealerTransactionType.adjustment:
        return 'adjustment';
    }
  }

  static DealerTransactionType fromPersistKey(String key) {
    switch (key) {
      case 'delivery':
        return DealerTransactionType.delivery;
      case 'return':
        return DealerTransactionType.returned;
      case 'payment':
        return DealerTransactionType.payment;
      default:
        return DealerTransactionType.adjustment;
    }
  }
}

enum DealerPaymentMethod { cash, transfer, card, other }

extension DealerPaymentMethodLabel on DealerPaymentMethod {
  String get label {
    switch (this) {
      case DealerPaymentMethod.cash:
        return 'Nakit';
      case DealerPaymentMethod.transfer:
        return 'Havale / EFT';
      case DealerPaymentMethod.card:
        return 'Kart';
      case DealerPaymentMethod.other:
        return 'Diğer';
    }
  }

  String get persistKey {
    switch (this) {
      case DealerPaymentMethod.cash:
        return 'cash';
      case DealerPaymentMethod.transfer:
        return 'transfer';
      case DealerPaymentMethod.card:
        return 'card';
      case DealerPaymentMethod.other:
        return 'other';
    }
  }

  static DealerPaymentMethod fromPersistKey(String key) {
    switch (key) {
      case 'cash':
        return DealerPaymentMethod.cash;
      case 'transfer':
        return DealerPaymentMethod.transfer;
      case 'card':
        return DealerPaymentMethod.card;
      default:
        return DealerPaymentMethod.other;
    }
  }
}

/// Bir bayi hareketi.
///
/// Supabase şeması:
/// dealer_transactions(id, dealer_id, type, product_name, quantity,
///                     unit_price, amount, payment_method, note, created_at)
///
/// Notlar:
/// - `amount` her zaman ekonomik etkiyi temsil eder (+ veya 0). İşaret yorumu
///   `type` üzerinden yapılır (delivery → +, return → −, payment → −,
///   adjustment → her iki yön).
/// - `productName / quantity / unitPrice` sadece delivery ve return için
///   anlamlıdır; ödeme/düzeltmede null kalır.
class DealerTransaction {
  const DealerTransaction({
    required this.id,
    required this.dealerId,
    required this.type,
    this.productName,
    this.quantity,
    this.unitPrice,
    required this.amount,
    this.paymentMethod,
    this.note = '',
    required this.createdAt,
  });

  final String id;
  final String dealerId;
  final DealerTransactionType type;
  final String? productName;
  final int? quantity;
  final double? unitPrice;
  final double amount;
  final DealerPaymentMethod? paymentMethod;
  final String note;
  final DateTime createdAt;
}
