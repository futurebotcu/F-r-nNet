// Bayi Defteri Kullanılabilirlik Sprinti — Tüm İşlem Geçmişi ekranı (B/C/D).
// Tüm kayıtlar görünür, tip/arama filtresi çalışır, satır → detay sheet,
// patron işlemi siler.

import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/driver_scoped_dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_transaction_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<LocalDealerRepository> _seed() async {
  final repo = LocalDealerRepository(seed: true);
  // Sadece bu testin görünür kayıtlarını d_pide'ye yaz (seed'de tx'i yok),
  // böylece assertion'lar deterministik.
  await repo.addTransaction(DealerTransaction(
    id: 'h_del',
    dealerId: 'd_pide',
    type: DealerTransactionType.delivery,
    productName: 'Francala',
    quantity: 10,
    unitPrice: 40,
    amount: 400,
    createdAt: DateTime.now(),
  ));
  await repo.addTransaction(DealerTransaction(
    id: 'h_pay',
    dealerId: 'd_pide',
    type: DealerTransactionType.payment,
    amount: 200,
    createdAt: DateTime.now(),
  ));
  return repo;
}

Widget _wrap(LocalDealerRepository repo) => ProviderScope(
      overrides: [dealerRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: DealerTransactionHistoryScreen(dealerId: 'd_pide'),
      ),
    );

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR', null));

  Future<void> pump(WidgetTester tester, LocalDealerRepository repo) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();
  }

  testWidgets('Tüm kayıtlar görünür + tip + arama filtresi', (tester) async {
    await pump(tester, await _seed());

    // İki kayıt da görünür.
    expect(find.textContaining('Francala'), findsOneWidget); // teslimat
    expect(find.text('Ödeme'), findsWidgets); // filtre chip + satır

    // Arama: "Francala" → yalnız teslimat satırı kalır (satır başlığı).
    await tester.enterText(find.byType(TextField), 'Francala');
    await tester.pumpAndSettle();
    expect(find.text('Teslimat · Francala'), findsOneWidget);
    // Ödeme filtre chip'i hâlâ ekranda (arama satırları daraltır).
    expect(find.text('Ödeme'), findsWidgets);
  });

  testWidgets('Satır → detay sheet alanları + sil aksiyonu', (tester) async {
    await pump(tester, await _seed());

    await tester.tap(find.textContaining('Francala'));
    await tester.pumpAndSettle();

    // Detay sheet alanları.
    expect(find.text('Ürün'), findsOneWidget);
    expect(find.text('Bakiye etkisi'), findsOneWidget);
    expect(find.text('İşlemi Sil / İptal Et'), findsOneWidget);
  });

  testWidgets('Patron işlem siler → kayıt listeden gider', (tester) async {
    final repo = await _seed();
    await pump(tester, repo);

    await tester.tap(find.textContaining('Francala'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşlemi Sil / İptal Et'));
    await tester.pumpAndSettle();
    // Onay dialogu → Sil.
    expect(find.text('İşlem silinsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    // Repo'dan gitti.
    final after = await repo.listTransactions('d_pide');
    expect(after.any((t) => t.id == 'h_del'), isFalse);
    // Ekranda Francala kalmadı.
    expect(find.textContaining('Francala'), findsNothing);
  });

  testWidgets('10 gün önceki "40 ekmek" Son 30 günde + aramada görünür',
      (tester) async {
    final repo = LocalDealerRepository(seed: true);
    await repo.addTransaction(DealerTransaction(
      id: 'h_old',
      dealerId: 'd_pide',
      type: DealerTransactionType.delivery,
      productName: 'Ekmek',
      quantity: 40,
      unitPrice: 10,
      amount: 400,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ));
    await pump(tester, repo);

    // Default (Tümü): 10 gün önceki kayıt görünür.
    expect(find.text('Teslimat · Ekmek'), findsOneWidget);

    // "Son 30 gün" dönem filtresi → hâlâ görünür (kayıp gibi görünmez).
    await tester.tap(find.text('Son 30 gün'));
    await tester.pumpAndSettle();
    expect(find.text('Teslimat · Ekmek'), findsOneWidget);

    // Arama "ekmek" → eski kayıt bulunur.
    await tester.enterText(find.byType(TextField), 'ekmek');
    await tester.pumpAndSettle();
    expect(find.text('Teslimat · Ekmek'), findsOneWidget);
  });

  testWidgets('Şoför silme denerse → "patron yetkisi gerekir" mesajı',
      (tester) async {
    final inner = LocalDealerRepository(seed: true, currentUserId: 'u1');
    await inner.addDriver(driverUserId: 'u1', name: 'Ali Şoför');
    final driverId = (await inner.listDrivers()).first.id;
    await inner.setDriverAssignments(driverId: driverId, dealerIds: ['d_pide']);
    await inner.addTransaction(DealerTransaction(
      id: 'h_del',
      dealerId: 'd_pide',
      type: DealerTransactionType.delivery,
      productName: 'Francala',
      quantity: 10,
      unitPrice: 40,
      amount: 400,
      createdAt: DateTime.now(),
    ));
    final scoped = DriverScopedDealerRepository(inner: inner);

    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [dealerRepositoryProvider.overrideWithValue(scoped)],
      child: const MaterialApp(
        home: DealerTransactionHistoryScreen(dealerId: 'd_pide'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Francala'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşlemi Sil / İptal Et'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Bu işlem için patron yetkisi gerekir.'), findsOneWidget);
    // Kayıt silinmedi.
    final after = await inner.listTransactions('d_pide');
    expect(after.any((t) => t.id == 'h_del'), isTrue);
  });
}
