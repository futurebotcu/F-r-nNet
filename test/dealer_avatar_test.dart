// Quality Patch v2 — DealerAvatar widget testleri.
//
// Bayi adının ilk harfini renkli kart/daire içinde gösteren paylaşılan
// widget. Palette + shape + size + fallbackChar parametreleri.

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/widgets/dealer_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Dealer _dealer({
  String id = 'd1',
  String name = 'Hamdi Bakkal',
  bool isActive = true,
}) {
  return Dealer(id: id, name: name, isActive: isActive, createdAt: DateTime(2026, 1, 1));
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('DealerAvatar — initial', () {
    testWidgets('Bayi adının ilk harfi uppercase render edilir',
        (tester) async {
      await tester.pumpWidget(_wrap(
        DealerAvatar(dealer: _dealer(name: 'mehmet')),
      ));
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('Boş ad → default fallback B', (tester) async {
      await tester.pumpWidget(_wrap(
        DealerAvatar(dealer: _dealer(name: '')),
      ));
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('Custom fallbackChar respekt edilir', (tester) async {
      await tester.pumpWidget(_wrap(
        DealerAvatar(dealer: _dealer(name: ''), fallbackChar: '?'),
      ));
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('DealerAvatar — palette renkleri', () {
    testWidgets('autoActivity + aktif → softGold tonu', (tester) async {
      await tester.pumpWidget(_wrap(
        DealerAvatar(
          dealer: _dealer(isActive: true),
          palette: DealerAvatarPalette.autoActivity,
        ),
      ));
      final text = tester.widget<Text>(find.text('H'));
      expect(text.style?.color, AppColors.softGold);
    });

    testWidgets('autoActivity + pasif → textMuted tonu', (tester) async {
      await tester.pumpWidget(_wrap(
        DealerAvatar(
          dealer: _dealer(isActive: false),
          palette: DealerAvatarPalette.autoActivity,
        ),
      ));
      final text = tester.widget<Text>(find.text('H'));
      expect(text.style?.color, AppColors.textMuted);
    });

    testWidgets('copper palette → okunur ink harf (pale lemon zemin)',
        (tester) async {
      // Faz 2 P2 — eskiden foreground=copper (lemon) idi → pale lemon zeminde
      // okunmuyordu. Artık ink harf (kontrast + lemon aksan çerçeve).
      await tester.pumpWidget(_wrap(
        DealerAvatar(
          dealer: _dealer(),
          palette: DealerAvatarPalette.copper,
        ),
      ));
      final text = tester.widget<Text>(find.text('H'));
      expect(text.style?.color, AppColors.brandInk);
    });
  });
}
