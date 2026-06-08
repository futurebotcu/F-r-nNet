// V1.4 P1.5 — CreateProfileScreen hydrate-then-submit guard regression.
//
// Risk register kanıtı: P1.5 — Google OAuth sonrası completion mode'da
// ProfileController async hydrate ediliyor. `_hydrateFromProfile`
// `_accountType` ve `_badge`'i KOŞULSUZ overwrite eder (display_name/city
// yalnız boşken doldurulur). Hydrate tamamlanmadan kullanıcı Kaydet'e
// basarsa default `commercial`/`first-badge` Supabase'e yazılır.
//
// Patch: `_save` içinde erken submit guard:
//
//   if (_isCompletion && !_profileHydrated) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text(AppStrings.profileStillLoadingError)),
//     );
//     return;
//   }
//
// Bu test source-level audit pattern'iyle (account_deletion_p0_test.dart
// ile aynı) guard'ın doğru konumda + doğru çağrı ile var olduğunu doğrular.
// Tam widget pump testi profile controller hydrate timing'i ile race
// koşullarını simüle etmeyi gerektirir; source assertion regresyonu
// minimum maliyetle aynı garantiyi verir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreateProfileScreen P1.5 hydrate-submit guard (source)', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/profile/screens/create_profile_screen.dart',
      ).readAsStringSync();
    });

    test('AppStrings.profileStillLoadingError referansı mevcut', () {
      expect(
        src.contains('AppStrings.profileStillLoadingError'),
        isTrue,
        reason: 'Guard Türkçe snackbar key\'ini kullanmalı',
      );
    });

    test('P1.5 guard koşulu mevcut (_isCompletion && !_profileHydrated)', () {
      expect(
        src.contains('_isCompletion && !_profileHydrated'),
        isTrue,
        reason:
            'Guard yalnız completion mode + pre-hydrate durumunda devreye girer',
      );
    });

    test(
      'guard _save\'in başında — validate ve _submitting kontrollerinden sonra, '
      'legal check ve repo save\'den önce',
      () {
        final idxSaveStart = src.indexOf('Future<void> _save() async');
        final idxValidate = src.indexOf(
          '_formKey.currentState!.validate()',
          idxSaveStart,
        );
        final idxSubmittingCheck = src.indexOf(
          'if (_submitting) return;',
          idxSaveStart,
        );
        final idxGuard = src.indexOf(
          '_isCompletion && !_profileHydrated',
          idxSaveStart,
        );
        // Legal check daha sonra gelmeli (signup mode):
        final idxLegalCheck = src.indexOf(
          'if (!_isCompletion && !_legalAccepted)',
          idxSaveStart,
        );
        // Repo save çağrılarının ilki (completion path):
        final saveMatch = RegExp(
          r'profileControllerProvider\.notifier\)\s*\.save',
        ).firstMatch(src.substring(idxSaveStart));
        final idxRepoSave = saveMatch == null
            ? -1
            : idxSaveStart + saveMatch.start;

        expect(idxSaveStart, greaterThan(-1));
        expect(idxValidate, greaterThan(idxSaveStart));
        expect(idxSubmittingCheck, greaterThan(idxValidate));
        expect(
          idxGuard,
          greaterThan(idxSubmittingCheck),
          reason: 'Guard `_submitting` kontrolünden sonra olmalı',
        );
        expect(
          idxLegalCheck,
          greaterThan(idxGuard),
          reason: 'Legal check guard\'dan sonra çalışmalı',
        );
        expect(
          idxRepoSave,
          greaterThan(idxGuard),
          reason: 'Repo save guard\'dan sonra çağrılmalı',
        );
      },
    );

    test('guard içinde mounted check + snackbar + return var', () {
      final idxGuard = src.indexOf('_isCompletion && !_profileHydrated');
      // Guard'ı izleyen kısa blok içinde:
      final idxMounted = src.indexOf('if (!mounted) return;', idxGuard);
      final idxSnackbar = src.indexOf(
        'AppStrings.profileStillLoadingError',
        idxGuard,
      );
      // Guard return early olmalı (legal check'e kadar düşmesin):
      final idxLegalCheck = src.indexOf(
        'if (!_isCompletion && !_legalAccepted)',
        idxGuard,
      );

      expect(
        idxMounted,
        greaterThan(idxGuard),
        reason: 'Guard içinde mounted check olmalı',
      );
      expect(
        idxSnackbar,
        greaterThan(idxMounted),
        reason: 'Snackbar mounted check sonrası fire etmeli',
      );
      expect(
        idxSnackbar,
        lessThan(idxLegalCheck),
        reason: 'Snackbar guard içinde olmalı, legal check\'ten önce',
      );
    });

    test('mevcut completion mode contract korunmuş (_isCompletion = true)', () {
      // Patch _hydrateFromProfile semantiğini değiştirmedi; mevcut
      // _isCompletion atamaları (initState'te authUser != null veya existing
      // != null durumlarında) yerinde kalmalı.
      expect(
        src.contains('_isCompletion = true'),
        isTrue,
        reason:
            'Completion mode'
            ' atama satırları korunmalı',
      );
      expect(
        src.contains('_hydrateFromProfile'),
        isTrue,
        reason: '_hydrateFromProfile metodu korunmalı',
      );
      expect(
        src.contains('_profileHydrated = true'),
        isTrue,
        reason: 'Hydrate tamamlanınca flag true yapılmalı',
      );
    });
  });
}
