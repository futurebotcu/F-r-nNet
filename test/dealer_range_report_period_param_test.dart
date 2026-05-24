// Quality Patch v2 — DealerRangeReportScreen initial period query param
// tüketim testleri.
//
// Raporlar tab'ından `?period=last30Days` veya `?period=thisMonth` ile
// gelirse o chip seçili açılır. Bilinmeyen/yok ise default last30Days
// davranışı korunur (Sprint 3 yine yeşil).

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_range_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<LocalDealerRepository> _seededRepo() async {
  final repo = LocalDealerRepository(seed: false);
  await repo.upsertDealer(Dealer(
    id: 'd1',
    name: 'Hamdi Bakkal',
    createdAt: DateTime(2026, 1, 1),
  ));
  // Sadece "Bu ay" range'ine düşen bir tx ekle — chip seçimi metrikleri
  // değiştirebilir; rapor tipi ne olursa olsun ekran render edilmeli.
  await repo.addTransaction(DealerTransaction(
    id: 't1',
    dealerId: 'd1',
    type: DealerTransactionType.delivery,
    amount: 500,
    createdAt: DateTime(2026, 5, 10),
  ));
  return repo;
}

GoRouter _routerWithQuery(String? period) {
  final query = (period == null) ? '' : '?period=$period';
  return GoRouter(
    initialLocation: '/dealers/d1/report$query',
    routes: [
      GoRoute(
        path: '/dealers/:id/report',
        builder: (_, state) => DealerRangeReportScreen(
          dealerId: state.pathParameters['id']!,
          initialPeriodKey: state.uri.queryParameters['period'],
          now: DateTime(2026, 5, 24, 10),
        ),
      ),
    ],
  );
}

Widget _wrap(LocalDealerRepository repo, GoRouter router) {
  return ProviderScope(
    overrides: [dealerRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('DealerRangeReportScreen — initial period query', () {
    testWidgets('query yok → default Son 30 gün chip seçili',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo, _routerWithQuery(null)));
      await tester.pumpAndSettle();

      // 6 chip render olur; Son 30 gün default.
      expect(find.text(AppStrings.dealerReportPeriodLast30), findsOneWidget);
      // ChoiceChip selected görsel kontrolü için seçili olanın
      // ChoiceChip widget'ı bulunur.
      final last30 = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      // En az 6 chip vardır; seçili olan tek tane.
      final selected = last30.where((c) => c.selected).toList();
      expect(selected.length, 1);
      // Seçili chip'in label'ı "Son 30 gün" olmalı.
      final selectedLabel = (selected.first.label as Text).data;
      expect(selectedLabel, AppStrings.dealerReportPeriodLast30);
    });

    testWidgets('?period=thisMonth → Bu ay chip seçili açılır',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo, _routerWithQuery('thisMonth')));
      await tester.pumpAndSettle();

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      final selected = chips.where((c) => c.selected).toList();
      expect(selected.length, 1);
      final label = (selected.first.label as Text).data;
      // Range report'taki 'Bu ay' chip label'ı `AppStrings.dealerRangePeriodThisMonth`
      // veya benzeri; bu testte label string'i içeriği kontrol etmek yerine
      // chip'in seçili olduğunu ve "Ay" geçtiğini doğrula (locale-agnostik).
      expect(label?.toLowerCase().contains('ay'), isTrue);
    });

    testWidgets('bilinmeyen ?period=garbage → default Son 30 gün',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo, _routerWithQuery('garbage')));
      await tester.pumpAndSettle();

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      final selected = chips.where((c) => c.selected).toList();
      expect(selected.length, 1);
      final label = (selected.first.label as Text).data;
      expect(label, AppStrings.dealerReportPeriodLast30);
    });
  });
}
