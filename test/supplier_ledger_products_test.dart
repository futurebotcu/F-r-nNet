// Final Functional Sprint — Toptancı tedarik presetleri + rol bazlı çözüm +
// "Diğer/manuel ürün adı" standardı (ProductChoiceChips).

import 'dart:io';

import 'package:firin_defter/core/constants/app_products.dart';
import 'package:firin_defter/core/widgets/product_choice_chips.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('Toptancı tedarik presetleri', () {
    test('supplier listesi fırın tedarik ürünlerini içerir', () {
      for (final p in ['Un', 'Yaş maya', 'Sıvı yağ', 'Tuz', 'Şeker',
          'Susam', 'Çörek otu', 'Ambalaj', 'Katkı maddesi']) {
        expect(AppProducts.supplier.contains(p), isTrue, reason: '$p eksik');
      }
      // Fırın ürünleri (ekmek/simit) tedarik listesinde DEĞİL.
      expect(AppProducts.supplier.contains('Ekmek'), isFalse);
    });

    test('forAccountType: toptancı→supplier, diğer→defaults', () {
      expect(AppProducts.forAccountType(AccountType.wholesaler),
          AppProducts.supplier);
      expect(AppProducts.forAccountType(AccountType.commercial),
          AppProducts.defaults);
      expect(AppProducts.forAccountType(AccountType.individual),
          AppProducts.defaults);
      expect(AppProducts.forAccountType(null), AppProducts.defaults);
    });
  });

  group('Diğer + manuel ürün adı standardı (ProductChoiceChips)', () {
    testWidgets('preset chip seçimi onSelected ile değeri verir', (t) async {
      String? selected;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProductChoiceChips(
            selected: selected,
            onSelected: (v) => selected = v,
            products: const ['Un', 'Maya'],
          ),
        ),
      ));
      await t.tap(find.text('Un'));
      expect(selected, 'Un');
    });

    testWidgets('"Diğer" → manuel input açılır, yazılan ad onSelected\'e gider',
        (t) async {
      String? selected;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setState) => ProductChoiceChips(
              selected: selected,
              onSelected: (v) => setState(() => selected = v),
              products: const ['Un', 'Maya'],
            ),
          ),
        ),
      ));
      // "Diğer" chip'i var.
      expect(find.text('Diğer'), findsOneWidget);
      await t.tap(find.text('Diğer'));
      await t.pump();
      // Manuel input alanı açıldı.
      expect(find.byType(TextField), findsOneWidget);
      // Manuel ürün adı yaz → onSelected trim'li değer alır.
      await t.enterText(find.byType(TextField), '  Özel un karışımı  ');
      await t.pump();
      expect(selected, 'Özel un karışımı');
    });

    testWidgets('preset dışı başlangıç değeri "Diğer" modunu açar', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProductChoiceChips(
            selected: 'Katkı karışımı X',
            onSelected: (_) {},
            products: const ['Un', 'Maya'],
          ),
        ),
      ));
      await t.pump();
      // Manuel input açık ve değer dolu.
      expect(find.text('Katkı karışımı X'), findsOneWidget);
    });
  });

  group('Rol bazlı preset bağlama (kaynak sözleşmesi)', () {
    final forms = <String>[
      'lib/features/dealers/screens/dealer_delivery_form_screen.dart',
      'lib/features/dealers/screens/dealer_return_form_screen.dart',
      'lib/features/dealers/screens/dealer_detail_screen.dart',
    ];
    for (final f in forms) {
      test('$f rol bazlı products kullanır', () {
        final src = _read(f);
        expect(src.contains('AppProducts.forAccountType'), isTrue);
      });
    }

    test('Toptancı panel kartı fırın-müşteri odaklı copy', () {
      final src = _read('lib/core/constants/app_strings.dart');
      expect(src.contains("cardWholesaleCustomers = 'Fırın Müşterileri'"),
          isTrue);
    });
  });
}
