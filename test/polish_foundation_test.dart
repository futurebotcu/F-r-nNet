// Polish turu temel bileşenleri: FirinNetAvatar, AppNetworkImage /
// AppImageState, showAppConfirmDialog.

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/app/theme/app_theme.dart';
import 'package:firin_defter/core/widgets/app_confirm_dialog.dart';
import 'package:firin_defter/core/widgets/app_network_image.dart';
import 'package:firin_defter/core/widgets/firinnet_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('FirinNetAvatar', () {
    test('baş harfler (Türkçe büyük harf, en çok 2)', () {
      expect(FirinNetAvatar.initialsOf('ismail kaya'), 'İK');
      expect(FirinNetAvatar.initialsOf('  ırmak  '), 'I');
      expect(FirinNetAvatar.initialsOf('Ayşe Nur Kaya'), 'AN');
      expect(FirinNetAvatar.initialsOf(''), '?');
      expect(FirinNetAvatar.initialsOf(null), '?');
      expect(FirinNetAvatar.initialsOf('— Örnek'), 'Ö');
    });

    test('yalnız http(s) URL kullanılabilir', () {
      expect(FirinNetAvatar.isUsableUrl('https://x.co/a.png'), isTrue);
      expect(FirinNetAvatar.isUsableUrl('not a url'), isFalse);
      expect(FirinNetAvatar.isUsableUrl('file:///a.png'), isFalse);
      expect(FirinNetAvatar.isUsableUrl(''), isFalse);
      expect(FirinNetAvatar.isUsableUrl(null), isFalse);
    });

    testWidgets('bozuk URL → baş harf (kırık resim yok)', (tester) async {
      await tester.pumpWidget(
        _app(const FirinNetAvatar(name: 'Hasan Kara', imageUrl: '::bozuk')),
      );
      expect(find.text('HK'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });

    testWidgets('Akademi botu marka avatarı', (tester) async {
      await tester.pumpWidget(
        _app(
          const FirinNetAvatar(
            name: 'FırınNet Hijyen',
            kind: FirinNetAvatarKind.academy,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('avatar_academy')), findsOneWidget);
      expect(find.text('FH'), findsNothing);
    });

    testWidgets('isimsiz işletme → mağaza ikonu', (tester) async {
      await tester.pumpWidget(
        _app(const FirinNetAvatar(kind: FirinNetAvatarKind.business)),
      );
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    });

    testWidgets('1.5x yazı ölçeğinde baş harf taşmaz', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: _app(
            const FirinNetAvatar(
              name: 'Şükrü Çağlar',
              size: FirinNetAvatarSize.xs,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('ŞÇ'), findsOneWidget);
    });
  });

  group('AppNetworkImage', () {
    testWidgets('URL yok → "görsel yok" durumu + etiket', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            height: 120,
            child: AppNetworkImage(url: null, emptyLabel: 'Fotoğraf yok'),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('app_image_empty')), findsOneWidget);
      expect(find.text('Fotoğraf yok'), findsOneWidget);
    });

    testWidgets('hata durumu kırık ikon değil, sakin etiket', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 200,
            height: 120,
            child: AppImageState.error(label: 'Görsel yüklenemedi'),
          ),
        ),
      );
      expect(find.text('Görsel yüklenemedi'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.byIcon(Icons.broken_image), findsNothing);
    });

    testWidgets('küçük küçük-resimde etiket gizli, taşma yok', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 40,
            height: 40,
            child: AppNetworkImage(
              url: null,
              emptyLabel: 'Fotoğraf yok',
              compact: true,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Fotoğraf yok'), findsNothing);
    });
  });

  group('showAppConfirmDialog', () {
    Future<bool?> open(WidgetTester tester, {bool destructive = false}) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  ctx,
                  title: 'İlan silinsin mi?',
                  message: 'Bu işlem geri alınamaz.',
                  confirmLabel: 'Sil',
                  destructive: destructive,
                );
              },
              child: const Text('aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Vazgeç → false; eylem adlı CTA → true', (tester) async {
      await open(tester, destructive: true);
      expect(find.text('İlan silinsin mi?'), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);
      expect(find.text('Tamam'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('app_confirm_cancel')));
      await tester.pumpAndSettle();
      expect(find.text('İlan silinsin mi?'), findsNothing);
    });

    testWidgets('yıkıcı CTA kırmızı zemin + beyaz metin', (tester) async {
      await open(tester, destructive: true);
      final btn = tester.widget<FilledButton>(
        find.byKey(const ValueKey('app_confirm_ok')),
      );
      final bg = btn.style!.backgroundColor!.resolve(<WidgetState>{});
      final fg = btn.style!.foregroundColor!.resolve(<WidgetState>{});
      expect(bg, AppColors.danger);
      expect(fg, Colors.white);
    });

    testWidgets('dönüş değeri', (tester) async {
      late bool r;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                r = await showAppConfirmDialog(
                  ctx,
                  title: 'Çıkış yapılsın mı?',
                  confirmLabel: 'Çıkış yap',
                );
              },
              child: const Text('aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app_confirm_ok')));
      await tester.pumpAndSettle();
      expect(r, isTrue);
    });
  });
}
