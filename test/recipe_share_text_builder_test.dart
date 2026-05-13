import 'package:firin_defter/features/bakery_panel/models/recipe_metadata.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_quantities.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_record.dart';
import 'package:firin_defter/features/bakery_panel/services/recipe_calculator.dart';
import 'package:firin_defter/features/bakery_panel/services/recipe_share_text_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = RecipeCalculator();
  const builder = RecipeShareTextBuilder();

  // Brief örneği: 50 kg un / 30 L su / 500 gr maya / 1 kg tuz / 250 gr gramaj /
  // 2.445 kg fire — gerçek miktar mantığı. (Eski yüzdelik karşılığı 60/1/2/3%.)
  const sampleQuantities = RecipeQuantities(
    flourKg: 50,
    waterKg: 30,
    yeastKg: 0.5,
    saltKg: 1,
    pieceWeightG: 250,
    wasteKg: 2.445,
  );

  Recipe buildSampleRecipe({
    String productName = 'Ekmek',
    RecipeMetadata? metadata,
    RecipeQuantities? quantities,
  }) {
    final q = quantities ?? sampleQuantities;
    final r = calc.calculateFromQuantities(q,
        extras: (metadata ?? RecipeMetadata.empty).ingredients);
    return Recipe(
      id: 'r_1',
      productName: productName,
      quantities: q,
      result: r,
      metadata: metadata ?? RecipeMetadata.empty,
      createdAt: DateTime(2026, 5, 13, 9, 0),
    );
  }

  group('RecipeShareTextBuilder', () {
    test('briefteki örneği WhatsApp formatına çevirir (50/60/1/2/250/3)', () {
      final recipe = buildSampleRecipe();
      final text = builder.build(recipe);

      // İlk satır başlık
      expect(text, startsWith('Ekmek Reçetesi\n'));
      // Hesap satırları
      expect(text, contains('Un: 50 kg'));
      expect(text, contains('Su: 30 kg'));
      expect(text, contains('Maya: 0.5 kg'));
      expect(text, contains('Tuz: 1 kg'));
      expect(text, contains('Gramaj: 250 gr'));
      expect(text, contains('Tahmini: 316 adet'));
      // Son satır marka
      expect(text, endsWith('\nFırınNet'));
    });

    test('metadata.title varsa onu başlık olarak kullanır', () {
      final recipe = buildSampleRecipe(
        productName: 'Ekmek',
        metadata: const RecipeMetadata(title: 'Trabzon Ekmeği'),
      );
      final text = builder.build(recipe);
      expect(text, startsWith('Trabzon Ekmeği Reçetesi\n'));
    });

    test('product_name boşsa "Genel reçete" başlığını kullanır', () {
      final recipe = buildSampleRecipe(productName: '');
      final text = builder.build(recipe);
      expect(text, startsWith('Genel reçete Reçetesi\n'));
    });

    test('malzemeler ve adımlar varsa listeler', () {
      final recipe = buildSampleRecipe(
        metadata: const RecipeMetadata(
          ingredients: <RecipeIngredient>[
            RecipeIngredient(name: 'Susam', amount: 1, unit: 'kg'),
            RecipeIngredient(
                name: 'Şeker', amount: 0.5, unit: 'kg', note: 'kahverengi'),
          ],
          steps: <RecipeStep>[
            RecipeStep(order: 1, text: 'Hamuru yoğur'),
            RecipeStep(order: 2, text: 'Dinlendir', durationMin: 45),
          ],
        ),
      );
      final text = builder.build(recipe);
      expect(text, contains('Malzemeler:'));
      expect(text, contains('- Susam: 1 kg'));
      expect(text, contains('- Şeker: 0.5 kg (kahverengi)'));
      expect(text, contains('Yapılışı:'));
      expect(text, contains('1. Hamuru yoğur'));
      expect(text, contains('2. Dinlendir (45 dk)'));
    });

    test('pişirme bilgileri ve not satırlarını ekler', () {
      final recipe = buildSampleRecipe(
        metadata: const RecipeMetadata(
          bake: RecipeBakeInfo(tempC: 220, durationMin: 18, proofMin: 45),
          notes: 'Soğuk fermantasyon önerilir',
        ),
      );
      final text = builder.build(recipe);
      expect(text, contains('Pişirme: 220°C • 18 dk pişirme • 45 dk mayalanma'));
      expect(text, contains('Not: Soğuk fermantasyon önerilir'));
    });

    test('adımlar order sıralamasına göre yazılır', () {
      final recipe = buildSampleRecipe(
        metadata: const RecipeMetadata(
          steps: <RecipeStep>[
            RecipeStep(order: 3, text: 'Pişir'),
            RecipeStep(order: 1, text: 'Yoğur'),
            RecipeStep(order: 2, text: 'Bezelere ayır'),
          ],
        ),
      );
      final text = builder.build(recipe);
      final yogurIdx = text.indexOf('1. Yoğur');
      final ayirIdx = text.indexOf('2. Bezelere ayır');
      final pisirIdx = text.indexOf('3. Pişir');
      expect(yogurIdx, lessThan(ayirIdx));
      expect(ayirIdx, lessThan(pisirIdx));
    });
  });
}
