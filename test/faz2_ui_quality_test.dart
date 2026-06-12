// FırınNet Faz 2 — Premium UI/UX Quality sözleşme/davranış testleri.
//
// Ortak ErrorRetryState component'i, çift-etiket çözümü (feed "Tümü"),
// premium boş-state ve çıplak hata metinlerinin temizliği.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/error_retry_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('Çift-etiket çözümü (Topluluk vs feed filtresi)', () {
    test('feed iç filtresi "Tümü" (Topluluk segmenti "Genel Akış" ile çakışmaz)',
        () {
      expect(AppStrings.feedSegmentAll, 'Tümü');
      expect(AppStrings.communitySegFeed, 'Genel Akış');
      // İki etiket artık farklı → çift-etiket karmaşası yok.
      expect(AppStrings.feedSegmentAll == AppStrings.communitySegFeed, isFalse);
    });
  });

  group('Ortak ErrorRetryState component', () {
    testWidgets('başlık + alt metin render eder, retry opsiyonel', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: ErrorRetryState()),
      ));
      await t.pump();
      expect(find.text(AppStrings.errorGenericTitle), findsOneWidget);
      expect(find.text(AppStrings.errorGenericSubtitle), findsOneWidget);
      // onRetry yokken buton yok.
      expect(find.text(AppStrings.retry), findsNothing);
    });

    testWidgets('onRetry verilince "Yeniden dene" butonu görünür + çalışır',
        (t) async {
      var tapped = false;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ErrorRetryState(onRetry: () => tapped = true),
        ),
      ));
      await t.pump();
      expect(find.text(AppStrings.retry), findsOneWidget);
      await t.tap(find.text(AppStrings.retry));
      expect(tapped, isTrue);
    });
  });

  group('Çıplak hata metni temizliği (ham exception sızmaz)', () {
    final screens = <String>[
      'lib/features/bakery_panel/screens/report_screen.dart',
      'lib/features/bakery_panel/screens/end_of_day_screen.dart',
      'lib/features/dealers/screens/dealer_share_screen.dart',
      'lib/features/dealers/screens/wholesale_customers_screen.dart',
      'lib/features/dealers/screens/dealer_range_report_screen.dart',
    ];
    for (final s in screens) {
      test('$s ErrorRetryState kullanır, "Hata: \$e" yok', () {
        final src = _read(s);
        expect(src.contains('ErrorRetryState'), isTrue);
        expect(src.contains("Text('Hata: \$e')"), isFalse,
            reason: 'Ham exception kullanıcıya gösterilmemeli');
      });
    }

    test('dealer_detail inline hatalar ham exception sızdırmaz', () {
      final src =
          _read('lib/features/dealers/screens/dealer_detail_screen.dart');
      expect(src.contains("Text('Bakiye: \$e')"), isFalse);
      expect(src.contains("Text('İşlem: \$e')"), isFalse);
      expect(src.contains('_SectionError'), isTrue);
    });
  });

  group('Premium boş-state', () {
    test('feed boş-state EmptyState + yeni başlık/alt metin', () {
      final src = _read('lib/features/social/feed/social_feed_page.dart');
      // _FeedEmpty artık premium EmptyState kullanır.
      final i = src.indexOf('class _FeedEmpty');
      final block = src.substring(i, i + 400);
      expect(block.contains('EmptyState('), isTrue);
      expect(AppStrings.feedEmptyTitle.isNotEmpty, isTrue);
      expect(AppStrings.feedEmptySubtitle.isNotEmpty, isTrue);
    });
  });
}
