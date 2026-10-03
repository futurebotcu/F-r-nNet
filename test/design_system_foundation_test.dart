// Tasarım sistemi temeli regresyonları: ortak geri bildirim (snackbar),
// segment seçili metin kontrastı, başlıkta otomatik geri, tema bileşenleri,
// Türkçe büyük harf.

import 'package:firin_defter/app/theme/app_colors.dart';
import 'package:firin_defter/app/theme/app_theme.dart';
import 'package:firin_defter/core/utils/tr_case.dart';
import 'package:firin_defter/core/widgets/app_feedback.dart';
import 'package:firin_defter/core/widgets/app_primary_button.dart';
import 'package:firin_defter/core/widgets/premium/firinnet_header.dart';
import 'package:firin_defter/core/widgets/segment_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) =>
    MaterialApp(theme: AppTheme.lightTheme(), home: home);

void main() {
  test('tema: snackbar koyu zemin, dialog/sheet/progress tanımlı', () {
    final t = AppTheme.lightTheme();
    expect(t.snackBarTheme.backgroundColor, AppColors.brandInk);
    expect(t.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(t.dialogTheme.shape, isNotNull);
    expect(t.bottomSheetTheme.backgroundColor, AppColors.surface);
    expect(t.progressIndicatorTheme.color, AppColors.brandInk);
    expect(t.textSelectionTheme.cursorColor, AppColors.brandInk);
  });

  testWidgets('AppFeedback success/error ikon + metin gösterir', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    AppFeedback.success(ctx, 'İlan yayınlandı');
    await tester.pump();
    expect(find.text('İlan yayınlandı'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    AppFeedback.error(ctx, 'Kaydedilemedi. Tekrar dene.');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    expect(
      find.text('İlan yayınlandı'),
      findsNothing,
      reason: 'önceki kapanır',
    );
  });

  testWidgets(
    'SegmentTabBar seçili metin mürekkep (sarı üstünde beyaz değil)',
    (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SegmentTabBar(
              labels: const ['Eleman', 'İş yeri'],
              index: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final selected = tester.widget<Text>(find.text('Eleman'));
      expect(selected.style?.color, AppColors.brandInk);
    },
  );

  testWidgets('FirinNetHeader: push edilen sayfada geri, kökte logo', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: FirinNetHeader(title: 'Kök')),
      ),
    );
    expect(find.byKey(const ValueKey('firinnet_header_back')), findsNothing);
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: FirinNetHeader(title: 'Akademi')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('firinnet_header_back')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('firinnet_header_back')));
    await tester.pumpAndSettle();
    expect(find.text('Kök'), findsOneWidget);
  });

  testWidgets('AppPrimaryButton cümle düzeni (KAYDET değil)', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: AppPrimaryButton(label: 'Giriş yap', onPressed: () {}),
        ),
      ),
    );
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.text('GIRIŞ YAP'), findsNothing);
  });

  test('Türkçe büyük harf', () {
    expect('giriş'.trUpper, 'GİRİŞ');
    expect('ılık'.trUpper, 'ILIK');
  });
}
