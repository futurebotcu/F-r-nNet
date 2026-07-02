import 'package:firin_defter/core/widgets/premium/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cila: StatCard hero değerinde büyük para değerleri kart genişliğini aşsa
/// bile kırpılmadan (FittedBox scaleDown) tek satır kalır ve taşma (RenderFlex
/// overflow) fırlatmaz. Widget testinde taşma exception atar; test geçiyorsa
/// taşma yok demektir.
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required String value,
    required bool hero,
    double width = 160,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: StatCard(
                icon: Icons.payments_outlined,
                label: 'Günlük toplam kâr',
                value: value,
                hero: hero,
                warm: hero,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hero büyük para değeri dar kartta taşmaz', (tester) async {
    await pumpCard(tester, value: '₺1.250.000,00', hero: true, width: 150);
    expect(find.text('₺1.250.000,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('çok büyük değer (milyon üstü) dar kartta taşmaz', (
    tester,
  ) async {
    await pumpCard(tester, value: '₺12.345.678,90', hero: true, width: 140);
    expect(find.text('₺12.345.678,90'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal küçük değer sorunsuz görünür', (tester) async {
    await pumpCard(tester, value: '316', hero: true, width: 200);
    expect(find.text('316'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-hero büyük değer de taşmaz', (tester) async {
    await pumpCard(tester, value: '₺9.876.543,21', hero: false, width: 130);
    expect(find.text('₺9.876.543,21'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
