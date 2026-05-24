// Sprint 6C — CashTenderedCalculator widget testleri.
//
// Donor (evan361425/flutter-pos-system) keypad mantığını birebir koruyor:
// 5-kolon layout, _operators ['+', '-', 'x'], submit state machine,
// paid >= price → change pozitif, paid < price → error text.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/utils/number_formatter.dart';
import 'package:firin_defter/features/dealers/widgets/cash_tendered_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap({
    required ValueNotifier<num> price,
    required ValueNotifier<num> paid,
    required VoidCallback onSubmit,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: CashTenderedCalculator(
            price: price,
            paid: paid,
            onSubmit: onSubmit,
          ),
        ),
      ),
    );
  }

  group('CashTenderedCalculator — rendering', () {
    testWidgets('iki display row (Verilen / Para üstü) + keypad', (tester) async {
      final price = ValueNotifier<num>(100);
      final paid = ValueNotifier<num>(100);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      expect(find.text(AppStrings.cashCalcLabelPaid), findsOneWidget);
      expect(find.text(AppStrings.cashCalcLabelChange), findsOneWidget);
      // 9 dijit + 0 + 00 + . + 4 operatör + 3 aksiyon = 18 button
      expect(find.byKey(const Key('cashier.calculator.1')), findsOneWidget);
      expect(find.byKey(const Key('cashier.calculator.0')), findsOneWidget);
      expect(find.byKey(const Key('cashier.calculator.dot')), findsOneWidget);
      expect(find.byKey(const Key('cashier.calculator.submit')), findsOneWidget);
    });

    testWidgets('initial state — paid hint = price tutarı', (tester) async {
      final price = ValueNotifier<num>(250);
      final paid = ValueNotifier<num>(250);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      // İlk açılışta paid input boş, default text = price currency formatlı
      expect(
        find.byKey(const Key('cashier.calculator.paid.hint')),
        findsOneWidget,
      );
    });
  });

  group('CashTenderedCalculator — keypad input', () {
    testWidgets('dijit tap → paid notifier güncellenir', (tester) async {
      final price = ValueNotifier<num>(100);
      final paid = ValueNotifier<num>(100);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      await tester.tap(find.byKey(const Key('cashier.calculator.1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();

      expect(paid.value, 100);
    });

    testWidgets('00 button → çift sıfır eklenir', (tester) async {
      final price = ValueNotifier<num>(0);
      final paid = ValueNotifier<num>(0);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      await tester.tap(find.byKey(const Key('cashier.calculator.5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.00')));
      await tester.pump();

      // "500" → paid = 500
      expect(paid.value, 500);
    });

    testWidgets('back button → son karakter silinir', (tester) async {
      final price = ValueNotifier<num>(0);
      final paid = ValueNotifier<num>(0);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      await tester.tap(find.byKey(const Key('cashier.calculator.1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.3')));
      await tester.pump();
      expect(paid.value, 123);

      await tester.tap(find.byKey(const Key('cashier.calculator.back')));
      await tester.pump();
      expect(paid.value, 12);
    });

    testWidgets('clear → paid sıfırlanır (= price)', (tester) async {
      final price = ValueNotifier<num>(50);
      final paid = ValueNotifier<num>(50);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      await tester.tap(find.byKey(const Key('cashier.calculator.9')));
      await tester.pump();
      expect(paid.value, 9);

      await tester.tap(find.byKey(const Key('cashier.calculator.clear')));
      await tester.pump();
      // text boş → paid notifier price'a düşer
      expect(paid.value, 50);
    });
  });

  group('CashTenderedCalculator — operators', () {
    testWidgets('+ operatörü → "=" davranışı (5+3=8)', (tester) async {
      final price = ValueNotifier<num>(0);
      final paid = ValueNotifier<num>(0);
      bool submitFired = false;

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () => submitFired = true,
      ));

      await tester.tap(find.byKey(const Key('cashier.calculator.5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.3')));
      await tester.pump();

      // İlk submit: operatör varken "=" davranışı; onSubmit fire ETMEZ
      await tester.tap(find.byKey(const Key('cashier.calculator.submit')));
      await tester.pump();
      expect(submitFired, isFalse);
      expect(paid.value, 8);

      // İkinci submit: operatör yok → onSubmit fire eder
      await tester.tap(find.byKey(const Key('cashier.calculator.submit')));
      await tester.pump();
      expect(submitFired, isTrue);
    });

    testWidgets('- operatörü (10-3=7)', (tester) async {
      final price = ValueNotifier<num>(0);
      final paid = ValueNotifier<num>(0);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      await tester.tap(find.byKey(const Key('cashier.calculator.1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.minus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.3')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.submit')));
      await tester.pump();

      expect(paid.value, 7);
    });

    testWidgets('x operatörü (4x5=20)', (tester) async {
      final price = ValueNotifier<num>(0);
      final paid = ValueNotifier<num>(0);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      await tester.tap(find.byKey(const Key('cashier.calculator.4')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.times')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.submit')));
      await tester.pump();

      expect(paid.value, 20);
    });
  });

  group('CashTenderedCalculator — submit & change display', () {
    testWidgets('paid > price → change pozitif (₺X gösterilir)', (tester) async {
      final price = ValueNotifier<num>(50);
      final paid = ValueNotifier<num>(50);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      // "100" gir → change = 100 - 50 = 50
      await tester.tap(find.byKey(const Key('cashier.calculator.1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();

      expect(paid.value, 100);
      expect(find.byKey(const Key('cashier.calculator.change')), findsOneWidget);
      expect(
        find.text(NumberFormatter.currency(50)),
        findsOneWidget,
      );
    });

    testWidgets('paid < price → change error text gösterilir', (tester) async {
      final price = ValueNotifier<num>(100);
      final paid = ValueNotifier<num>(100);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      // "50" gir → 50 < 100 → error
      await tester.tap(find.byKey(const Key('cashier.calculator.5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();

      expect(paid.value, 50);
      expect(
        find.byKey(const Key('cashier.calculator.change.error')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.cashCalcInsufficient), findsOneWidget);
    });

    testWidgets('submit (operatör yok, paid girilmiş) → onSubmit fire eder',
        (tester) async {
      final price = ValueNotifier<num>(50);
      final paid = ValueNotifier<num>(50);
      bool submitFired = false;

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () => submitFired = true,
      ));

      await tester.tap(find.byKey(const Key('cashier.calculator.1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.submit')));
      await tester.pump();

      expect(submitFired, isTrue);
    });
  });

  group('CashTenderedCalculator — ceil', () {
    testWidgets('ceil button → ondalıklı tutar yukarı yuvarlanır',
        (tester) async {
      final price = ValueNotifier<num>(0);
      final paid = ValueNotifier<num>(0);

      await tester.pumpWidget(wrap(
        price: price,
        paid: paid,
        onSubmit: () {},
      ));

      // "12.5" gir
      await tester.tap(find.byKey(const Key('cashier.calculator.1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.dot')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.5')));
      await tester.pump();
      expect(paid.value, 12.5);

      // ceil → 13
      await tester.tap(find.byKey(const Key('cashier.calculator.ceil')));
      await tester.pump();
      expect(paid.value, 13);
    });
  });
}
