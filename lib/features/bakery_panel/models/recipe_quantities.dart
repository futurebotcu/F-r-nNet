/// Gerçek miktar tabanlı reçete girdisi.
///
/// Fırıncı yüzdeyle değil gerçek miktarla düşünür. Bu model UI'dan
/// (un kg, su L/kg, maya kg/gr, tuz kg/gr, fire kg, gramaj gr) doğrudan
/// üretilir. Hesap motoru bunları olduğu gibi alır.
///
/// 1 L su = 1 kg kabulü; UI tarafında gerekli birim dönüşümleri yapıldıktan
/// sonra bu modele kg cinsinden geçilir.
class RecipeQuantities {
  const RecipeQuantities({
    required this.flourKg,
    required this.waterKg,
    required this.yeastKg,
    required this.saltKg,
    required this.pieceWeightG,
    this.wasteKg = 0,
  });

  final double flourKg;
  final double waterKg;
  final double yeastKg;
  final double saltKg;
  final double pieceWeightG;

  /// Fire/kayıp. Boş bırakılırsa 0 — hesap toplam hamuru olduğu gibi alır.
  final double wasteKg;

  /// Briefteki örnek: 50/30L/500gr/1kg/250gr/2.445kg → 316 adet.
  static const RecipeQuantities defaults = RecipeQuantities(
    flourKg: 50,
    waterKg: 30,
    yeastKg: 0.5,
    saltKg: 1,
    pieceWeightG: 250,
    wasteKg: 0,
  );

  RecipeQuantities copyWith({
    double? flourKg,
    double? waterKg,
    double? yeastKg,
    double? saltKg,
    double? pieceWeightG,
    double? wasteKg,
  }) {
    return RecipeQuantities(
      flourKg: flourKg ?? this.flourKg,
      waterKg: waterKg ?? this.waterKg,
      yeastKg: yeastKg ?? this.yeastKg,
      saltKg: saltKg ?? this.saltKg,
      pieceWeightG: pieceWeightG ?? this.pieceWeightG,
      wasteKg: wasteKg ?? this.wasteKg,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'flourKg': flourKg,
        'waterKg': waterKg,
        'yeastKg': yeastKg,
        'saltKg': saltKg,
        'pieceWeightG': pieceWeightG,
        'wasteKg': wasteKg,
      };

  factory RecipeQuantities.fromJson(Map<String, dynamic>? json) {
    if (json == null) return RecipeQuantities.defaults;
    return RecipeQuantities(
      flourKg: ((json['flourKg'] as num?) ?? 0).toDouble(),
      waterKg: ((json['waterKg'] as num?) ?? 0).toDouble(),
      yeastKg: ((json['yeastKg'] as num?) ?? 0).toDouble(),
      saltKg: ((json['saltKg'] as num?) ?? 0).toDouble(),
      pieceWeightG: ((json['pieceWeightG'] as num?) ?? 1).toDouble(),
      wasteKg: ((json['wasteKg'] as num?) ?? 0).toDouble(),
    );
  }
}

/// Birim adlarından kg ağırlığına dönüşüm (extras toplamı için).
///
/// "kg" → x, "g"/"gr" → x/1000, "l"/"lt"/"litre" → x (1L ≈ 1kg).
/// "adet"/"yumurta" gibi anlamsız birimler `null` döner — extras toplamına
/// dahil edilmez.
double? unitToKg(double amount, String unit) {
  final u = unit.trim().toLowerCase();
  if (amount <= 0) return null;
  switch (u) {
    case 'kg':
      return amount;
    case 'g':
    case 'gr':
    case 'gram':
      return amount / 1000.0;
    case 'l':
    case 'lt':
    case 'litre':
      return amount; // 1 L ≈ 1 kg
    case 'ml':
      return amount / 1000.0;
    default:
      return null;
  }
}
