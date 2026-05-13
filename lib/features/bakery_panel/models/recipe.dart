/// Reçete hesaplayıcısının girdisi.
class RecipeInput {
  const RecipeInput({
    required this.flourKg,
    required this.waterPct,
    required this.yeastPct,
    required this.saltPct,
    required this.pieceWeightG,
    required this.wastePct,
  });

  final double flourKg;
  final double waterPct;
  final double yeastPct;
  final double saltPct;
  final double pieceWeightG;
  final double wastePct;

  /// Brief'teki örnek varsayılan.
  static const RecipeInput defaults = RecipeInput(
    flourKg: 50,
    waterPct: 60,
    yeastPct: 1,
    saltPct: 2,
    pieceWeightG: 250,
    wastePct: 3,
  );

  RecipeInput copyWith({
    double? flourKg,
    double? waterPct,
    double? yeastPct,
    double? saltPct,
    double? pieceWeightG,
    double? wastePct,
  }) {
    return RecipeInput(
      flourKg: flourKg ?? this.flourKg,
      waterPct: waterPct ?? this.waterPct,
      yeastPct: yeastPct ?? this.yeastPct,
      saltPct: saltPct ?? this.saltPct,
      pieceWeightG: pieceWeightG ?? this.pieceWeightG,
      wastePct: wastePct ?? this.wastePct,
    );
  }
}

/// Hesap çıktısı.
class RecipeResult {
  const RecipeResult({
    required this.waterLiters,
    required this.yeastKg,
    required this.saltKg,
    required this.totalDoughKg,
    required this.doughAfterWasteKg,
    required this.estimatedPieces,
  });

  final double waterLiters;
  final double yeastKg;
  final double saltKg;
  final double totalDoughKg;
  final double doughAfterWasteKg;
  final int estimatedPieces;
}
