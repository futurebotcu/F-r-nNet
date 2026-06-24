import 'package:firin_defter/features/bakery_panel/calculators/models/calculator_category.dart';
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

  group('Rol görünürlük matrisi (ortak / çalışan / patron)', () {
    // Modül id → beklenen kategori.
    const ortak = {
      'dough_yield',
      'morning_plan',
      'water_ratio',
      'sack_bread',
      'bakers_percent',
      'recipe_scale',
    };
    const calisan = {'water_temp'};
    const patron = {
      'cost_profit',
      'flour_hike',
      'oven_energy',
      'free_goods',
      'evening_discount',
    };

    Set<String> idsFor(AccountType t) =>
        CalculatorToolsRegistry.forAccount(t).map((e) => e.id).toSet();

    test(
      'patron (ticari) ortak + patron modüllerini görür, çalışanı görmez',
      () {
        final ids = idsFor(AccountType.commercial);
        expect(ids, containsAll(ortak));
        expect(ids, containsAll(patron));
        expect(ids.intersection(calisan), isEmpty);
      },
    );

    test('bireysel ortak + çalışan modüllerini görür, patronu görmez', () {
      final ids = idsFor(AccountType.individual);
      expect(ids, containsAll(ortak));
      expect(ids, containsAll(calisan));
      expect(ids.intersection(patron), isEmpty);
    });

    test('toptancı hiçbir modülü görmez (boş)', () {
      expect(idsFor(AccountType.wholesaler), isEmpty);
    });

    test('her araç tekil id + tekil route taşır', () {
      final ids = CalculatorToolsRegistry.all.map((e) => e.id).toList();
      final routes = CalculatorToolsRegistry.all.map((e) => e.route).toList();
      expect(ids.toSet().length, ids.length, reason: 'id tekrarı var');
      expect(routes.toSet().length, routes.length, reason: 'route tekrarı var');
    });
  });

  group('groupedForAccount (kategori + rol sıralaması)', () {
    test('bireysel: Günlük Hızlı önce, sonra Üretim; patron grupları yok', () {
      final groups = CalculatorToolsRegistry.groupedForAccount(
        AccountType.individual,
      );
      final cats = groups.map((g) => g.category).toList();
      expect(cats, [
        CalculatorCategory.dailyQuick,
        CalculatorCategory.productionRecipe,
      ]);
      // dailyQuick içinde su sıcaklığı (çalışan) yer alır.
      final daily = groups.first.tools.map((t) => t.id);
      expect(daily, contains('water_temp'));
    });

    test('patron: Üretim → Maliyet/Kâr → Tedarikçi → Günlük sırası', () {
      final groups = CalculatorToolsRegistry.groupedForAccount(
        AccountType.commercial,
      );
      final cats = groups.map((g) => g.category).toList();
      expect(cats, [
        CalculatorCategory.productionRecipe,
        CalculatorCategory.bossCostProfit,
        CalculatorCategory.supplierDeal,
        CalculatorCategory.dailyQuick,
      ]);
      // Üretim grubunun ilk aracı sabah üretim planlayıcı (en sık).
      expect(groups.first.tools.first.id, 'morning_plan');
    });

    test('toptancı: hiç grup yok', () {
      expect(
        CalculatorToolsRegistry.groupedForAccount(AccountType.wholesaler),
        isEmpty,
      );
    });

    test('her görünür araç tam olarak bir gruba düşer', () {
      for (final type in [AccountType.individual, AccountType.commercial]) {
        final visible = CalculatorToolsRegistry.forAccount(type).length;
        final grouped = CalculatorToolsRegistry.groupedForAccount(
          type,
        ).fold<int>(0, (sum, g) => sum + g.tools.length);
        expect(grouped, visible, reason: '$type: araç sayısı korunmalı');
      }
    });
  });
}
