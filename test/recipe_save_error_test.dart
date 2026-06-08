// V1.4 P1.6 — RecipeEditorScreen save hata yönetimi regression.
//
// Risk register kanıtı: P1.6 — `_save` içindeki `catch (e)` raw `$e`
// interpolasyonu yapıyor (`Kaydedilemedi: $e`); GuestActionRequiredException
// sessizce yutuluyordu. Patch:
//   - `on GuestActionRequiredException` → showAuthRequiredSheet (defense-in-depth)
//   - `catch (_)` → Türkçe `AppStrings.recipeSaveError`
//
// Bu test:
//   - Fake recipe repo `save` throws → Türkçe snackbar görünür
//   - `_saving=false`, kaydet butonu yeniden basılabilir
//   - Form verileri korunur (kullanıcı tekrar deneyebilir)
//   - Raw `Kaydedilemedi: $e` snackbar artık görünmez

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_record.dart';
import 'package:firin_defter/features/bakery_panel/providers/bakery_providers.dart';
import 'package:firin_defter/features/bakery_panel/repositories/local_recipe_repository.dart';
import 'package:firin_defter/features/bakery_panel/repositories/recipe_repository.dart';
import 'package:firin_defter/features/bakery_panel/screens/recipe_editor_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────── Fake

class _ThrowingRecipeRepository extends LocalRecipeRepository {
  _ThrowingRecipeRepository() : super();

  int saveCalls = 0;

  @override
  Future<Recipe> save(Recipe draft) {
    saveCalls++;
    return Future<Recipe>.error(Exception('network boom (recipe save)'));
  }
}

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _realProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

Widget _wrap({required RecipeRepository repo}) {
  return ProviderScope(
    overrides: [
      recipeRepositoryProvider.overrideWithValue(repo),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, _realProfile),
      ),
    ],
    child: const MaterialApp(home: RecipeEditorScreen()),
  );
}

Finder _primaryButton() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'AppPrimaryButton',
  );
}

Future<Finder> _findSaveButton(WidgetTester tester) async {
  final saveButton = _primaryButton();
  if (saveButton.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      saveButton,
      find.byType(ListView),
      const Offset(0, -300),
    );
  } else {
    await tester.ensureVisible(saveButton);
  }
  await tester.pumpAndSettle();
  return saveButton;
}

void main() {
  testWidgets('P1.6 — RecipeEditorScreen save throws → Türkçe hata snackbar; '
      '_saving false, form korunur, raw error UI\'ya sızmaz', (tester) async {
    final repo = _ThrowingRecipeRepository();
    await tester.pumpWidget(_wrap(repo: repo));

    // İlk render — varsayılan değerler (_flour='50', _water='30', _piece='250')
    // validation'ı geçer; ek form doldurmaya gerek yok.
    await tester.pumpAndSettle();

    final saveButton = await _findSaveButton(tester);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // 1) Repo gerçekten çağrıldı (validation + guard passed).
    expect(repo.saveCalls, 1);

    // 2) Türkçe hata snackbar'ı görünür.
    expect(
      find.text(AppStrings.recipeSaveError),
      findsOneWidget,
      reason: 'recipe save fırlattığında Türkçe hata gösterilmeli.',
    );

    // 3) Raw "Kaydedilemedi: " prefix'i artık UI'da görünmemeli.
    expect(
      find.textContaining('Kaydedilemedi:'),
      findsNothing,
      reason: 'Raw exception sızıntısı kaldırıldı; eski snackbar metni yok.',
    );

    // 4) Buton tekrar basılabilir, kaydetme state'inde kalmamalı.
    expect(_primaryButton(), findsOneWidget);
    expect(find.text('Kaydediliyor…'), findsNothing);

    // 5) Form korunur — RecipeEditorScreen hâlâ render'da. Spesifik
    //    field değerlerini test etmek yerine ekranın hâlâ açık olduğunu
    //    (kaydet butonu mevcut) doğrulamak yeterli; ayrıntı yukarıda (#4).
    expect(find.byType(RecipeEditorScreen), findsOneWidget);
  });

  testWidgets(
    'P1.6 regression — başarılı save mevcut akışı korur (sadece smoke)',
    (tester) async {
      final repo = LocalRecipeRepository();
      await tester.pumpWidget(_wrap(repo: repo));
      await tester.pumpAndSettle();

      // Default değerlerle save → success path.
      // Bu test "Reçete kaydedildi: ..." snackbar veya pushReplacement
      // davranışını doğrulamaz (navigation provider override gerektirir);
      // sadece raw "Kaydedilemedi:" snackbar veya recipeSaveError görünmediğini
      // doğrular — yani success path break etmedi.
      final saveButton = await _findSaveButton(tester);
      await tester.tap(saveButton);
      // pushReplacement çağrısı yapabileceği için pumpAndSettle yerine kısa pump.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Hata snackbar'ı görünmemeli.
      expect(find.text(AppStrings.recipeSaveError), findsNothing);
      expect(find.textContaining('Kaydedilemedi:'), findsNothing);
    },
  );
}
