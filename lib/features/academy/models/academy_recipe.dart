/// FırınNet Akademi yayımlı tarif modeli (`academy_recipes`, RLS:
/// status='published' herkese görünür). Malzemeler fırıncı yüzdesiyle
/// birlikte gösterilir: "Un 1000 g (%100)".
class AcademyRecipeIngredient {
  const AcademyRecipeIngredient({
    required this.name,
    required this.grams,
    this.pct,
  });

  final String name;
  final num grams;
  final num? pct;

  factory AcademyRecipeIngredient.fromMap(Map<String, dynamic> m) {
    return AcademyRecipeIngredient(
      name: (m['name'] as String?) ?? '',
      grams: (m['grams'] as num?) ?? 0,
      pct: m['pct'] as num?,
    );
  }

  /// "Un 1000 g (%100)" — yüzde yoksa yalnız gramaj.
  String get display {
    final p = pct;
    final g = grams % 1 == 0 ? grams.toInt().toString() : grams.toString();
    if (p == null) return '$name $g g';
    final ps = p % 1 == 0 ? p.toInt().toString() : p.toString();
    return '$name $g g (%$ps)';
  }
}

class AcademyRecipe {
  const AcademyRecipe({
    required this.id,
    required this.title,
    required this.authorName,
    required this.sourceKind,
    required this.ingredients,
    this.sourceUrl,
    this.ovenC,
    this.minutes,
    this.steps = '',
    this.notes = '',
  });

  final String id;
  final String title;
  final String authorName;
  final String sourceKind; // master | bot | adapted
  final String? sourceUrl;
  final List<AcademyRecipeIngredient> ingredients;
  final int? ovenC;
  final int? minutes;
  final String steps;
  final String notes;

  factory AcademyRecipe.fromRow(Map<String, dynamic> row) {
    final rawIngs = row['ingredients'];
    return AcademyRecipe(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      authorName: (row['author_name'] as String?) ?? '',
      sourceKind: (row['source_kind'] as String?) ?? 'master',
      sourceUrl: row['source_url'] as String?,
      ingredients: [
        if (rawIngs is List)
          for (final i in rawIngs)
            if (i is Map)
              AcademyRecipeIngredient.fromMap(i.cast<String, dynamic>()),
      ],
      ovenC: (row['oven_c'] as num?)?.toInt(),
      minutes: (row['minutes'] as num?)?.toInt(),
      steps: (row['steps'] as String?) ?? '',
      notes: (row['notes'] as String?) ?? '',
    );
  }
}
