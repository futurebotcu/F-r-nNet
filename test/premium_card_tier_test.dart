// Visual North Star Sprint 1A — PremiumCard.tier enum + backward compat.
//
// 3 tier görsel davranışı + warm=true → hero shortcut + default standard
// regresyon.

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/app/theme/app_tokens.dart';
import 'package:firin_defter/core/widgets/premium/premium_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

/// PremiumCard'ın iç Container'ının BoxDecoration'ını ele alır.
BoxDecoration _decorationOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(PremiumCard),
          matching: find.byType(Container),
        )
        .first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('PremiumCard — default standard tier', () {
    testWidgets(
      'Default tier=standard → card bg + hairline border + card shadow',
      (tester) async {
        await tester.pumpWidget(_wrap(const PremiumCard(child: Text('x'))));
        final deco = _decorationOf(tester);
        expect(deco.color, AppColors.card);
        expect(deco.border, isNotNull);
        expect(deco.boxShadow, AppShadow.card);
        // Default radius l (20)
        final radius = (deco.borderRadius as BorderRadius?)?.topLeft.x;
        expect(radius, AppRadius.l);
      },
    );
  });

  group('PremiumCard — tier=hero', () {
    testWidgets('tier=hero → elevatedCard bg + soft shadow + radius xl (28)', (
      tester,
    ) async {
      // Premium card trio sprint — hero tier shadow heroGlow (mat
      // espresso) yerine AppShadow.soft (warm bakır halo) kullanır;
      // FırınNet referansındaki sıcak premium kart hissi için.
      await tester.pumpWidget(
        _wrap(const PremiumCard(tier: CardTier.hero, child: Text('x'))),
      );
      final deco = _decorationOf(tester);
      expect(deco.color, AppColors.elevatedCard);
      expect(deco.boxShadow, AppShadow.soft);
      final radius = (deco.borderRadius as BorderRadius?)?.topLeft.x;
      expect(radius, AppRadius.xl);
    });

    testWidgets(
      'warm=true backward compat → tier=hero ile birebir aynı görsel',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const PremiumCard(warm: true, child: Text('x'))),
        );
        final deco = _decorationOf(tester);
        expect(deco.color, AppColors.elevatedCard);
        expect(deco.boxShadow, AppShadow.soft);
      },
    );
  });

  group('PremiumCard — tier=compact', () {
    testWidgets(
      'tier=compact → card bg + border YOK + shadow YOK + radius m (16)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const PremiumCard(tier: CardTier.compact, child: Text('x'))),
        );
        final deco = _decorationOf(tester);
        expect(deco.color, AppColors.card);
        expect(deco.border, isNull, reason: 'compact tier border taşımaz');
        expect(deco.boxShadow, isNull, reason: 'compact tier shadow taşımaz');
        final radius = (deco.borderRadius as BorderRadius?)?.topLeft.x;
        expect(radius, AppRadius.m);
      },
    );
  });

  group('PremiumCard — opsiyonel radius override', () {
    testWidgets('radius parametresi tier default\'unu override eder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PremiumCard(
            tier: CardTier.hero,
            radius: AppRadius.s,
            child: Text('x'),
          ),
        ),
      );
      final deco = _decorationOf(tester);
      final radius = (deco.borderRadius as BorderRadius?)?.topLeft.x;
      expect(radius, AppRadius.s, reason: 'override hero default\'unu ezdi');
    });
  });
}
