// Sprint 6B — DealerPickerSheet widget testleri.
//
// Modal bottom sheet: bayi search + filter (all/debtOnly) + tap →
// onSelect(Dealer). Borçlu filtresinde currentBalance > 0 garantili
// (Sprint 6C QuickPaymentSheet'in hasDebt önkoşulu).

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/widgets/dealer_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<LocalDealerRepository> _seededRepo() async {
  final repo = LocalDealerRepository(seed: false);
  // Üç bayi: ikisi borçlu, biri kapalı, biri pasif
  await repo.upsertDealer(Dealer(
    id: 'd-debt-1',
    name: 'Hamdi Bakkal',
    city: 'Konya',
    area: 'Selçuklu',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-debt-2',
    name: 'Mehmet Market',
    city: 'Konya',
    area: 'Meram',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-closed',
    name: 'Köşe Pide',
    city: 'Konya',
    area: 'Karatay',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd-passive',
    name: 'Şenel Büfe',
    isActive: false,
    createdAt: DateTime(2026, 1, 1),
  ));
  // d-debt-1 borçlu (₺500), d-debt-2 borçlu (₺300), d-closed kapalı (0)
  await repo.addTransaction(DealerTransaction(
    id: 't1',
    dealerId: 'd-debt-1',
    type: DealerTransactionType.delivery,
    amount: 500,
    createdAt: DateTime(2026, 5, 1),
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't2',
    dealerId: 'd-debt-2',
    type: DealerTransactionType.delivery,
    amount: 300,
    createdAt: DateTime(2026, 5, 1),
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't3-d',
    dealerId: 'd-closed',
    type: DealerTransactionType.delivery,
    amount: 100,
    createdAt: DateTime(2026, 5, 1),
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't3-p',
    dealerId: 'd-closed',
    type: DealerTransactionType.payment,
    amount: 100,
    createdAt: DateTime(2026, 5, 2),
  ));
  return repo;
}

Widget _wrap(LocalDealerRepository repo, {bool debtOnly = false}) {
  return ProviderScope(
    overrides: [
      dealerRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              child: const Text('open'),
              onPressed: () => DealerPickerSheet.show(
                context: context,
                debtOnly: debtOnly,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('DealerPickerSheet — rendering', () {
    testWidgets('açıldığında title + filter chip + search field görünür',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await _open(tester);

      expect(find.text(AppStrings.dealerPickerTitle), findsOneWidget);
      expect(find.text(AppStrings.dealerPickerFilterAll), findsOneWidget);
      expect(find.text(AppStrings.dealerPickerFilterDebtOnly), findsOneWidget);
      // Search hint text inside TextField
      expect(find.text(AppStrings.dealerPickerSearchHint), findsOneWidget);
    });
  });

  group('DealerPickerSheet — filter', () {
    testWidgets('default all → tüm aktif bayiler listede', (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await _open(tester);

      // Aktif 3 bayi (Hamdi, Mehmet, Köşe); pasif Şenel listede YOK
      expect(find.text('Hamdi Bakkal'), findsOneWidget);
      expect(find.text('Mehmet Market'), findsOneWidget);
      expect(find.text('Köşe Pide'), findsOneWidget);
      expect(find.text('Şenel Büfe'), findsNothing);
    });

    testWidgets('initialDebtOnly: true → yalnız borçlu bayiler',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo, debtOnly: true));
      await _open(tester);

      // Borçlu 2 bayi: Hamdi (₺500), Mehmet (₺300). Köşe kapalı (0).
      expect(find.text('Hamdi Bakkal'), findsOneWidget);
      expect(find.text('Mehmet Market'), findsOneWidget);
      expect(find.text('Köşe Pide'), findsNothing);
    });

    testWidgets('all → debt filter chip toggle → list filtrelenir',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await _open(tester);

      expect(find.text('Köşe Pide'), findsOneWidget); // initial all

      // SegmentedButton'da "Borçlu" chip'ine tıkla
      await tester.tap(find.text(AppStrings.dealerPickerFilterDebtOnly));
      await tester.pumpAndSettle();

      expect(find.text('Köşe Pide'), findsNothing); // kapalı, filtre dışı
      expect(find.text('Hamdi Bakkal'), findsOneWidget); // borçlu
    });
  });

  group('DealerPickerSheet — tap returns dealer', () {
    testWidgets('bayi satırına tap → showModalBottomSheet Future Dealer döner',
        (tester) async {
      final repo = await _seededRepo();

      // Sheet'i programatik aç + Future'ı yakala
      Dealer? returned;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dealerRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    child: const Text('open'),
                    onPressed: () async {
                      returned = await DealerPickerSheet.show(
                        context: context,
                        debtOnly: false,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _open(tester);

      // Hamdi'ye tap
      await tester.tap(find.text('Hamdi Bakkal'));
      await tester.pumpAndSettle();

      expect(returned, isNotNull);
      expect(returned!.id, 'd-debt-1');
    });
  });
}
