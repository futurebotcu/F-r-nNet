// Şoför Daveti ekranı — FN-ID label/help (teknik UUID/profile/user id YOK).

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
  testWidgets('FırınNet ID label + örnek help görünür; teknik ifade yok',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // FN-ID label + örnek + Ayarlar yönlendirmesi.
    expect(find.text('FırınNet ID'), findsOneWidget);
    expect(find.text('Örn. FN-2026-000123'), findsOneWidget);
    expect(
      find.textContaining('Ayarlar ekranında görünen FırınNet ID'),
      findsOneWidget,
    );

    // Teknik ifadeler EKRANDA görünmemeli.
    final all = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ').toLowerCase();
    expect(all.contains('uuid'), isFalse);
    expect(all.contains('profile id'), isFalse);
    expect(all.contains('user id'), isFalse);
    expect(all.contains('kullanıcı id'), isFalse);
  });
}
