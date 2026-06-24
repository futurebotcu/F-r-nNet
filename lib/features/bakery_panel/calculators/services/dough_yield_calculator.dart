import '../../models/recipe.dart' show RecipeResult;
import '../../models/recipe_metadata.dart' show RecipeIngredient;
import '../../models/recipe_quantities.dart';
import '../../services/recipe_calculator.dart';

/// "Hamurdan Ürün" (hamur verimi) hesabı — saf Dart servis.
///
/// Matematik tek kaynakta kalsın diye mevcut [RecipeCalculator]'a delege
/// eder; bu feature'a alan-adıyla (DoughYield) ayrı bir giriş noktası verir.
/// Formül UI/controller içine yazılmaz — ekran bu servisi çağırır.
///
/// Negatif / sıfır / fire-taşması gibi durumlar motor tarafında clamp'lenir;
/// NaN / Infinity / sıfıra bölme üretmez.
class DoughYieldCalculator {
  const DoughYieldCalculator([this._engine = const RecipeCalculator()]);

  final RecipeCalculator _engine;

  /// Gerçek miktarlardan toplam hamur, fire sonrası net hamur ve tahmini
  /// adet hesaplar. Tüm girişler kg (birim gramaj hariç, o gr).
  RecipeResult calculate(
    RecipeQuantities quantities, {
    List<RecipeIngredient> extras = const <RecipeIngredient>[],
  }) {
    return _engine.calculateFromQuantities(quantities, extras: extras);
  }
}
