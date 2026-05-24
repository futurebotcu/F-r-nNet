// Sprint 6C — QuickPaymentSheet widget testleri.
//
// Tam borç kapatma akışı: paid >= price → payment kaydı (amount = price,
// tendered değil). paid < price → kısmi tahsilat hint, kayıt yok.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/widgets/quick_payment_sheet.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _commercialProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

void main() {
  Future<LocalDealerRepository> seededRepo() async {
    final repo = LocalDealerRepository(seed: false);
    await repo.upsertDealer(Dealer(
      id: 'd1',
      name: 'Hamdi Bakkal',
      createdAt: DateTime(2026, 1, 1),
    ));
    return repo;
  }

  Widget wrap(LocalDealerRepository repo, double balance) {
    return ProviderScope(
      overrides: [
        dealerRepositoryProvider.overrideWithValue(repo),
        profileControllerProvider.overrideWith(
          (ref) => _SeededProfileController(ref, _commercialProfile),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                child: const Text('open'),
                onPressed: () => QuickPaymentSheet.show(
                  context: context,
                  dealerId: 'd1',
                  dealerName: 'Hamdi Bakkal',
                  currentBalance: balance,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('QuickPaymentSheet — rendering', () {
    testWidgets('açıldığında bayi adı + BORÇ pill görünür', (tester) async {
      final repo = await seededRepo();
      await tester.pumpWidget(wrap(repo, 500));
      await openSheet(tester);

      expect(find.text('Hamdi Bakkal'), findsOneWidget);
      expect(find.text(AppStrings.quickPaymentDebtLabel), findsOneWidget);
      expect(find.text(AppStrings.quickPaymentTitle), findsOneWidget);
      // Calculator widget keypad'i mount edilmiş
      expect(find.byKey(const Key('cashier.calculator.1')), findsOneWidget);
      expect(find.byKey(const Key('cashier.calculator.submit')),
          findsOneWidget);
    });
  });

  group('QuickPaymentSheet — tam borç kapatma', () {
    testWidgets('paid = price → payment kaydı (amount = price)',
        (tester) async {
      final repo = await seededRepo();
      await tester.pumpWidget(wrap(repo, 500));
      await openSheet(tester);

      // Default paid = price (initial state), direkt submit
      await tester.tap(find.byKey(const Key('cashier.calculator.submit')));
      await tester.pumpAndSettle();

      // Modal kapanır
      expect(find.text(AppStrings.quickPaymentTitle), findsNothing);
      // Transaction repo'ya yazıldı
      final txs = await repo.listTransactions('d1');
      expect(txs.length, 1);
      expect(txs.first.type, DealerTransactionType.payment);
      expect(txs.first.amount, 500.0); // price, tendered değil
      expect(txs.first.paymentMethod, DealerPaymentMethod.cash);
    });

    testWidgets(
        'paid > price → payment amount yine price; snackbar para üstü hatırlatır',
        (tester) async {
      final repo = await seededRepo();
      await tester.pumpWidget(wrap(repo, 500));
      await openSheet(tester);

      // "1000" type → paid = 1000, change = 500
      await tester.tap(find.byKey(const Key('cashier.calculator.1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('cashier.calculator.submit')));
      await tester.pumpAndSettle();

      // Modal kapanır
      expect(find.text(AppStrings.quickPaymentTitle), findsNothing);
      // Transaction: amount = price (500), tendered DEĞİL
      final txs = await repo.listTransactions('d1');
      expect(txs.length, 1);
      expect(txs.first.amount, 500.0);
      // Snackbar para üstü mesajı içerir
      expect(
        find.textContaining(AppStrings.quickPaymentChangeReturn),
        findsOneWidget,
      );
    });
  });

  group('QuickPaymentSheet — kısmi tahsilat reddi', () {
    testWidgets(
        'paid < price → snackbar hint, modal AÇIK kalır, kayıt YAZILMAZ',
        (tester) async {
      final repo = await seededRepo();
      await tester.pumpWidget(wrap(repo, 500));
      await openSheet(tester);

      // Default paid = price (500). Önce clear, sonra "100" type → paid = 100 < 500
      await tester.tap(find.byKey(const Key('cashier.calculator.clear')));
      await tester.pump();
      // Clear sonrası paid notifier'ı price'a düşer (500). Operator kullanma
      // alternatif: explicit "100" type.
      await tester.tap(find.byKey(const Key('cashier.calculator.1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cashier.calculator.0')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('cashier.calculator.submit')));
      await tester.pump();

      // Modal hâlâ açık (başlık görünür)
      expect(find.text(AppStrings.quickPaymentTitle), findsOneWidget);
      // Snackbar partial hint mesajı içerir
      expect(find.text(AppStrings.quickPaymentPartialHint), findsOneWidget);
      // Hiçbir kayıt yazılmadı
      final txs = await repo.listTransactions('d1');
      expect(txs.length, 0);
    });
  });
}
