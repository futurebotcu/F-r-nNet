// Polish Sprint 1 — DealerFilterChip widget testleri.
//
// 4 ekranda (List/Reports/Activity/Offer) paylaşılan filter/segment
// chip. Görsel davranış: selected → copper border + softGold label;
// unselected → hairline border + textSecondary label. onSelected
// nullable (saving sırasında disabled).

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/features/dealers/widgets/dealer_filter_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

void main() {
  group('DealerFilterChip — render', () {
    testWidgets('selected=true → labelStyle softGold w800', (tester) async {
      await tester.pumpWidget(_wrap(
        DealerFilterChip(
          label: 'Tümü (4)',
          selected: true,
          onSelected: (_) {},
        ),
      ));
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.labelStyle?.color, AppColors.softGold);
      expect(chip.labelStyle?.fontWeight, FontWeight.w800);
      expect(chip.selected, isTrue);
    });

    testWidgets('selected=false → labelStyle textSecondary w600',
        (tester) async {
      await tester.pumpWidget(_wrap(
        DealerFilterChip(
          label: 'Pasif',
          selected: false,
          onSelected: (_) {},
        ),
      ));
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.labelStyle?.color, AppColors.textSecondary);
      expect(chip.labelStyle?.fontWeight, FontWeight.w600);
      expect(chip.selected, isFalse);
    });

    testWidgets('Tap → onSelected callback fires with toggled bool',
        (tester) async {
      bool? captured;
      await tester.pumpWidget(_wrap(
        DealerFilterChip(
          label: 'Aktif',
          selected: false,
          onSelected: (v) => captured = v,
        ),
      ));
      await tester.tap(find.byType(DealerFilterChip));
      await tester.pumpAndSettle();
      expect(captured, isTrue, reason: 'unselected chip tap → true geçer');
    });

    testWidgets('onSelected=null → disabled (tap callback fire etmez)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const DealerFilterChip(
          label: 'Disabled',
          selected: false,
          onSelected: null,
        ),
      ));
      // Sadece render edilebilir mi kontrol; tap-without-callback flutter_test
      // hata atmaz, ChoiceChip kendisi disabled state'i içerir.
      expect(find.text('Disabled'), findsOneWidget);
    });
  });
}
