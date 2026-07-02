import 'package:firin_defter/features/bakery_panel/calculators/models/calculator_category.dart';
import 'package:firin_defter/features/bakery_panel/calculators/registry/calculator_tools_registry.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Final tamamlama paketi — 11 yeni modülün rol görünürlüğü ve hub
/// kategori yerleşimi.
void main() {
  // Yeni ortak modüller (ticari + bireysel; toptancıya kapalı).
  const ortakYeni = {'weight_change', 'pack_convert'};
  // Yeni çalışan modülleri (yalnız bireysel).
  const calisanYeni = {'fermentation_time', 'overtime_pay'};
  // Yeni patron modülleri (yalnız ticari).
  const patronYeni = {
    'recipe_cost_detail',
    'flat_deal',
    'oven_capacity',
    'labor_index',
    'master_earnings',
    'tip_split',
    'daily_close',
  };

  Set<String> idsFor(AccountType t) =>
      CalculatorToolsRegistry.forAccount(t).map((e) => e.id).toSet();

  group('Final paket rol görünürlüğü', () {
    test('ortak modüller ticari + bireyselde görünür', () {
      expect(idsFor(AccountType.commercial), containsAll(ortakYeni));
      expect(idsFor(AccountType.individual), containsAll(ortakYeni));
    });

    test('çalışan modülleri yalnız bireyselde görünür', () {
      expect(idsFor(AccountType.individual), containsAll(calisanYeni));
      expect(idsFor(AccountType.commercial).intersection(calisanYeni), isEmpty);
    });

    test('patron modülleri yalnız ticaride görünür', () {
      expect(idsFor(AccountType.commercial), containsAll(patronYeni));
      expect(idsFor(AccountType.individual).intersection(patronYeni), isEmpty);
    });

    test('toptancı yeni modüllerin hiçbirini görmez (boş kalır)', () {
      expect(idsFor(AccountType.wholesaler), isEmpty);
    });
  });

  group('Final paket hub kategori yerleşimi', () {
    CalculatorCategory categoryOf(String id) =>
        CalculatorToolsRegistry.all.firstWhere((t) => t.id == id).category;

    test('gramaj / mayalanma / kapanış → Günlük Hızlı Hesaplar', () {
      expect(categoryOf('weight_change'), CalculatorCategory.dailyQuick);
      expect(categoryOf('fermentation_time'), CalculatorCategory.dailyQuick);
      expect(categoryOf('daily_close'), CalculatorCategory.dailyQuick);
    });

    test('koli / mesai+prim / kapasite → Üretim ve Reçete', () {
      expect(categoryOf('pack_convert'), CalculatorCategory.productionRecipe);
      expect(categoryOf('overtime_pay'), CalculatorCategory.productionRecipe);
      expect(categoryOf('oven_capacity'), CalculatorCategory.productionRecipe);
    });

    test('detaylı reçete maliyeti / işçilik → Maliyet ve Kâr', () {
      expect(
        categoryOf('recipe_cost_detail'),
        CalculatorCategory.bossCostProfit,
      );
      expect(categoryOf('labor_index'), CalculatorCategory.bossCostProfit);
    });

    test('düz hesap → Tedarikçi ve Pazarlık', () {
      expect(categoryOf('flat_deal'), CalculatorCategory.supplierDeal);
    });

    test('usta hak ediş / prim bölüştürücü → Personel ve Paylaşım', () {
      expect(categoryOf('master_earnings'), CalculatorCategory.staffShare);
      expect(categoryOf('tip_split'), CalculatorCategory.staffShare);
    });

    test('patron görünümünde Personel ve Paylaşım en son bölümdür', () {
      final groups = CalculatorToolsRegistry.groupedForAccount(
        AccountType.commercial,
      );
      expect(groups.last.category, CalculatorCategory.staffShare);
      expect(
        groups.last.tools.map((t) => t.id),
        containsAll({'master_earnings', 'tip_split'}),
      );
    });

    test('bireysel görünümde patron/personel grupları hiç oluşmaz', () {
      final cats = CalculatorToolsRegistry.groupedForAccount(
        AccountType.individual,
      ).map((g) => g.category).toList();
      expect(cats, [
        CalculatorCategory.dailyQuick,
        CalculatorCategory.productionRecipe,
      ]);
    });

    test(
      'bireyselde günlük hızlı hesaplar üsttedir ve yeni araçları taşır',
      () {
        final groups = CalculatorToolsRegistry.groupedForAccount(
          AccountType.individual,
        );
        expect(groups.first.category, CalculatorCategory.dailyQuick);
        final daily = groups.first.tools.map((t) => t.id);
        expect(daily, containsAll({'weight_change', 'fermentation_time'}));
        final production = groups[1].tools.map((t) => t.id);
        expect(production, containsAll({'pack_convert', 'overtime_pay'}));
      },
    );

    test('patron görünümünde günlük kontrol (dailyQuick) 2. bölümdedir', () {
      final groups = CalculatorToolsRegistry.groupedForAccount(
        AccountType.commercial,
      );
      expect(groups[1].category, CalculatorCategory.dailyQuick);
      final daily = groups[1].tools.map((t) => t.id);
      expect(daily, containsAll({'stock_runway', 'daily_close'}));
    });
  });

  group('Final paket bütünlük', () {
    test('tüm araçlar tekil id + tekil route taşır', () {
      final ids = CalculatorToolsRegistry.all.map((e) => e.id).toList();
      final routes = CalculatorToolsRegistry.all.map((e) => e.route).toList();
      expect(ids.toSet().length, ids.length, reason: 'id tekrarı var');
      expect(routes.toSet().length, routes.length, reason: 'route tekrarı var');
    });

    test('yeni modüllerin tümü kayıtlı ve etkin', () {
      final all = CalculatorToolsRegistry.all;
      for (final id in {...ortakYeni, ...calisanYeni, ...patronYeni}) {
        final tool = all.firstWhere((t) => t.id == id);
        expect(tool.enabled, isTrue, reason: '$id etkin olmalı');
        expect(
          tool.route,
          startsWith('/calculator/'),
          reason: '$id route düzeni',
        );
      }
    });
  });
}
