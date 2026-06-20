// feature/dealer-driver-permission-levels — AddDriverScreen yetki UI testi.
// Yarı/Tam segment görünür, varsayılan Yarı, bilgi popup doğru metinleri verir.

import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/add_driver_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap() => ProviderScope(
      overrides: [
        dealerRepositoryProvider
            .overrideWithValue(LocalDealerRepository(seed: true)),
      ],
      child: const MaterialApp(home: AddDriverScreen()),
    );

void main() {
  testWidgets('Segment görünür + varsayılan Yarı + bilgi popup', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Segment seçenekleri görünür.
    expect(find.text('Yarı Yetki'), findsWidgets);
    expect(find.text('Tam Yetki'), findsWidgets);

    // Varsayılan Yarı → inline açıklama yarı metni; tam metni henüz yok.
    expect(find.text(AddDriverScreen.halfPermissionInfo), findsOneWidget);
    expect(find.text(AddDriverScreen.fullPermissionInfo), findsNothing);

    // Bilgi ikonu → bottom sheet iki metni de gösterir.
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.text(AddDriverScreen.fullPermissionInfo), findsOneWidget);
    expect(find.text(AddDriverScreen.halfPermissionInfo), findsWidgets);
  });

  testWidgets('Tam Yetki seçilince inline açıklama tam metne döner',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tam Yetki'));
    await tester.pumpAndSettle();
    expect(find.text(AddDriverScreen.fullPermissionInfo), findsOneWidget);
  });
}
