// PR-UI-2 — form kaydedilmemiş değişiklik koruması.
// DirtyFormGuard davranışı (widget) + dialog + 6 formun wiring'i (source-assert).

import 'dart:io';

import 'package:firin_defter/core/widgets/dirty_form_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('DirtyFormGuard — geri davranışı', () {
    Future<GlobalKey<NavigatorState>> pushForm(
      WidgetTester tester, {
      required bool isDirty,
    }) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: Text('home')),
      ));
      nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => DirtyFormGuard(
          isDirty: isDirty,
          child: const Scaffold(body: Text('form')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('form'), findsOneWidget);
      return nav;
    }

    testWidgets('dirty: geri → onay dialogu açar, ekranda kalır',
        (tester) async {
      final nav = await pushForm(tester, isDirty: true);
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Değişiklikleri sil?'), findsOneWidget);
      expect(find.text('form'), findsOneWidget); // çıkmadı
    });

    testWidgets('clean: geri → dialogsuz çıkar (home döner)', (tester) async {
      final nav = await pushForm(tester, isDirty: false);
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Değişiklikleri sil?'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('dirty + onay → çıkar (home döner)', (tester) async {
      final nav = await pushForm(tester, isDirty: true);
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Değişiklikleri sil'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('showDiscardChangesDialog', () {
    testWidgets('onay → true; vazgeç → false', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold();
        }),
      ));

      // Vazgeç → false
      final f1 = showDiscardChangesDialog(ctx);
      await tester.pumpAndSettle();
      expect(find.text('Değişiklikleri sil?'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(await f1, isFalse);

      // Onay → true
      final f2 = showDiscardChangesDialog(ctx);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Değişiklikleri sil'));
      await tester.pumpAndSettle();
      expect(await f2, isTrue);
    });
  });

  group('6 form DirtyFormGuard ile sarılı', () {
    final forms = <String, String>{
      'add_dealer': 'lib/features/dealers/screens/add_dealer_screen.dart',
      'dealer_delivery':
          'lib/features/dealers/screens/dealer_delivery_form_screen.dart',
      'supplier_product':
          'lib/features/b2b_market/screens/supplier/forms/supplier_product_form_screen.dart',
      'supplier_campaign':
          'lib/features/b2b_market/screens/supplier/forms/supplier_campaign_form_screen.dart',
      'market_listing':
          'lib/features/marketplace/screens/market_listing_form_screen.dart',
      'social_composer':
          'lib/features/social/composer/social_composer_page.dart',
    };

    forms.forEach((name, path) {
      test('$name → DirtyFormGuard + _dirty', () {
        final src = _read(path);
        expect(src.contains('dirty_form_guard.dart'), isTrue,
            reason: '$name import eksik');
        expect(src.contains('DirtyFormGuard(isDirty: _dirty'), isTrue,
            reason: '$name wrap eksik');
        expect(src.contains('_dirty'), isTrue);
      });
    });

    test('composer custom geri butonu guard üzerinden pop eder', () {
      final src = _read('lib/features/social/composer/social_composer_page.dart');
      expect(src.contains('maybePopWithDirtyGuard'), isTrue);
    });

    test('Form tabanlı ekranlar Form.onChanged ile text dirty işaretler', () {
      for (final p in [
        'lib/features/dealers/screens/add_dealer_screen.dart',
        'lib/features/b2b_market/screens/supplier/forms/supplier_product_form_screen.dart',
        'lib/features/b2b_market/screens/supplier/forms/supplier_campaign_form_screen.dart',
        'lib/features/marketplace/screens/market_listing_form_screen.dart',
      ]) {
        expect(_read(p).contains('onChanged: _markDirty'), isTrue,
            reason: '$p Form.onChanged eksik');
      }
    });
  });
}
