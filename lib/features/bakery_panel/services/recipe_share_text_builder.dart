import '../models/recipe_record.dart';

/// Reçeteyi WhatsApp/sistem paylaşımına uygun çok satırlı metne çevirir.
///
/// Saf fonksiyon — UI'dan, repository'den ve `share_plus`'tan bağımsız.
/// Test edilebilir.
class RecipeShareTextBuilder {
  const RecipeShareTextBuilder();

  String build(Recipe recipe) {
    final lines = <String>[];

    final title = recipe.displayTitle;
    if (title.isNotEmpty) {
      lines.add('$title Reçetesi');
    } else {
      lines.add('Reçete');
    }

    final q = recipe.quantities;
    final result = recipe.result;

    lines.add('Un: ${_kg(q.flourKg)} kg');
    lines.add('Su: ${_kg(q.waterKg)} kg');
    lines.add('Maya: ${_kg(q.yeastKg)} kg');
    lines.add('Tuz: ${_kg(q.saltKg)} kg');
    lines.add('Gramaj: ${_gr(q.pieceWeightG)} gr');
    lines.add('Tahmini: ${result.estimatedPieces} adet');

    final ingredients = recipe.metadata.ingredients;
    if (ingredients.isNotEmpty) {
      lines.add('');
      lines.add('Malzemeler:');
      for (final ing in ingredients) {
        final note = (ing.note?.trim().isNotEmpty ?? false) ? ' (${ing.note})' : '';
        lines.add('- ${ing.name}: ${_kg(ing.amount)} ${ing.unit}$note');
      }
    }

    final steps = recipe.metadata.steps;
    if (steps.isNotEmpty) {
      lines.add('');
      lines.add('Yapılışı:');
      final sorted = [...steps]..sort((a, b) => a.order.compareTo(b.order));
      for (final s in sorted) {
        final dur = s.durationMin != null ? ' (${s.durationMin} dk)' : '';
        lines.add('${s.order}. ${s.text}$dur');
      }
    }

    final bake = recipe.metadata.bake;
    if (!bake.isEmpty) {
      lines.add('');
      final bakeLine = <String>[];
      if (bake.tempC != null) bakeLine.add('${_kg(bake.tempC!)}°C');
      if (bake.durationMin != null) bakeLine.add('${bake.durationMin} dk pişirme');
      if (bake.proofMin != null) bakeLine.add('${bake.proofMin} dk mayalanma');
      lines.add('Pişirme: ${bakeLine.join(' • ')}');
    }

    final notes = recipe.metadata.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      lines.add('');
      lines.add('Not: $notes');
    }

    lines.add('');
    lines.add('FırınNet');
    return lines.join('\n');
  }

  String _kg(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    // En fazla 3 ondalık; sondaki sıfırlar atılır.
    final s = v.toStringAsFixed(3);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  String _gr(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
