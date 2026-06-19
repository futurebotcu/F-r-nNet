// Toptancı Müşteriler ekranında Şoförler yönetim girişi (UI placement).
//
// Toptancı da patron/owner: aynı şoför yönetimi (DriverListScreen) reuse edilir.
// Bu test yalnız "Şoförler girişi görünür + doğru route'a gider" doğrular.

import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/wholesale_customers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/wholesale/customers',
      routes: [
        GoRoute(
          path: '/wholesale/customers',
          builder: (_, __) => const WholesaleCustomersScreen(),
        ),
        GoRoute(
          path: '/dealers/drivers',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('Şoför Yönetimi — stub'))),
        ),
      ],
    );

Widget _wrap() => ProviderScope(
      overrides: [
        dealerRepositoryProvider
            .overrideWithValue(LocalDealerRepository(seed: true)),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    );

void main() {
  testWidgets('Toptancı Müşteriler ekranında Şoförler girişi görünür + push',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Şoförler app-bar action (tooltip) bulunur.
    final shoforler = find.byTooltip('Şoförler');
    expect(shoforler, findsOneWidget);

    await tester.tap(shoforler);
    await tester.pumpAndSettle();

    // DriverListScreen route'una (stub) gider — ayrı sistem değil, reuse.
    expect(find.text('Şoför Yönetimi — stub'), findsOneWidget);
  });
}
