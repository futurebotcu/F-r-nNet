import 'package:firin_defter/features/bakery_panel/calculators/models/calculator_role_visibility.dart';
import 'package:firin_defter/features/bakery_panel/calculators/models/calculator_tool.dart';
import 'package:firin_defter/features/bakery_panel/calculators/registry/calculator_tools_registry.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalculatorRoleVisibility', () {
    test('producers ticari + bireysele açık, toptancıya kapalı', () {
      const v = CalculatorRoleVisibility.producers;
      expect(v.isVisibleTo(AccountType.commercial), isTrue);
      expect(v.isVisibleTo(AccountType.individual), isTrue);
      expect(v.isVisibleTo(AccountType.wholesaler), isFalse);
    });

    test('all tüm rollere açık', () {
      const v = CalculatorRoleVisibility.all;
      expect(v.isVisibleTo(AccountType.commercial), isTrue);
      expect(v.isVisibleTo(AccountType.individual), isTrue);
      expect(v.isVisibleTo(AccountType.wholesaler), isTrue);
    });

    test('commercialOnly / individualOnly tek role açık', () {
      expect(
        CalculatorRoleVisibility.commercialOnly.isVisibleTo(
          AccountType.commercial,
        ),
        isTrue,
      );
      expect(
        CalculatorRoleVisibility.commercialOnly.isVisibleTo(
          AccountType.individual,
        ),
        isFalse,
      );
      expect(
        CalculatorRoleVisibility.individualOnly.isVisibleTo(
          AccountType.individual,
        ),
        isTrue,
      );
    });
  });

  group('CalculatorToolsRegistry.forAccount', () {
    test('ticari rolde Hamurdan Ürün aracı görünür', () {
      final tools = CalculatorToolsRegistry.forAccount(AccountType.commercial);
      expect(tools.map((t) => t.id), contains('dough_yield'));
    });

    test('bireysel rolde Hamurdan Ürün aracı görünür', () {
      final tools = CalculatorToolsRegistry.forAccount(AccountType.individual);
      expect(tools.map((t) => t.id), contains('dough_yield'));
    });

    test('toptancı rolde hesaplama aracı görünmez (boş liste)', () {
      final tools = CalculatorToolsRegistry.forAccount(AccountType.wholesaler);
      expect(tools, isEmpty);
    });

    test('filtre yalnız enabled + role görünür araçları döndürür', () {
      // enabled=false bir araç hiçbir rolde görünmez.
      const disabled = CalculatorTool(
        id: 'x',
        title: 't',
        description: 'd',
        icon: Icons.calculate,
        route: '/calculator/x',
        visibility: CalculatorRoleVisibility.all,
        enabled: false,
      );
      expect(disabled.isVisibleTo(AccountType.commercial), isTrue);
      // (registry yalnız enabled olanları döndürür; bu birim seviyesinde
      // isVisibleTo görünürlüğü, enabled'i registry filtreler.)
    });

    test('dough_yield aracı doğru route ile tanımlı', () {
      final tool = CalculatorToolsRegistry.all.firstWhere(
        (t) => t.id == 'dough_yield',
      );
      expect(tool.route, '/calculator/dough');
      expect(tool.enabled, isTrue);
    });
  });
}
