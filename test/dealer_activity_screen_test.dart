// Sprint Activity — DealerActivityScreen widget tests.
//
// Cross-dealer tx list: filter chip (Tümü/Teslimat/İade/Tahsilat/Düzeltme),
// bayi adı search, tarih grup (Bugün/Dün/Bu hafta/Daha eski), tap-row →
// dealer detail.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

GoRouter _testRouter() => GoRouter(
      initialLocation: '/dealers',
      routes: [
        GoRoute(
          path: '/dealers',
          builder: (_, __) => const DealerActivityScreen(),
        ),
        GoRoute(
          path: '/dealers/:id',
          builder: (_, state) => Scaffold(
            body: Center(
              child: Text('Detail of ${state.pathParameters['id']}'),
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

Future<LocalDealerRepository> _seededRepo({_Seed seed = _Seed.mixed}) async {
  final repo = LocalDealerRepository(seed: false);
  await repo.upsertDealer(Dealer(
    id: 'd1',
    name: 'Hamdi Bakkal',
    createdAt: DateTime(2026, 1, 1),
  ));
  await repo.upsertDealer(Dealer(
    id: 'd2',
    name: 'Mehmet Market',
    createdAt: DateTime(2026, 1, 1),
  ));
  if (seed == _Seed.empty) return repo;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  // 30 gün öncesi — bugün hangi gün olursa olsun "Daha eski" bucket'a düşer.
  final longAgo = today.subtract(const Duration(days: 30));

  // Bugün — Hamdi delivery + payment
  await repo.addTransaction(DealerTransaction(
    id: 't-today-d',
    dealerId: 'd1',
    type: DealerTransactionType.delivery,
    amount: 200,
    createdAt: today.add(const Duration(hours: 9)),
  ));
  await repo.addTransaction(DealerTransaction(
    id: 't-today-p',
    dealerId: 'd1',
    type: DealerTransactionType.payment,
    amount: 100,
    createdAt: today.add(const Duration(hours: 14)),
  ));
  // Dün — Mehmet returned
  await repo.addTransaction(DealerTransaction(
    id: 't-yest-r',
    dealerId: 'd2',
    type: DealerTransactionType.returned,
    amount: 50,
    createdAt: yesterday.add(const Duration(hours: 10)),
  ));
  // Daha eski — Hamdi adjustment
  await repo.addTransaction(DealerTransaction(
    id: 't-old-a',
    dealerId: 'd1',
    type: DealerTransactionType.adjustment,
    amount: 25,
    createdAt: longAgo.add(const Duration(hours: 9)),
  ));
  return repo;
}

enum _Seed { empty, mixed }

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  group('DealerActivityScreen — empty', () {
    testWidgets('hiç tx yok → "Henüz hareket yok" empty state',
        (tester) async {
      final repo = await _seededRepo(seed: _Seed.empty);
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.dealerActivityEmptyTitle),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerActivityEmptyBody),
        findsOneWidget,
      );
      // Search field empty state'te render edilmez
      expect(
        find.text(AppStrings.dealerActivitySearchHint),
        findsNothing,
      );
    });
  });

  group('DealerActivityScreen — render & groups', () {
    testWidgets('mixed tx → search + filter + 3 grup başlığı render edilir',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // AppBar title
      expect(find.text(AppStrings.dealerActivityTitle), findsAtLeastNWidgets(1));
      // Search hint
      expect(find.text(AppStrings.dealerActivitySearchHint), findsOneWidget);
      // 3 grup başlığı (Bu hafta boş olabilir bugün haftası başına bağlı)
      // En az "Bugün" + "Dün" + "Daha eski" görünür
      expect(
        find.text(AppStrings.dealerActivityGroupToday.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerActivityGroupYesterday.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerActivityGroupOlder.toUpperCase()),
        findsOneWidget,
      );
      // Bayi adları en az 1 yerde
      expect(find.text('Hamdi Bakkal'), findsAtLeastNWidgets(1));
      expect(find.text('Mehmet Market'), findsAtLeastNWidgets(1));
    });

    testWidgets('filter chip "Teslimat" tap → yalnız delivery satırı',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Tümü 4 tx; Teslimat 1
      await tester.tap(find.textContaining(
          '${AppStrings.dealerTxFilterTypeDelivery} (1)'));
      await tester.pumpAndSettle();

      // Hamdi (delivery sahibi) görünür; Mehmet (returned) GİTMELİ
      expect(find.text('Hamdi Bakkal'), findsAtLeastNWidgets(1));
      expect(find.text('Mehmet Market'), findsNothing);
    });

    testWidgets('filter chip "Tahsilat" → payment row görünür',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining(
          '${AppStrings.dealerTxFilterTypePayment} (1)'));
      await tester.pumpAndSettle();

      // Payment Hamdi'ye ait → Hamdi görünür
      expect(find.text('Hamdi Bakkal'), findsAtLeastNWidgets(1));
      // Mehmet (returned) görünmemeli
      expect(find.text('Mehmet Market'), findsNothing);
    });

    testWidgets('search "Mehmet" → yalnız Mehmet tx', (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Mehmet',
      );
      await tester.pumpAndSettle();

      expect(find.text('Mehmet Market'), findsAtLeastNWidgets(1));
      expect(find.text('Hamdi Bakkal'), findsNothing);
    });

    testWidgets('filter + search match yok → "Eşleşen hareket yok"',
        (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Mehmet aramada Tahsilat filtre — Mehmet'in payment'i YOK
      await tester.enterText(find.byType(TextField), 'Mehmet');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(
          '${AppStrings.dealerTxFilterTypePayment} (1)'));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.dealerActivityNoMatchTitle),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.dealerActivityNoMatchBody),
        findsOneWidget,
      );
    });
  });

  group('DealerActivityScreen — row tap navigation', () {
    testWidgets('satır tap → dealer detail route push', (tester) async {
      final repo = await _seededRepo();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Bugün Hamdi delivery satırı — ilk Hamdi tap
      await tester.tap(find.text('Hamdi Bakkal').first);
      await tester.pumpAndSettle();

      expect(find.text('Detail of d1'), findsOneWidget);
    });
  });
}
