import 'package:firin_defter/core/widgets/guide/app_guide_surface.dart';
import 'package:firin_defter/core/widgets/guide/guide_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guide yüzeyi altyapı testleri: topBanner / bottomGuide render, küçültme,
/// kapatma, klavye davranışı, dar ekran ve büyük yazı ölçeği.
const _banner = GuideMessage(
  id: 'test_banner',
  title: 'Kısa bilgi başlığı',
  body: 'Kısa bilgi açıklaması.',
  placement: GuidePlacement.topBanner,
  variant: GuideVariant.success,
);

const _guide = GuideMessage(
  id: 'test_guide',
  title: 'İşlem rehberi başlığı',
  body: 'İşlemin ne yaptığını anlatan kısa açıklama.',
  placement: GuidePlacement.bottomGuide,
  variant: GuideVariant.tip,
  allowedRoles: {'commercial'},
  screenKey: 'test_screen',
  steps: [
    GuideStep(title: 'Adım bir', body: 'Birinci adımın açıklaması.'),
    GuideStep(title: 'Adım iki', body: 'İkinci adımın açıklaması.'),
    GuideStep(title: 'Adım üç', body: 'Üçüncü adımın açıklaması.'),
    GuideStep(title: 'Adım dört', body: 'Dördüncü adımın açıklaması.'),
  ],
);

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          const Expanded(child: SizedBox()),
          child,
        ],
      ),
    ),
  );
}

void main() {
  group('GuideMessage — model', () {
    test('allowedRoles null ise her rol görür', () {
      const open = GuideMessage(id: 'x', title: 't', body: 'b');
      expect(open.isVisibleToRole('commercial'), isTrue);
      expect(open.isVisibleToRole('individual'), isTrue);
      expect(open.isVisibleToRole(null), isTrue);
    });

    test('allowedRoles verildiyse yalnız o roller görür', () {
      expect(_guide.isVisibleToRole('commercial'), isTrue);
      expect(_guide.isVisibleToRole('individual'), isFalse);
      expect(_guide.isVisibleToRole('wholesaler'), isFalse);
      expect(_guide.isVisibleToRole(null), isFalse);
    });

    test('screenKey eşlemesi: rehber ilgisiz ekrana ait değildir', () {
      expect(_guide.matchesScreen('test_screen'), isTrue);
      expect(_guide.matchesScreen('another_screen'), isFalse);
      const global = GuideMessage(id: 'g', title: 't', body: 'b');
      expect(global.matchesScreen('anything'), isTrue);
    });

    test('showCondition false ise shouldShow false', () {
      final gated = GuideMessage(
        id: 'c',
        title: 't',
        body: 'b',
        showCondition: () => false,
      );
      expect(gated.shouldShow, isFalse);
      expect(_guide.shouldShow, isTrue);
    });
  });

  group('AppGuideSurface — topBanner', () {
    testWidgets('başlık + açıklama render olur, kapat çalışır', (tester) async {
      await tester.pumpWidget(_wrap(const AppGuideSurface(message: _banner)));
      expect(find.text('Kısa bilgi başlığı'), findsOneWidget);
      expect(find.text('Kısa bilgi açıklaması.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('guide_close_test_banner')));
      await tester.pumpAndSettle();
      expect(find.text('Kısa bilgi başlığı'), findsNothing);
    });
  });

  group('AppGuideSurface — bottomGuide', () {
    testWidgets('başlık, açıklama ve adımlar render olur', (tester) async {
      await tester.pumpWidget(_wrap(const AppGuideSurface(message: _guide)));
      expect(find.text('İşlem rehberi başlığı'), findsOneWidget);
      expect(find.text('Adım bir'), findsOneWidget);
      expect(find.text('Adım dört'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // adım numarası çipi
    });

    testWidgets('küçült/genişlet: adımlar gizlenir, başlık kalır', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const AppGuideSurface(message: _guide)));
      await tester.tap(find.byKey(const ValueKey('guide_collapse_test_guide')));
      await tester.pumpAndSettle();
      expect(find.text('İşlem rehberi başlığı'), findsOneWidget);
      expect(find.text('Adım bir'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('guide_collapse_test_guide')));
      await tester.pumpAndSettle();
      expect(find.text('Adım bir'), findsOneWidget);
    });

    testWidgets('kapat: yüzey tamamen kaybolur', (tester) async {
      await tester.pumpWidget(_wrap(const AppGuideSurface(message: _guide)));
      await tester.tap(find.byKey(const ValueKey('guide_close_test_guide')));
      await tester.pumpAndSettle();
      expect(find.text('İşlem rehberi başlığı'), findsNothing);
      expect(find.text('Adım bir'), findsNothing);
    });

    testWidgets('forceCollapsed: adımlar gizli, başlık şeridi görünür', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AppGuideSurface(message: _guide, forceCollapsed: true)),
      );
      expect(find.text('İşlem rehberi başlığı'), findsOneWidget);
      expect(find.text('Adım bir'), findsNothing);
    });

    testWidgets('klavye açıkken otomatik küçülür (form alanlarını ezmez)', (
      tester,
    ) async {
      // Gerçek klavye gibi: ham View inset'i (Scaffold body'de MediaQuery
      // viewInsets sıfırlandığı için widget View.of üzerinden okur).
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(_wrap(const AppGuideSurface(message: _guide)));
      expect(find.text('İşlem rehberi başlığı'), findsOneWidget);
      expect(find.text('Adım bir'), findsNothing);
    });

    testWidgets('320dp dar ekranda taşma yapmaz', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_wrap(const AppGuideSurface(message: _guide)));
      expect(find.text('İşlem rehberi başlığı'), findsOneWidget);
      expect(find.text('Adım bir'), findsOneWidget);
    });

    testWidgets('320dp + 1.3x yazı ölçeğinde taşma yapmaz', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(_wrap(const AppGuideSurface(message: _guide)));
      // İçerik yükseklik sınırlı + kaydırılabilir: taşma hatası fırlamaz.
      expect(find.text('İşlem rehberi başlığı'), findsOneWidget);
    });
  });
}
