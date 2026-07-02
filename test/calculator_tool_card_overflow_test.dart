import 'package:firin_defter/features/bakery_panel/calculators/widgets/calculator_tool_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cila: uzun kart başlıkları küçük ekranda (320px) 2 satıra açılabilir,
/// overflow yapmamalı. Widget testinde RenderFlex taşması hata fırlatır;
/// test geçiyorsa taşma yok demektir.
void main() {
  const longTitles = <String>[
    'Dükkan Boşta Kaça Çalışıyor?',
    'Fırıncı Yüzdesi (Una Göre Reçete)',
    'Çuvaldan Kaç Ürün Çıkar?',
    'Fiyat Güncelleme Simülatörü',
  ];

  Future<void> pump320(WidgetTester tester, String title) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              CalculatorToolCard(
                title: title,
                subtitle:
                    'Uzun açıklama metni ile iki satırlık alt başlık örneği burada.',
                icon: Icons.calculate_outlined,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final title in longTitles) {
    testWidgets('320px uzun başlık taşmaz: $title', (tester) async {
      await pump320(tester, title);
      expect(find.text(title), findsOneWidget);
      // Offline rozeti ve chevron hâlâ görünür (düzen bozulmadı).
      expect(find.text('Offline'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
    });
  }
}
