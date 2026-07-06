/// Fire/zayiat sebebi (waste_entries.waste_type).
///
/// persistKey'ler DB CHECK constraint'iyle hizalıdır (bakery_ledger_v1
/// migration'ı superset'e genişletti). Eski V1 değerleri ('waste',
/// 'leftover') fromKey'de en yakın yeni sebebe eşlenir; DB'deki veri
/// DEĞİŞMEZ, yalnız görünüm eşlenir.
enum WasteReason {
  burnt,
  overproduction,
  returned,
  spoilage,
  staffError,
  other,
}

extension WasteReasonMeta on WasteReason {
  String get persistKey {
    switch (this) {
      case WasteReason.burnt:
        return 'burnt';
      case WasteReason.overproduction:
        return 'overproduction';
      case WasteReason.returned:
        return 'return';
      case WasteReason.spoilage:
        return 'spoilage';
      case WasteReason.staffError:
        return 'staff_error';
      case WasteReason.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case WasteReason.burnt:
        return 'Yanık';
      case WasteReason.overproduction:
        return 'Fazla üretim';
      case WasteReason.returned:
        return 'İade';
      case WasteReason.spoilage:
        return 'Bozulma';
      case WasteReason.staffError:
        return 'Personel hatası';
      case WasteReason.other:
        return 'Diğer';
    }
  }

  static WasteReason fromKey(String? key) {
    switch (key) {
      case 'burnt':
        return WasteReason.burnt;
      case 'overproduction':
      // Legacy 'leftover' (tezgahta kalan) → en yakın sebep: fazla üretim.
      case 'leftover':
        return WasteReason.overproduction;
      case 'return':
        return WasteReason.returned;
      case 'spoilage':
        return WasteReason.spoilage;
      case 'staff_error':
        return WasteReason.staffError;
      default:
        // Legacy 'waste' + bilinmeyen → Diğer.
        return WasteReason.other;
    }
  }
}

class WasteEntry {
  const WasteEntry({
    required this.id,
    required this.product,
    required this.quantity,
    required this.unitValue,
    required this.note,
    required this.createdAt,
    this.reason = WasteReason.other,
  });

  final String id;
  final String product;
  final int quantity;

  /// Birim maliyet veya satış fiyatı (TL).
  final double unitValue;
  final String note;
  final DateTime createdAt;
  final WasteReason reason;

  double get estimatedLoss => quantity * unitValue;
}
