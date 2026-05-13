/// Reçete kütüphanesi için zengin meta alanları.
/// Supabase tarafında `recipe_calculations.metadata` (jsonb) sütununda saklanır.
/// Local mock repository'de de aynı şekilde tutulur.
///
/// Schema serbest — sürüm uyumluluğu için bilinmeyen anahtarlar yutulur ve
/// known anahtarlar opsiyonel olarak okunur.
library;

class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    this.note,
  });

  final String name;
  final double amount;
  final String unit;
  final String? note;

  RecipeIngredient copyWith({
    String? name,
    double? amount,
    String? unit,
    String? note,
  }) {
    return RecipeIngredient(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'amount': amount,
        'unit': unit,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: (json['name'] as String?)?.trim() ?? '',
      amount: ((json['amount'] as num?) ?? 0).toDouble(),
      unit: (json['unit'] as String?)?.trim() ?? '',
      note: (json['note'] as String?)?.trim(),
    );
  }
}

class RecipeStep {
  const RecipeStep({
    required this.order,
    required this.text,
    this.durationMin,
  });

  final int order;
  final String text;
  final int? durationMin;

  RecipeStep copyWith({int? order, String? text, int? durationMin}) {
    return RecipeStep(
      order: order ?? this.order,
      text: text ?? this.text,
      durationMin: durationMin ?? this.durationMin,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'order': order,
        'text': text,
        if (durationMin != null) 'durationMin': durationMin,
      };

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      order: ((json['order'] as num?) ?? 0).toInt(),
      text: (json['text'] as String?)?.trim() ?? '',
      durationMin: (json['durationMin'] as num?)?.toInt(),
    );
  }
}

class RecipeBakeInfo {
  const RecipeBakeInfo({
    this.tempC,
    this.durationMin,
    this.proofMin,
  });

  /// Pişirme derecesi (°C).
  final double? tempC;

  /// Pişirme süresi (dakika).
  final int? durationMin;

  /// Mayalanma / dinlendirme süresi (dakika).
  final int? proofMin;

  bool get isEmpty => tempC == null && durationMin == null && proofMin == null;

  RecipeBakeInfo copyWith({
    double? tempC,
    int? durationMin,
    int? proofMin,
  }) {
    return RecipeBakeInfo(
      tempC: tempC ?? this.tempC,
      durationMin: durationMin ?? this.durationMin,
      proofMin: proofMin ?? this.proofMin,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (tempC != null) 'tempC': tempC,
        if (durationMin != null) 'durationMin': durationMin,
        if (proofMin != null) 'proofMin': proofMin,
      };

  factory RecipeBakeInfo.fromJson(Map<String, dynamic> json) {
    return RecipeBakeInfo(
      tempC: (json['tempC'] as num?)?.toDouble(),
      durationMin: (json['durationMin'] as num?)?.toInt(),
      proofMin: (json['proofMin'] as num?)?.toInt(),
    );
  }
}

class RecipeMetadata {
  const RecipeMetadata({
    this.title,
    this.description,
    this.ingredients = const <RecipeIngredient>[],
    this.steps = const <RecipeStep>[],
    this.bake = const RecipeBakeInfo(),
    this.notes,
    this.mediaHints = const <String>[],
    this.updatedAt,
  });

  /// "Trabzon Ekmeği" gibi serbest reçete başlığı.
  /// Boşsa product_name kullanılır.
  final String? title;

  final String? description;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final RecipeBakeInfo bake;
  final String? notes;

  /// Foto/video referansları — V1'de placeholder, gerçek Supabase Storage
  /// yüklemesi sonraki fazda.
  final List<String> mediaHints;

  final DateTime? updatedAt;

  static const RecipeMetadata empty = RecipeMetadata();

  RecipeMetadata copyWith({
    String? title,
    String? description,
    List<RecipeIngredient>? ingredients,
    List<RecipeStep>? steps,
    RecipeBakeInfo? bake,
    String? notes,
    List<String>? mediaHints,
    DateTime? updatedAt,
  }) {
    return RecipeMetadata(
      title: title ?? this.title,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      bake: bake ?? this.bake,
      notes: notes ?? this.notes,
      mediaHints: mediaHints ?? this.mediaHints,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (title != null && title!.isNotEmpty) 'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (ingredients.isNotEmpty)
          'ingredients': ingredients.map((e) => e.toJson()).toList(),
        if (steps.isNotEmpty) 'steps': steps.map((e) => e.toJson()).toList(),
        if (!bake.isEmpty) 'bake': bake.toJson(),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (mediaHints.isNotEmpty) 'mediaHints': mediaHints,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory RecipeMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return RecipeMetadata.empty;
    return RecipeMetadata(
      title: (json['title'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
      ingredients: (json['ingredients'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(RecipeIngredient.fromJson)
              .toList(growable: false) ??
          const <RecipeIngredient>[],
      steps: (json['steps'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(RecipeStep.fromJson)
              .toList(growable: false) ??
          const <RecipeStep>[],
      bake: RecipeBakeInfo.fromJson(
          (json['bake'] as Map?)?.cast<String, dynamic>() ?? const {}),
      notes: (json['notes'] as String?)?.trim(),
      mediaHints: (json['mediaHints'] as List?)
              ?.cast<String>()
              .toList(growable: false) ??
          const <String>[],
      updatedAt: (json['updatedAt'] as String?) != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}
