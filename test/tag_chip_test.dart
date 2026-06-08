// Visual North Star Sprint 1A — TagChip widget testleri.
//
// Render: `#$label` text + pale lemon fill + pill border. `onTap`
// opsiyonel; `null` ise InkWell sarmaz.

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/core/widgets/tag_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('TagChip — render', () {
    testWidgets('Caller ham label → widget içeride "#" prefix ekler', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const TagChip(label: 'ekşimaya')));
      expect(find.text('#ekşimaya'), findsOneWidget);
      expect(find.text('ekşimaya'), findsNothing);
    });

    testWidgets('Label brandInk renkte render edilir', (tester) async {
      await tester.pumpWidget(_wrap(const TagChip(label: 'simit')));
      final txt = tester.widget<Text>(find.text('#simit'));
      expect(txt.style?.color, AppColors.brandInk);
      // AppTypography.labelLarge -> 12.5pt w700 letterSpacing 0.25
      expect(txt.style?.fontSize, 12);
      expect(txt.style?.fontWeight, FontWeight.w700);
      expect(txt.style?.letterSpacing, 0.2);
    });
  });

  group('TagChip — interaction', () {
    testWidgets('onTap null → InkWell sarmaz; sadece pill render', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const TagChip(label: 'taşfırın')));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('onTap verilirse InkWell + tap callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(TagChip(label: 'borek', onTap: () => taps++)),
      );
      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.text('#borek'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
