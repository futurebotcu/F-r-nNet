// Quality Patch v2 — DealerKpiTile widget testleri.
//
// Genel Bakış + Raporlar (+ Gün Sonu V1 ileride) tarafından paylaşılan
// ortak KPI kart widget'ı. Render davranışı: uppercase label, accent
// renkli değer, emphasized warm card.

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/features/dealers/widgets/dealer_kpi_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  group('DealerKpiTile — render', () {
    testWidgets('label uppercase rendered', (tester) async {
      await tester.pumpWidget(_wrap(
        const DealerKpiTile(
          label: 'Açık Alacaklar',
          value: '₺1.000,00',
          accent: AppColors.copper,
        ),
      ));
      // Label `.toUpperCase()` ile render edilir.
      expect(find.text('AÇIK ALACAKLAR'), findsOneWidget);
      expect(find.text('Açık Alacaklar'), findsNothing);
    });

    testWidgets('value text accent rengiyle render edilir', (tester) async {
      await tester.pumpWidget(_wrap(
        const DealerKpiTile(
          label: 'NET DEĞIŞIM',
          value: '₺500,00',
          accent: AppColors.copper,
        ),
      ));
      final valueText =
          tester.widget<Text>(find.text('₺500,00'));
      expect(valueText.style?.color, AppColors.copper);
      expect(valueText.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('isCount=true → tabularFigures kapanır', (tester) async {
      await tester.pumpWidget(_wrap(
        const DealerKpiTile(
          label: 'İşlem',
          value: '10',
          accent: AppColors.textSecondary,
          isCount: true,
        ),
      ));
      final txt = tester.widget<Text>(find.text('10'));
      expect(txt.style?.fontFeatures, isNull);
    });

    testWidgets('isCount=false default → tabularFigures uygulanır',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const DealerKpiTile(
          label: 'Tutar',
          value: '₺123,45',
          accent: AppColors.success,
        ),
      ));
      final txt = tester.widget<Text>(find.text('₺123,45'));
      expect(txt.style?.fontFeatures, isNotNull);
      expect(txt.style?.fontFeatures, isNotEmpty);
    });
  });
}
