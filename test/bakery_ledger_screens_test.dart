import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/bakery_panel/models/bakery_task.dart';
import 'package:firin_defter/features/bakery_panel/models/production_entry.dart';
import 'package:firin_defter/features/bakery_panel/models/waste_entry.dart';
import 'package:firin_defter/features/bakery_panel/providers/bakery_providers.dart';
import 'package:firin_defter/features/bakery_panel/repositories/bakery_repository.dart';
import 'package:firin_defter/features/bakery_panel/repositories/local_bakery_repository.dart';
import 'package:firin_defter/features/bakery_panel/screens/bakery_panel_screen.dart';
import 'package:firin_defter/features/bakery_panel/screens/end_of_day_screen.dart';
import 'package:firin_defter/features/bakery_panel/screens/production_entry_screen.dart';
import 'package:firin_defter/features/bakery_panel/screens/report_screen.dart';
import 'package:firin_defter/features/bakery_panel/screens/waste_entry_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Fırın Defteri V1 — ekran testleri.
class _FixedProfileController extends ProfileController {
  _FixedProfileController(super.ref) {
    state = BakeryProfile(
      displayName: 'Test Fırıncı',
      accountType: AccountType.commercial,
      city: 'Ankara',
      roleBadge: 'Fırıncı',
      email: 't@t.com',
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required BakeryRepository repo,
  Size size = const Size(1200, 3600),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bakeryRepositoryProvider.overrideWithValue(repo),
        profileControllerProvider.overrideWith(
          (ref) => _FixedProfileController(ref),
        ),
        // Rapor tablo testleri paywall'ı test etmez → premium ile tam içerik.
        // (Paywall kilit davranışı ayrı paywall_ui_test'te doğrulanır.)
        subscriptionRepositoryProvider.overrideWithValue(
          LocalSubscriptionRepository(plan: BusinessPlan.premium),
        ),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('Fırın Defteri ana ekran', () {
    testWidgets('bugün kartı + hızlı girişler + işler + boş kayıt durumu', (
      tester,
    ) async {
      final repo = LocalBakeryRepository();
      await _pump(tester, const BakeryPanelScreen(), repo: repo);
      expect(find.text(AppStrings.ledgerTitle), findsOneWidget);
      // Ciro girilmemiş → ₺ — ve Gün Açık rozeti.
      expect(find.text('₺ —'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ledger_day_status_open')),
        findsOneWidget,
      );
      // 6 hızlı giriş.
      for (final label in [
        AppStrings.ledgerQuickProduction,
        AppStrings.ledgerQuickWaste,
        AppStrings.ledgerQuickRevenue,
        AppStrings.ledgerQuickNote,
        AppStrings.ledgerQuickTask,
        AppStrings.ledgerQuickEndOfDay,
      ]) {
        expect(find.text(label), findsWidgets);
      }
      // Bugün ne yapacağım? boş → öneri chip'leri.
      expect(find.text(AppStrings.ledgerTasksSection), findsOneWidget);
      expect(
        find.byKey(
          ValueKey('ledger_suggestion_${kBakeryTaskSuggestions.first}'),
        ),
        findsOneWidget,
      );
      // Son kayıtlar boş durumu.
      expect(find.text(AppStrings.ledgerRecentEmpty), findsOneWidget);
      // Akıllı chip'ler: üretim yok + ciro yok + gün sonu bekliyor.
      expect(find.text(AppStrings.ledgerChipNoProduction), findsOneWidget);
      expect(find.text(AppStrings.ledgerChipNoRevenue), findsOneWidget);
      expect(find.text(AppStrings.ledgerChipDayOpen), findsOneWidget);
      // Gider linki var ama gider FORMU yok (ayrı menü kuralı).
      expect(find.byKey(const ValueKey('ledger_expense_link')), findsOneWidget);
      expect(find.text(AppStrings.ledgerExpenseLinkNote), findsOneWidget);
    });

    testWidgets('öneri chip\'i görev ekler; tamamlanınca işaretlenir', (
      tester,
    ) async {
      final repo = LocalBakeryRepository();
      await _pump(tester, const BakeryPanelScreen(), repo: repo);
      await tester.tap(
        find.byKey(const ValueKey('ledger_suggestion_Sabah kontrolü')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sabah kontrolü'), findsOneWidget);
      final task = (await repo.tasks(DateTime.now())).single;
      await tester.tap(find.byKey(ValueKey('ledger_task_done_${task.id}')));
      await tester.pumpAndSettle();
      expect((await repo.tasks(DateTime.now())).single.isDone, isTrue);
    });

    testWidgets('Ciro yaz → sheet → kaydet → hero güncellenir', (tester) async {
      final repo = LocalBakeryRepository();
      await _pump(tester, const BakeryPanelScreen(), repo: repo);
      await tester.tap(find.text(AppStrings.ledgerQuickRevenue));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.ledgerRevenueSheetTitle), findsOneWidget);
      // Boş submit → validasyon.
      await tester.tap(find.byKey(const ValueKey('ledger_revenue_save')));
      await tester.pumpAndSettle();
      expect(find.text('Ciro veya not gir.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.ledgerRevenueField),
        '4500',
      );
      await tester.tap(find.byKey(const ValueKey('ledger_revenue_save')));
      await tester.pumpAndSettle();
      expect((await repo.dayBook(DateTime.now()))!.revenueAmount, 4500);
      expect(find.text('₺ —'), findsNothing);
      expect(find.text(AppStrings.ledgerChipNoRevenue), findsNothing);
    });

    testWidgets('320dp + 1.3x taşma yapmaz', (tester) async {
      final repo = LocalBakeryRepository();
      await repo.upsertDayBook(
        day: DateTime.now(),
        revenue: 12345.67,
        dayNote: 'Uzun bir gün notu — taşma denemesi için yeterince uzun.',
      );
      await repo.addTask(day: DateTime.now(), title: 'Sipariş hazırlığı');
      await _pump(
        tester,
        const BakeryPanelScreen(),
        repo: repo,
        size: const Size(320, 5000),
        textScale: 1.3,
      );
      expect(find.text(AppStrings.ledgerTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('operasyon tabloları (tables polish)', () {
    testWidgets('ana ekranda üretim/fire tabloları: boş durum + CTA', (
      tester,
    ) async {
      final repo = LocalBakeryRepository();
      await _pump(tester, const BakeryPanelScreen(), repo: repo);
      expect(
        find.byKey(const ValueKey('ledger_table_production')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.ledgerTableProductionEmpty), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ledger_table_production_add')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ledger_table_waste')), findsOneWidget);
      expect(find.text(AppStrings.ledgerTableWasteEmpty), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ledger_table_waste_add')),
        findsOneWidget,
      );
    });

    testWidgets(
      'dolu tablolar: üretim satırı + fire sebep rozeti + görev durum rozeti',
      (tester) async {
        final repo = LocalBakeryRepository();
        await _addProduction(repo, 'Ekmek', 120);
        await repo.addWaste(
          WasteEntry(
            id: 'w1',
            product: 'Simit',
            quantity: 8,
            unitValue: 5,
            note: 'sabah',
            createdAt: DateTime.now(),
            reason: WasteReason.burnt,
          ),
        );
        await repo.addTask(day: DateTime.now(), title: 'Açık işim');
        final doneId = await repo.addTask(
          day: DateTime.now(),
          title: 'Biten işim',
        );
        await repo.setTaskDone(doneId, true);
        await _pump(tester, const BakeryPanelScreen(), repo: repo);
        // Üretim tablosu satırı.
        expect(find.text('120 adet'), findsWidgets);
        // Fire tablosu: sebep rozeti görünür.
        expect(find.text(WasteReason.burnt.label), findsWidgets);
        // Görevler: açık iş üstte, durum rozetleri görünür.
        final openY = tester.getTopLeft(find.text('Açık işim')).dy;
        final doneY = tester.getTopLeft(find.text('Biten işim')).dy;
        expect(openY, lessThan(doneY));
        expect(find.text(AppStrings.ledgerTaskStatusOpen), findsOneWidget);
        expect(find.text(AppStrings.ledgerTaskStatusDone), findsOneWidget);
      },
    );

    testWidgets('raporda Gün Sonu Defteri + Ürün Bazlı Özet tabloları', (
      tester,
    ) async {
      final repo = LocalBakeryRepository();
      await _addProduction(repo, 'Ekmek', 100);
      await repo.addWaste(
        WasteEntry(
          id: 'w1',
          product: 'Ekmek',
          quantity: 20,
          unitValue: 8,
          note: '',
          createdAt: DateTime.now(),
          reason: WasteReason.spoilage,
        ),
      );
      await repo.upsertDayBook(
        day: DateTime.now(),
        revenue: 5000,
        dayNote: 'İyi gün',
      );
      await _pump(tester, const ReportScreen(), repo: repo);
      expect(
        find.byKey(const ValueKey('ledger_table_daybook')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ledger_table_products')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ledger_table_notes')), findsOneWidget);
      // Fire oranı formatı (%20.0) + yüksek fire rozeti.
      expect(find.text('%20.0'), findsWidgets);
      expect(find.text(AppStrings.ledgerChipHighWaste), findsWidgets);
      expect(find.text('İyi gün'), findsOneWidget);
    });

    testWidgets('üretim yoksa üründe fire oranı — olur', (tester) async {
      final repo = LocalBakeryRepository();
      await repo.addWaste(
        WasteEntry(
          id: 'w1',
          product: 'Poğaça',
          quantity: 3,
          unitValue: 0,
          note: '',
          createdAt: DateTime.now(),
          reason: WasteReason.other,
        ),
      );
      await _pump(tester, const ReportScreen(), repo: repo);
      // Ürün satırında oran ve zarar '—'.
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('gün sonu ekranında Günün Özeti mini tablosu', (tester) async {
      final repo = LocalBakeryRepository();
      await _addProduction(repo, 'Ekmek', 90);
      await repo.addTask(day: DateTime.now(), title: 'Bir iş');
      await _pump(tester, const EndOfDayScreen(), repo: repo);
      expect(find.byKey(const ValueKey('ledger_table_eod')), findsOneWidget);
      expect(find.text(AppStrings.ledgerTableEodTitle), findsOneWidget);
      expect(find.text('90 adet'), findsWidgets);
    });

    testWidgets('tablolar 320dp + 1.3x taşma yapmaz + Tümünü gör katlaması', (
      tester,
    ) async {
      final repo = LocalBakeryRepository();
      for (var i = 0; i < 7; i++) {
        await _addProduction(repo, 'Uzun Ürün Adı Denemesi $i', 100 + i);
      }
      await repo.addWaste(
        WasteEntry(
          id: 'w1',
          product: 'Ekmek',
          quantity: 50,
          unitValue: 12.5,
          note: 'uzunca bir fire notu taşma denemesi',
          createdAt: DateTime.now(),
          reason: WasteReason.staffError,
        ),
      );
      await repo.upsertDayBook(day: DateTime.now(), revenue: 123456.78);
      await _pump(
        tester,
        const ReportScreen(),
        repo: repo,
        size: const Size(320, 6000),
        textScale: 1.3,
      );
      expect(
        find.byKey(const ValueKey('ledger_table_daybook')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      // "Tümünü gör" katlaması çalışır (8 ürün > 6 satır limiti).
      await tester.ensureVisible(
        find.byKey(const ValueKey('ledger_table_products_toggle')),
      );
      await tester.tap(
        find.byKey(const ValueKey('ledger_table_products_toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.ledgerTableShowLess), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('üretim / fire form validasyonu', () {
    testWidgets(
      'üretim: ürün seçilmeden kaydetme reddedilir; seçilince kaydolur',
      (tester) async {
        final repo = LocalBakeryRepository();
        await _pump(tester, const ProductionEntryScreen(), repo: repo);
        await tester.tap(find.text('KAYDET'));
        await tester.pump();
        expect(find.text('Önce bir ürün seç.'), findsOneWidget);
        // Ürün + adet → kaydet.
        await tester.tap(find.text('Ekmek').first);
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'Adet'), '120');
        await tester.tap(find.text('KAYDET'));
        await tester.pumpAndSettle();
        final list = await repo.listProduction(day: DateTime.now());
        expect(list.single.quantity, 120);
        expect(list.single.product, 'Ekmek');
      },
    );

    testWidgets('fire: sebep zorunlu; sebeple kaydolur', (tester) async {
      final repo = LocalBakeryRepository();
      await _pump(tester, const WasteEntryScreen(), repo: repo);
      await tester.tap(find.text('Ekmek').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Adet'), '7');
      // Sebep seçilmedi → hata.
      await tester.tap(find.text('KAYDET'));
      await tester.pump();
      expect(find.text(AppStrings.ledgerWasteReasonRequired), findsOneWidget);
      // Sebep seç → kaydet.
      await tester.tap(find.byKey(const ValueKey('waste_reason_burnt')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('KAYDET'));
      await tester.pumpAndSettle();
      final list = await repo.listWastes(day: DateTime.now());
      expect(list.single.quantity, 7);
      expect(list.single.reason.persistKey, 'burnt');
    });
  });

  group('Gün Sonu ekranı', () {
    testWidgets('açık gün → kapat → kapalı rozet + yeniden aç', (tester) async {
      final repo = LocalBakeryRepository();
      await _addProduction(repo, 'Ekmek', 100);
      await repo.upsertDayBook(day: DateTime.now(), revenue: 3000);
      await _pump(tester, const EndOfDayScreen(), repo: repo);
      expect(find.byKey(const ValueKey('eod_status_open')), findsOneWidget);
      expect(find.byKey(const ValueKey('ledger_close_day')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('ledger_close_day')),
      );
      await tester.tap(find.byKey(const ValueKey('ledger_close_day')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('eod_status_closed')), findsOneWidget);
      expect(find.byKey(const ValueKey('ledger_reopen_day')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('ledger_reopen_day')),
      );
      await tester.tap(find.byKey(const ValueKey('ledger_reopen_day')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('eod_status_open')), findsOneWidget);
      expect((await repo.dayBook(DateTime.now()))!.isClosed, isFalse);
    });
  });

  group('Rapor ekranı', () {
    testWidgets('dönem filtreleri + veri kartları + boş dönem', (tester) async {
      final repo = LocalBakeryRepository();
      await _addProduction(repo, 'Ekmek', 200);
      await repo.upsertDayBook(day: DateTime.now(), revenue: 8000);
      await _pump(tester, const ReportScreen(), repo: repo);
      // 4 dönem chip'i.
      for (final p in LedgerReportPeriod.values) {
        expect(find.byKey(ValueKey('ledger_period_${p.name}')), findsOneWidget);
      }
      // Bugün: üretim + ciro görünür (StatCard etiketleri uppercase).
      expect(
        find.text(AppStrings.ledgerEodProduction.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text('200 adet'), findsOneWidget);
      // Dün: boş dönem mesajı.
      await tester.tap(find.byKey(const ValueKey('ledger_period_yesterday')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.ledgerReportEmpty), findsOneWidget);
      // Son 7 gün: bugünkü veri yine kapsanır.
      await tester.tap(find.byKey(const ValueKey('ledger_period_week7')));
      await tester.pumpAndSettle();
      expect(find.text('200 adet'), findsOneWidget);
    });

    testWidgets('320dp + 1.3x rapor taşmaz', (tester) async {
      final repo = LocalBakeryRepository();
      await _addProduction(repo, 'Ekmek', 200);
      await _pump(
        tester,
        const ReportScreen(),
        repo: repo,
        size: const Size(320, 4000),
        textScale: 1.3,
      );
      expect(find.text(AppStrings.ledgerReportTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _addProduction(
  LocalBakeryRepository repo,
  String product,
  int qty,
) => repo.addProduction(
  ProductionEntry(
    id: 'seed-$product-$qty',
    product: product,
    quantity: qty,
    note: '',
    createdAt: DateTime.now(),
  ),
);
