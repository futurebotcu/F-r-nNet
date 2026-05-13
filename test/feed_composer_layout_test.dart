// Composer layout regresyon testi.
//
// Önceki sürümde _buildExpanded Row({Spacer(), SizedBox(height: 44, child:
// FilledButton.icon(...))}) kullanıyordu; SizedBox height-only olduğu için
// FilledButton'a parent'tan gelen genişlik kısıtı intrinsic-width fazında
// sonsuz olarak iletilebiliyor ve "BoxConstraints forces an infinite width"
// hatası atıyordu.
//
// Bu test composer'ı bounded ama gerçekçi bir telefon genişliğinde pump
// eder, expanded mode'a alır ve `tester.takeException()` ile layout
// exception'ı çıkmadığını doğrular.

import 'package:firin_defter/features/feed/repositories/feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/feed/widgets/feed_composer.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'FeedComposer expanded mode bounded width altında exception atmaz',
    (tester) async {
      final FeedRepository fakeRepo = LocalFeedRepository(seed: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 360, // Tipik dar telefon genişliği.
                  child: const FeedComposer(),
                ),
              ),
            ),
          ),
        ),
      );

      // İlk render — collapsed.
      expect(tester.takeException(), isNull);

      // Composer'ı expand et.
      await tester.tap(find.byType(FeedComposer));
      await tester.pumpAndSettle();

      // Expanded mode'da hata yok (asıl regresyon).
      expect(tester.takeException(), isNull);

      // Paylaş butonu ve metin alanı görünür.
      // FilledButton.icon factory wrapper kullandığı için byType(FilledButton)
      // sıfır verir; bunun yerine ikon + metin ile doğrula.
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    },
  );

  testWidgets(
    'FeedComposer geniş ekranda da exception atmaz',
    (tester) async {
      final FeedRepository fakeRepo = LocalFeedRepository(seed: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 1080, // Geniş ekran / tablet.
                  child: const FeedComposer(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FeedComposer));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
