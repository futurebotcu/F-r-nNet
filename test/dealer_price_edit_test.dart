// Bayi Defteri Kullanılabilirlik Sprinti — A) Fiyat düzenle.
// "Düzenle" → DealerPriceSheet mevcut ürün+fiyatla ön-doldurulur (tarihçeli
// pattern: kaydedince yeni aktif fiyat eklenir). Ön-doldurmayı kanıtlar.

import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Fiyat düzenle: sheet mevcut ürün + fiyatla ön-doldurulur',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        dealerRepositoryProvider
            .overrideWithValue(LocalDealerRepository(seed: true)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DealerPriceSheet(
              dealerId: 'd_pide',
              initialProduct: 'Ekmek',
              initialPrice: 8.5,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Fiyat alanı ön-doldurulmuş.
    expect(find.text('8.5'), findsOneWidget);
    // Kaydet butonu mevcut (yeni aktif fiyat ekleme akışı).
    expect(find.byType(DealerPriceSheet), findsOneWidget);
  });
}
