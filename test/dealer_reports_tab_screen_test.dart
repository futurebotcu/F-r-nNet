// Sprint Raporlar — DealerReportsTabScreen widget testleri.
//
// 3 periyot segmenti (Son 7 gün / Son 30 gün / Bu ay), Genel Toplam
// KPI grid (Teslimat / İade / Tahsilat / İşlem Sayısı + Net Değişim
// emphasized), Bayi Bazlı Rapor listesi (yalnız aktif). Bayi satırı
// tap → /dealers/:id/report. Mevcut DealerRangeReportScreen bozulmaz.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_reports_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Test-deterministik referans zaman: 2026-05-24 10:00 (Pazar).
final _refNow = DateTime(2026, 5, 24, 10, 0);

Future<LocalDealerRepository> _seededRepo() async {
  final repo = LocalDealerRepository(seed: false);
  // 2 aktif bayi + 1 pasif bayi
  await repo.upsertDealer(Dealer(
    id: 'd-active-1',
    name: 'Hamdi Bakkal',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-active-2',
    name: 'Mehmet Market',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-passive',
    name: 'Şenel Büfe',
    isActive: false,
    createdAt: DateTime(2026, 1, 1),
  ));

  // Hamdi son 7 gün içinde: delivery 500 + payment 200 (net +300)
  await repo.addTransaction(DealerTransaction(
    id: 't-h1',
    dealerId: 'd-active-1',
    type: DealerTransactionType.delivery,
    amount: 500,
    createdAt: _refNow.subtract(const Duration(days: 2)),
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't-h2',
    dealerId: 'd-active-1',
    type: DealerTransactionType.payment,
    amount: 200,
    createdAt: _refNow.subtract(const Duration(days: 1)),
  ));

  // Mehmet son 7 gün içinde: delivery 100 (net +100)
  await repo.addTransaction(DealerTransaction(
    id: 't-m1',
    dealerId: 'd-active-2',
    type: DealerTransactionType.delivery,
    amount: 100,
    createdAt: _refNow.subtract(const Duration(days: 3)),
  ));

  // Hamdi 20 gün önce (son 30'da ama son 7'de değil): return 50 (net -50)
  await repo.addTransaction(DealerTransaction(
    id: 't-h3-old',
    dealerId: 'd-active-1',
    type: DealerTransactionType.returned,
    amount: 50,
    createdAt: _refNow.subtract(const Duration(days: 20)),
  ));

  // Şenel pasif ama tx var (filtre'ye girmemeli)
  await repo.addTransaction(DealerTransaction(
    id: 't-passive',
    dealerId: 'd-passive',
    type: DealerTransactionType.delivery,
    amount: 999,
    createdAt: _refNow.subtract(const Duration(days: 1)),
  ));

  return repo;
}

GoRouter _testRouter() => GoRouter(
      initialLocation: '/dealers',
      routes: [
        GoRoute(
          path: '/dealers',
          builder: (_, __) => DealerReportsTabScreen(now: _refNow),
        ),
        GoRoute(
          path: '/dealers/:id/report',
          builder: (_, state) => Scaffold(
            body: Center(
              child: Text('range-report-stub:${state.pathParameters['id']}'),
            ),
          ),
        ),
      ],
    );

Widget _wrap(LocalDealerRepository repo) {
  return ProviderScope(
    overrides: [
      dealerRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: _testRouter()),
  );
}

void main() {
  group('DealerReportsTabScreen — segment + summary', () {
    testWidgets('3 periyot chip render edilir; default Son 30 gün',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.dealerReportsPeriodLast7), findsOneWidget);
      expect(find.text(AppStrings.dealerReportsPeriodLast30), findsOneWidget);
      expect(
        find.text(AppStrings.dealerReportsPeriodThisMonth),
        findsOneWidget,
      );

      // Genel Toplam başlığı (uppercase)
      expect(
        find.text(AppStrings.dealerReportsSummaryTitle.toUpperCase()),
        findsOneWidget,
      );
      // "2 aktif bayi" satırı (pasif Şenel hariç)
      expect(
        find.text('2 ${AppStrings.dealerReportsActiveDealersLabel}'),
        findsOneWidget,
      );
    });

    testWidgets('Default Son 30 gün → KPI labels + tx count 4',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // 5 KPI label (uppercase)
      expect(
        find.text(AppStrings.dealerReportsKpiDelivery.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerReportsKpiReturn.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerReportsKpiPayment.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerReportsKpiTxCount.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerReportsKpiNetChange.toUpperCase()),
        findsOneWidget,
      );

      // Son 30 gün → 4 aktif tx (Hamdi 500 + Hamdi -200 ödeme + Mehmet
      // 100 + Hamdi -50 iade); pasif Şenel'in tx'i hariç.
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('Son 7 gün segment tap → tx count 3 (eski iade hariç)',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.dealerReportsPeriodLast7));
      await tester.pumpAndSettle();

      // Son 7 gün'de Hamdi 500/200 + Mehmet 100 = 3 tx; 20 gün
      // önceki iade burada YOK.
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('DealerReportsTabScreen — Bayi Bazlı Rapor', () {
    testWidgets('Yalnız aktif bayiler listelenir (Şenel hariç)',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // "Bayi Bazlı Rapor" başlığı (uppercase)
      expect(
        find.text(AppStrings.dealerReportsByDealerTitle.toUpperCase()),
        findsOneWidget,
      );

      // Aktif bayiler listede
      expect(find.text('Hamdi Bakkal'), findsOneWidget);
      expect(find.text('Mehmet Market'), findsOneWidget);
      // Pasif bayi listede DEĞİL
      expect(find.text('Şenel Büfe'), findsNothing);
    });

    testWidgets('Bayi satır tap → /dealers/:id/report route push',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      final row = find.text('Hamdi Bakkal');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      // Stub range-report ekranına yönlendi
      expect(find.text('range-report-stub:d-active-1'), findsOneWidget);
    });
  });

  group('DealerReportsTabScreen — empty states', () {
    testWidgets('Hiç bayi yok → "aktif bayi yok" empty state',
        (tester) async {
      final repo = LocalDealerRepository(seed: false);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.dealerReportsNoActiveDealers),
        findsOneWidget,
      );
    });

    testWidgets('Aktif bayi var ama tx yok → "hareket yok" özet empty',
        (tester) async {
      final repo = LocalDealerRepository(seed: false);
      await repo.upsertDealer(Dealer(
        id: 'd-empty',
        name: 'Boş Bayi',
        createdAt: DateTime(2026, 1, 1),
      ));
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.dealerReportsEmpty), findsOneWidget);
      // Bayi listede yine de görünmeli
      expect(find.text('Boş Bayi'), findsOneWidget);
    });
  });
}
