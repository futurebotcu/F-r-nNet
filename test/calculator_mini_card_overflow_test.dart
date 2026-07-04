import 'package:firin_defter/features/bakery_panel/calculators/widgets/calculator_mini_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Premium hub: uzun başlıklar 2 kolonlu ızgaranın dar kartında (320dp
/// ekranda kart ~139dp) 2 satıra açılır, taşma yapmaz. Widget testinde
/// RenderFlex taşması hata fırlatır; test geçiyorsa taşma yok demektir.
void main() {
  const longTitles = <String>[
    'Dükkan Boşta Kaça Çalışıyor?',
    'Fırıncı Yüzdesi (Una Göre Reçete)',
    'Çuvaldan Kaç Ürün Çıkar?',
    'Fiyat Güncelleme Simülatörü',
    'Günlük Kapanış (Kâr / Zarar)',
  ];

  Future<void> pump320Grid(WidgetTester tester, String title) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              // Hub'daki gerçek ızgara ölçüleriyle aynı: 2 kolon + sabit
              // yükseklik. Kart bu kısıtta taşmadan render olmalı.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 142,
              ),
              itemCount: 2,
              itemBuilder: (_, __) => CalculatorMiniCard(
                title: title,
                subtitle:
                    'Uzun açıklama metni ile iki satırlık alt başlık örneği.',
                icon: Icons.calculate_outlined,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final title in longTitles) {
    testWidgets('320dp ızgarada uzun başlık taşmaz: $title', (tester) async {
      await pump320Grid(tester, title);
      expect(find.text(title), findsNWidgets(2));
      // Offline rozeti kartta yok (hub üstü tek notta); chevron pasif durur.
      expect(find.text('Offline'), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNWidgets(2));
    });
  }
}
