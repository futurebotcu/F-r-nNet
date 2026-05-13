import 'package:firin_defter/features/bakery_panel/models/recipe.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_metadata.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_quantities.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_record.dart';
import 'package:firin_defter/features/bakery_panel/repositories/local_recipe_repository.dart';
import 'package:firin_defter/features/bakery_panel/services/recipe_calculator.dart';
import 'package:firin_defter/features/bakery_panel/services/recipe_share_text_builder.dart';
import 'package:firin_defter/features/dashboard/services/role_panel_cards.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipeCalculator V2 (gerçek miktar)', () {
    const calc = RecipeCalculator();

    test('briefteki örnek: 50/30L/500gr/1kg/250gr/2.445kg → 316 adet', () {
      const q = RecipeQuantities(
        flourKg: 50,
        waterKg: 30, // 30 L ≈ 30 kg
        yeastKg: 0.5, // 500 gr
        saltKg: 1,
        pieceWeightG: 250,
        wasteKg: 2.445,
      );
      final r = calc.calculateFromQuantities(q);
      expect(r.waterLiters, 30);
      expect(r.yeastKg, 0.5);
      expect(r.saltKg, 1);
      expect(r.totalDoughKg, 81.5);
      expect(r.doughAfterWasteKg, closeTo(79.055, 1e-9));
      expect(r.estimatedPieces, 316);
    });

    test('fire boş bırakılırsa (wasteKg=0) toplam hamur olduğu gibi alınır',
        () {
      const q = RecipeQuantities(
        flourKg: 50,
        waterKg: 30,
        yeastKg: 0.5,
        saltKg: 1,
        pieceWeightG: 250,
      );
      final r = calc.calculateFromQuantities(q);
      expect(r.doughAfterWasteKg, 81.5);
      expect(r.estimatedPieces, 326);
    });

    test('extras kg dahil toplam hamuru artırır', () {
      const q = RecipeQuantities(
        flourKg: 50,
        waterKg: 30,
        yeastKg: 0.5,
        saltKg: 1,
        pieceWeightG: 250,
        wasteKg: 0,
      );
      // Yağ 2 kg + Susam 1 kg = 3 kg ek.
      const extras = <RecipeIngredient>[
        RecipeIngredient(name: 'Yağ', amount: 2, unit: 'kg'),
        RecipeIngredient(name: 'Susam', amount: 1, unit: 'kg'),
      ];
      final r = calc.calculateFromQuantities(q, extras: extras);
      expect(r.totalDoughKg, 84.5);
      expect(r.estimatedPieces, (84.5 * 1000 / 250).floor());
    });

    test('extras "adet" gibi anlamsız birimlerini görmezden gelir', () {
      const q = RecipeQuantities(
        flourKg: 50,
        waterKg: 30,
        yeastKg: 0.5,
        saltKg: 1,
        pieceWeightG: 250,
      );
      const extras = <RecipeIngredient>[
        RecipeIngredient(name: 'Yumurta', amount: 3, unit: 'adet'),
      ];
      final r = calc.calculateFromQuantities(q, extras: extras);
      expect(r.totalDoughKg, 81.5);
    });

    test('gr birimi 1000\'e bölünür (L = kg kabulü)', () {
      expect(unitToKg(500, 'gr'), closeTo(0.5, 1e-9));
      expect(unitToKg(2, 'L'), 2);
      expect(unitToKg(1, 'kg'), 1);
      expect(unitToKg(250, 'ml'), closeTo(0.25, 1e-9));
      expect(unitToKg(3, 'adet'), isNull);
    });

    test('waste > total ise net 0\'a clamp olur', () {
      const q = RecipeQuantities(
        flourKg: 1,
        waterKg: 0,
        yeastKg: 0,
        saltKg: 0,
        pieceWeightG: 100,
        wasteKg: 5, // toplamdan büyük
      );
      final r = calc.calculateFromQuantities(q);
      expect(r.doughAfterWasteKg, 0);
      expect(r.estimatedPieces, 0);
    });
  });

  group('RecipeQuantities JSON', () {
    test('defaults round-trip', () {
      final json = RecipeQuantities.defaults.toJson();
      final restored = RecipeQuantities.fromJson(json);
      expect(restored.flourKg, 50);
      expect(restored.waterKg, 30);
      expect(restored.yeastKg, 0.5);
      expect(restored.saltKg, 1);
      expect(restored.pieceWeightG, 250);
      expect(restored.wasteKg, 0);
    });

    test('null json → defaults', () {
      final restored = RecipeQuantities.fromJson(null);
      expect(restored.flourKg, 50);
    });
  });

  group('Recipe visibility', () {
    test('default Recipe.visibility = private', () {
      const q = RecipeQuantities.defaults;
      final r = Recipe(
        id: 'x',
        productName: 'Ekmek',
        quantities: q,
        result: const RecipeResult(
          waterLiters: 0,
          yeastKg: 0,
          saltKg: 0,
          totalDoughKg: 0,
          doughAfterWasteKg: 0,
          estimatedPieces: 0,
        ),
        createdAt: DateTime(2026, 5, 13),
      );
      expect(r.visibility, RecipeVisibility.private);
      expect(r.isPublic, isFalse);
    });

    test('private → public geçişi LocalRepo\'da publishedAt set eder',
        () async {
      final repo = LocalRecipeRepository();
      const q = RecipeQuantities.defaults;
      const result = RecipeResult(
        waterLiters: 0,
        yeastKg: 0,
        saltKg: 0,
        totalDoughKg: 0,
        doughAfterWasteKg: 0,
        estimatedPieces: 0,
      );
      final draft = Recipe(
        id: '',
        ownerId: 'u1',
        productName: 'Ekmek',
        quantities: q,
        result: result,
        createdAt: DateTime(2026, 5, 13),
      );
      final created = await repo.save(draft);
      expect(created.isPublic, isFalse);
      expect(created.publishedAt, isNull);

      // public yap
      final togglePublic = created.copyWith(visibility: RecipeVisibility.public);
      final published = await repo.save(togglePublic);
      expect(published.isPublic, isTrue);
      expect(published.publishedAt, isNotNull);

      // public → private
      final retract = published.copyWith(visibility: RecipeVisibility.private);
      final retracted = await repo.save(retract);
      expect(retracted.isPublic, isFalse);
      expect(retracted.publishedAt, isNull);
    });

    test('listPublicByOwner sadece is_public=true sahip kayıtları döner',
        () async {
      final repo = LocalRecipeRepository();
      const q = RecipeQuantities.defaults;
      const r0 = RecipeResult(
        waterLiters: 0,
        yeastKg: 0,
        saltKg: 0,
        totalDoughKg: 0,
        doughAfterWasteKg: 0,
        estimatedPieces: 0,
      );
      await repo.save(Recipe(
        id: '',
        ownerId: 'u1',
        productName: 'A (gizli)',
        quantities: q,
        result: r0,
        createdAt: DateTime(2026, 5, 13),
      ));
      await repo.save(Recipe(
        id: '',
        ownerId: 'u1',
        productName: 'B (açık)',
        quantities: q,
        result: r0,
        createdAt: DateTime(2026, 5, 13),
        visibility: RecipeVisibility.public,
      ));
      await repo.save(Recipe(
        id: '',
        ownerId: 'u2',
        productName: 'C (başkası, açık)',
        quantities: q,
        result: r0,
        createdAt: DateTime(2026, 5, 13),
        visibility: RecipeVisibility.public,
      ));

      final publicForU1 = await repo.listPublicByOwner('u1');
      expect(publicForU1, hasLength(1));
      expect(publicForU1.first.productName, 'B (açık)');

      final publicForU2 = await repo.listPublicByOwner('u2');
      expect(publicForU2, hasLength(1));
      expect(publicForU2.first.productName, 'C (başkası, açık)');

      expect(await repo.listPublicByOwner(null), isEmpty);
      expect(await repo.listPublicByOwner(''), isEmpty);
    });

    test('share text builder is_public durumunu değiştirmez', () {
      const builder = RecipeShareTextBuilder();
      final r = Recipe(
        id: 'x',
        productName: 'Ekmek',
        quantities: RecipeQuantities.defaults,
        result: const RecipeCalculator()
            .calculateFromQuantities(RecipeQuantities.defaults),
        createdAt: DateTime(2026, 5, 13),
      );
      expect(r.isPublic, isFalse);
      final text = builder.build(r);
      // Hâlâ aynı reçete — paylaş aksiyonu yalnız metin üretir.
      expect(r.isPublic, isFalse);
      expect(text, contains('Ekmek Reçetesi'));
    });
  });

  group('RolePanelCards — reçete erişimi', () {
    test('ticari rolde Reçetelerim kartı /recipes\'a yönlendirir', () {
      final cards = RolePanelCards.forAccount(AccountType.commercial);
      final recipeCard = cards.firstWhere(
        (c) => c.route == '/recipes',
        orElse: () =>
            throw StateError('Ticari rolde Reçetelerim kartı bulunamadı'),
      );
      expect(recipeCard.label.toLowerCase(), contains('reçete'));
      expect(recipeCard.comingSoon, isFalse);
    });

    test('bireysel rolde Reçetelerim kartı /recipes\'a yönlendirir', () {
      final cards = RolePanelCards.forAccount(AccountType.individual);
      final recipeCard = cards.firstWhere(
        (c) => c.route == '/recipes',
        orElse: () =>
            throw StateError('Bireysel rolde Reçetelerim kartı bulunamadı'),
      );
      expect(recipeCard.label.toLowerCase(), contains('reçete'));
      expect(recipeCard.comingSoon, isFalse);
    });
  });
}
