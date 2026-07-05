import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/add_driver_screen.dart';
import 'package:firin_defter/features/dealers/screens/driver_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Şoför Ekleme guide entegrasyonu: alt işlem rehberi her girişte görünür,
/// hata mesajı rehberin önüne geçer, başarılı kayıtta üst success şeridi.
Widget _wrapHome(Widget home) => ProviderScope(
  overrides: [
    dealerRepositoryProvider.overrideWithValue(
      LocalDealerRepository(seed: true),
    ),
  ],
  child: MaterialApp(home: home),
);

/// AddDriverScreen'i Navigator ile aç/kapa test edebilmek için basit giriş
/// ekranı ("Şoför Ekle" butonlu launcher).
class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey('open_add_driver'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddDriverScreen()),
          ),
          child: const Text('Şoför Ekle Aç'),
        ),
      ),
    );
  }
}

Future<void> _pumpTall(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrapHome(home));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('şoför ekleme ekranında alt rehber görünür (başlık + adımlar)', (
    tester,
  ) async {
    await _pumpTall(tester, const AddDriverScreen());
    expect(find.text(AppStrings.driverAddGuideTitle), findsOneWidget);
    expect(find.text(AppStrings.driverAddGuideStep1Title), findsOneWidget);
    expect(find.text(AppStrings.driverAddGuideStep4Title), findsOneWidget);
  });

  testWidgets('rehber kapatılsa bile yeni girişte yeniden görünür', (
    tester,
  ) async {
    await _pumpTall(tester, const _Launcher());

    // 1. giriş: rehber görünür → kapat → kaybolur.
    await tester.tap(find.byKey(const ValueKey('open_add_driver')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.driverAddGuideTitle), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('guide_close_driver_add_guide')),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.driverAddGuideTitle), findsNothing);

    // Ekrandan çık, yeniden gir: rehber TEKRAR görünür (kalıcı gizleme yok).
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open_add_driver')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.driverAddGuideTitle), findsOneWidget);
  });

  testWidgets('başarılı kayıt: üstte success şeridi + ekran kapanır', (
    tester,
  ) async {
    await _pumpTall(tester, const _Launcher());
    await tester.tap(find.byKey(const ValueKey('open_add_driver')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'FırınNet ID'),
      'FN-2026-000123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Şoför Adı'),
      'Test Şoför',
    );
    await tester.tap(find.text('Davet Gönder'));
    await tester.pumpAndSettle();

    // Ekran kapandı (launcher görünür) + success banner overlay'de.
    expect(find.byKey(const ValueKey('open_add_driver')), findsOneWidget);
    expect(find.text(AppStrings.driverAddedBannerTitle), findsOneWidget);
    expect(find.text(AppStrings.driverAddedBannerBody), findsOneWidget);

    // Otomatik kapanma zamanlayıcısı test sonunda sarkmasın.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text(AppStrings.driverAddedBannerTitle), findsNothing);
  });

  testWidgets(
    'form hatası rehberin önüne geçer: rehber küçülür, hata görünür',
    (tester) async {
      await _pumpTall(tester, const AddDriverScreen());
      expect(find.text(AppStrings.driverAddGuideStep1Title), findsOneWidget);

      // Boş form ile gönder → validasyon hatası.
      await tester.tap(find.text('Davet Gönder'));
      await tester.pumpAndSettle();

      expect(
        find.text('Davet oluşturulamadı. FırınNet ID\'yi kontrol edin.'),
        findsOneWidget,
      );
      // Rehber başlık şeridi kalır ama adımlar geri plana çekilir.
      expect(find.text(AppStrings.driverAddGuideTitle), findsOneWidget);
      expect(find.text(AppStrings.driverAddGuideStep1Title), findsNothing);
    },
  );

  testWidgets('ilgisiz ekranda (Şoförler listesi) şoför rehberi görünmez', (
    tester,
  ) async {
    await _pumpTall(tester, const DriverListScreen());
    expect(find.text(AppStrings.driverAddGuideTitle), findsNothing);
    expect(find.text(AppStrings.driverAddGuideStep1Title), findsNothing);
  });
}
