import 'package:firin_defter/features/bakery_panel/models/recipe.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_metadata.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_quantities.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_record.dart';
import 'package:firin_defter/features/bakery_panel/repositories/local_recipe_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalRecipeRepository', () {
    late LocalRecipeRepository repo;

    setUp(() {
      repo = LocalRecipeRepository();
    });

    // Brief örneği gerçek miktar: 50/30L/500gr/1kg/250gr/2.445kg → 316 adet.
    const sampleQuantities = RecipeQuantities(
      flourKg: 50,
      waterKg: 30,
      yeastKg: 0.5,
      saltKg: 1,
      pieceWeightG: 250,
      wasteKg: 2.445,
    );

    Recipe buildDraft({
      String id = '',
      String name = 'Ekmek',
      RecipeVisibility visibility = RecipeVisibility.private,
    }) {
      return Recipe(
        id: id,
        productName: name,
        quantities: sampleQuantities,
        result: const RecipeResult(
          waterLiters: 0,
          yeastKg: 0,
          saltKg: 0,
          totalDoughKg: 0,
          doughAfterWasteKg: 0,
          estimatedPieces: 0,
        ),
        createdAt: DateTime(2026, 5, 13),
        visibility: visibility,
      );
    }

    test('boş başlangıçta list() boş döner', () async {
      final items = await repo.list();
      expect(items, isEmpty);
    });

    test('save() yeni reçete ekler ve hesap sonuçlarını trigger gibi doldurur',
        () async {
      final saved = await repo.save(buildDraft());
      expect(saved.id, isNotEmpty);
      expect(saved.result.estimatedPieces, 316);
      expect(saved.result.waterLiters, 30);
      expect(saved.result.yeastKg, 0.5);
      expect(saved.result.saltKg, 1);
    });

    test('save() metadata.updatedAt değerini otomatik set eder', () async {
      final saved = await repo.save(buildDraft());
      expect(saved.metadata.updatedAt, isNotNull);
    });

    test('list() created_at desc sırasında döner', () async {
      final first = await repo.save(buildDraft(name: 'Ekmek'));
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await repo.save(buildDraft(name: 'Simit'));

      final items = await repo.list();
      expect(items.first.id, second.id);
      expect(items.last.id, first.id);
    });

    test('getById() doğru kaydı döner, bulunamazsa null', () async {
      final saved = await repo.save(buildDraft());
      final fetched = await repo.getById(saved.id);
      expect(fetched, isNotNull);
      expect(fetched!.id, saved.id);
      expect(await repo.getById('missing'), isNull);
    });

    test('save() aynı id ile güncellenir, ID korunur', () async {
      final saved = await repo.save(buildDraft());
      final updated = saved.copyWith(
        productName: 'Trabzon Ekmeği',
        metadata: const RecipeMetadata(title: 'Trabzon Ekmeği'),
      );
      final result = await repo.save(updated);
      expect(result.id, saved.id);
      expect(result.productName, 'Trabzon Ekmeği');

      final items = await repo.list();
      expect(items, hasLength(1));
    });

    test('delete() kaydı kaldırır', () async {
      final saved = await repo.save(buildDraft());
      await repo.delete(saved.id);
      expect(await repo.list(), isEmpty);
    });

    test('watch() save sonrası event yayar', () async {
      final events = <void>[];
      final sub = repo.watch().listen(events.add);
      await repo.save(buildDraft());
      await Future<void>.delayed(Duration.zero);
      expect(events, isNotEmpty);
      await sub.cancel();
    });
  });

  group('RecipeMetadata JSON round-trip', () {
    test('toJson/fromJson tam alanlar', () {
      const meta = RecipeMetadata(
        title: 'Trabzon Ekmeği',
        description: 'Çıtır kabuklu',
        ingredients: <RecipeIngredient>[
          RecipeIngredient(name: 'Un', amount: 50, unit: 'kg'),
          RecipeIngredient(
              name: 'Susam', amount: 1, unit: 'kg', note: 'üzerine'),
        ],
        steps: <RecipeStep>[
          RecipeStep(order: 1, text: 'Yoğur'),
          RecipeStep(order: 2, text: 'Dinlendir', durationMin: 45),
        ],
        bake: RecipeBakeInfo(tempC: 220, durationMin: 18, proofMin: 45),
        notes: 'Soğuk ferm.',
        mediaHints: <String>['placeholder://photo'],
      );
      final json = meta.toJson();
      final restored = RecipeMetadata.fromJson(json);

      expect(restored.title, 'Trabzon Ekmeği');
      expect(restored.description, 'Çıtır kabuklu');
      expect(restored.ingredients, hasLength(2));
      expect(restored.ingredients[1].note, 'üzerine');
      expect(restored.steps, hasLength(2));
      expect(restored.steps[1].durationMin, 45);
      expect(restored.bake.tempC, 220);
      expect(restored.bake.durationMin, 18);
      expect(restored.bake.proofMin, 45);
      expect(restored.notes, 'Soğuk ferm.');
      expect(restored.mediaHints, <String>['placeholder://photo']);
    });

    test('null/empty json RecipeMetadata.empty döner', () {
      expect(identical(RecipeMetadata.fromJson(null), RecipeMetadata.empty),
          isTrue);
      expect(identical(RecipeMetadata.fromJson(const <String, dynamic>{}),
          RecipeMetadata.empty),
          isTrue);
    });

    test('bilinmeyen anahtarlar yutulur (forward compat)', () {
      final restored = RecipeMetadata.fromJson(<String, dynamic>{
        'title': 'X',
        'futureField': <String, dynamic>{'a': 1},
      });
      expect(restored.title, 'X');
    });
  });
}
