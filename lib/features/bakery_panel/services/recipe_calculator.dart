import '../models/recipe.dart';
import '../models/recipe_metadata.dart';
import '../models/recipe_quantities.dart';

/// Saf hesap mantığı — UI'dan ve repository'den bağımsız.
/// Bu sayede kolay test edilebilir.
///
/// İki API:
/// - [calculate] — yüzde bazlı V1 (mevcut testler bunu kullanır, geriye uyum).
/// - [calculateFromQuantities] — gerçek miktar bazlı V2 (UI bunu kullanır).
class RecipeCalculator {
  const RecipeCalculator();

  /// V1 — yüzde bazlı hesap. Eski test yüzeyi için korunuyor.
  RecipeResult calculate(RecipeInput input) {
    final flourKg = input.flourKg.clamp(0, double.infinity).toDouble();
    final waterPct = input.waterPct.clamp(0, 200).toDouble();
    final yeastPct = input.yeastPct.clamp(0, 100).toDouble();
    final saltPct = input.saltPct.clamp(0, 100).toDouble();
    final wastePct = input.wastePct.clamp(0, 100).toDouble();
    final pieceWeightG =
        input.pieceWeightG.clamp(1, double.infinity).toDouble();

    // 1 kg su ≈ 1 litre kabulü.
    final waterLiters = flourKg * waterPct / 100.0;
    final yeastKg = flourKg * yeastPct / 100.0;
    final saltKg = flourKg * saltPct / 100.0;

    final totalDoughKg = flourKg + waterLiters + yeastKg + saltKg;
    final doughAfterWasteKg = totalDoughKg * (1.0 - wastePct / 100.0);

    final totalDoughGrams = doughAfterWasteKg * 1000.0;
    final estimatedPieces = (totalDoughGrams / pieceWeightG).floor();

    return RecipeResult(
      waterLiters: waterLiters,
      yeastKg: yeastKg,
      saltKg: saltKg,
      totalDoughKg: totalDoughKg,
      doughAfterWasteKg: doughAfterWasteKg,
      estimatedPieces: estimatedPieces < 0 ? 0 : estimatedPieces,
    );
  }

  /// V2 — gerçek miktar bazlı hesap.
  ///
  /// Formül (briefte tanımlı):
  ///   total = flour + water + yeast + salt + extras_kg
  ///   net   = total - waste
  ///   count = floor(net * 1000 / piece_weight_gr)
  ///
  /// [extras] içinden kg'a çevrilebilen ingredient'lar toplanır
  /// ([unitToKg] kullanır). Birimi bilinmeyenler atlanır.
  RecipeResult calculateFromQuantities(
    RecipeQuantities q, {
    List<RecipeIngredient> extras = const <RecipeIngredient>[],
  }) {
    final flourKg = q.flourKg.clamp(0, double.infinity).toDouble();
    final waterKg = q.waterKg.clamp(0, double.infinity).toDouble();
    final yeastKg = q.yeastKg.clamp(0, double.infinity).toDouble();
    final saltKg = q.saltKg.clamp(0, double.infinity).toDouble();
    final wasteKg = q.wasteKg.clamp(0, double.infinity).toDouble();
    final pieceWeightG = q.pieceWeightG.clamp(1, double.infinity).toDouble();

    final extrasKg = sumExtrasKg(extras);

    final totalDoughKg = flourKg + waterKg + yeastKg + saltKg + extrasKg;
    final clampedWaste = wasteKg > totalDoughKg ? totalDoughKg : wasteKg;
    final netDoughKg = totalDoughKg - clampedWaste;
    final netDoughKgSafe = netDoughKg < 0 ? 0.0 : netDoughKg;

    final estimatedPieces = (netDoughKgSafe * 1000.0 / pieceWeightG).floor();

    return RecipeResult(
      waterLiters: waterKg,
      yeastKg: yeastKg,
      saltKg: saltKg,
      totalDoughKg: totalDoughKg,
      doughAfterWasteKg: netDoughKgSafe,
      estimatedPieces: estimatedPieces < 0 ? 0 : estimatedPieces,
    );
  }

  /// Extras listesindeki kg'a çevrilebilen ingredient'ları toplar.
  /// Birimi "adet" gibi anlamsız olanlar dışarıda kalır.
  static double sumExtrasKg(List<RecipeIngredient> extras) {
    var total = 0.0;
    for (final e in extras) {
      final kg = unitToKg(e.amount, e.unit);
      if (kg != null) total += kg;
    }
    return total;
  }
}
