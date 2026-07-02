import 'package:firin_defter/features/bakery_panel/calculators/models/calculator_category.dart';
import 'package:firin_defter/features/bakery_panel/calculators/registry/calculator_tools_registry.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 3 — yeni 6 modülün rol görünürlüğü ve hub kategori yerleşimi.
void main() {
  // Yeni ortak modüller (ticari + bireysel; toptancıya kapalı).
  const ortakYeni = {'stock_runway', 'batch_value'};
  // Yeni patron modülleri (yalnız ticari).
  const patronYeni = {
    'price_update',
    'fixed_cost',
    'waste_loss',
    'dealer_profit',
  };

  Set<String> idsFor(AccountType t) =>
      CalculatorToolsRegistry.forAccount(t).map((e) => e.id).toSet();

  group('Faz 3 rol görünürlüğü', () {
    test('ortak modüller ticari + bireyselde görünür', () {
      expect(idsFor(AccountType.commercial), containsAll(ortakYeni));
      expect(idsFor(AccountType.individual), containsAll(ortakYeni));
    });

    test('patron modülleri yalnız ticaride görünür', () {
      final commercial = idsFor(AccountType.commercial);
      final individual = idsFor(AccountType.individual);
      expect(commercial, containsAll(patronYeni));
      expect(individual.intersection(patronYeni), isEmpty);
    });

    test('toptancı yeni modüllerin hiçbirini görmez (boş kalır)', () {
      expect(idsFor(AccountType.wholesaler), isEmpty);
    });
  });

  group('Faz 3 hub kategori yerleşimi', () {
    CalculatorCategory categoryOf(String id) =>
        CalculatorToolsRegistry.all.firstWhere((t) => t.id == id).category;

    test('stok / tepsi-parti → Günlük Hızlı Hesaplar', () {
      expect(categoryOf('stock_runway'), CalculatorCategory.dailyQuick);
      expect(categoryOf('batch_value'), CalculatorCategory.dailyQuick);
    });

    test('fiyat güncelleme / sabit gider / fire → Patron Maliyet ve Kâr', () {
      expect(categoryOf('price_update'), CalculatorCategory.bossCostProfit);
      expect(categoryOf('fixed_cost'), CalculatorCategory.bossCostProfit);
      expect(categoryOf('waste_loss'), CalculatorCategory.bossCostProfit);
    });

    test('bayi kârlılık → Tedarikçi ve Pazarlık', () {
      expect(categoryOf('dealer_profit'), CalculatorCategory.supplierDeal);
    });

    test('yeni modüller doğru gruba düşer (ticari)', () {
      final groups = CalculatorToolsRegistry.groupedForAccount(
        AccountType.commercial,
      );
      final daily = groups
          .firstWhere((g) => g.category == CalculatorCategory.dailyQuick)
          .tools
          .map((t) => t.id);
      final boss = groups
          .firstWhere((g) => g.category == CalculatorCategory.bossCostProfit)
          .tools
          .map((t) => t.id);
      final supplier = groups
          .firstWhere((g) => g.category == CalculatorCategory.supplierDeal)
          .tools
          .map((t) => t.id);
      expect(daily, containsAll({'stock_runway', 'batch_value'}));
      expect(boss, containsAll({'price_update', 'fixed_cost', 'waste_loss'}));
      expect(supplier, contains('dealer_profit'));
    });

    test('cila: patron görünümünde Stok modülü üst bölümlerde (2. bölüm)', () {
      final groups = CalculatorToolsRegistry.groupedForAccount(
        AccountType.commercial,
      );
      final stockSection = groups.indexWhere(
        (g) => g.tools.any((t) => t.id == 'stock_runway'),
      );
      final bossSection = groups.indexWhere(
        (g) => g.category == CalculatorCategory.bossCostProfit,
      );
      // Stok (Günlük Hızlı), Maliyet/Kâr bölümünün üstünde ve en fazla 2.
      // bölümde olmalı (Üretim'den hemen sonra).
      expect(stockSection, lessThan(bossSection));
      expect(stockSection, lessThanOrEqualTo(1));
    });
  });

  group('Faz 3 bütünlük', () {
    test('tüm araçlar tekil id + tekil route taşır', () {
      final ids = CalculatorToolsRegistry.all.map((e) => e.id).toList();
      final routes = CalculatorToolsRegistry.all.map((e) => e.route).toList();
      expect(ids.toSet().length, ids.length, reason: 'id tekrarı var');
      expect(routes.toSet().length, routes.length, reason: 'route tekrarı var');
    });
  });
}
