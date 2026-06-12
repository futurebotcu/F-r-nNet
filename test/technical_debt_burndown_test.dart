// FırınNet Technical Debt Burn-down — tick-split (content vs structural),
// dar yorum-sayacı override'ı, repo dispose lifecycle ve release config
// sözleşmeleri.
//
// Dayanıklı kaynak-sözleşmesi + saf birim davranışı (kırılgan UI selector'ı
// yerine). Birisi içerik tick'ini yapısala geri bağlarsa, dispose'u kaldırırsa
// ya da release minify config'ini geri alırsa test kırılır.

import 'dart:io';

import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Tick-split — içerik vs yapısal (storm önleme)', () {
    test('Dealer repo ayrı içerik controller + notify + watchContent', () {
      final src = _read(
        'lib/features/dealers/repositories/supabase_dealer_repository.dart',
      );
      expect(src.contains('_contentChanges'), isTrue);
      expect(src.contains('void _notifyContent()'), isTrue);
      expect(
        src.contains('Stream<void> watchContent() => _contentChanges.stream'),
        isTrue,
      );
      // Hareket/fiyat/not İÇERİK tick'i çağırır (yapısal _notify değil).
      expect(src.contains('_notifyContent();'), isTrue);
    });

    test('Dealer providers: içerik provider\'ları içerik tick\'ini izler', () {
      final src =
          _read('lib/features/dealers/providers/dealer_providers.dart');
      expect(src.contains('dealerContentChangesProvider'), isTrue);
      // Bakiye = f(transactions) → içerik tick'i.
      final balStart = src.indexOf('final balanceSummaryProvider');
      final balBlock = src.substring(balStart, balStart + 400);
      expect(balBlock.contains('dealerContentChangesProvider'), isTrue);
      // Yapısal liste içerik tick'ini İZLEMEZ (hareket eklenince liste
      // recompute olmamalı).
      final listStart = src.indexOf('final dealersListProvider');
      final listBlock = src.substring(listStart, listStart + 260);
      expect(listBlock.contains('dealerContentChangesProvider'), isFalse,
          reason: 'Bayi listesi hareket tick\'inde recompute olmamalı');
      expect(listBlock.contains('dealerChangesProvider'), isTrue);
    });

    test('Feed repo: like/save/yorum içerik tick\'i, post create yapısal', () {
      final src = _read(
        'lib/features/feed/repositories/supabase_feed_repository.dart',
      );
      expect(src.contains('_contentChanges'), isTrue);
      expect(
        src.contains('Stream<void> watchContent() => _contentChanges.stream'),
        isTrue,
      );
      expect(src.contains('_notifyContent();'), isTrue);
    });

    test('Feed paged notifier yapısal tick\'i izler (like\'ta refetch yok)',
        () {
      final src = _read('lib/features/feed/providers/feed_providers.dart');
      expect(src.contains('feedContentChangesProvider'), isTrue);
      // Paged feed build() yalnız yapısal tick izler.
      final pagedStart = src.indexOf('class FeedPagedNotifier');
      final buildStart = src.indexOf('Future<FeedPagedState> build()', pagedStart);
      final buildBlock = src.substring(buildStart, buildStart + 260);
      expect(buildBlock.contains('feedChangesProvider'), isTrue);
      expect(buildBlock.contains('feedContentChangesProvider'), isFalse,
          reason: 'Beğeni/yorum paged feed\'i yeniden çekmemeli');
    });
  });

  group('Dar yorum-sayacı override\'ı', () {
    test('FeedCommentCountOverride increment + resolve mantığı (birim)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier =
          container.read(feedCommentCountOverrideProvider.notifier);

      // Başlangıçta override yok → model sayısı döner.
      expect(notifier.resolve('p1', 3), 3);

      // Yorum eklendi (basis=3) → 4.
      notifier.increment('p1', 3);
      expect(notifier.resolve('p1', 3), 4);

      // İkinci yorum → 5.
      notifier.increment('p1', 3);
      expect(notifier.resolve('p1', 3), 5);

      // Feed gerçek sayıyla tazelenince (model=5) override no-op (max).
      expect(notifier.resolve('p1', 5), 5);
      // Model override'ı geçtiyse model kazanır (çift sayım yok).
      expect(notifier.resolve('p1', 9), 9);

      // Başka post etkilenmez.
      expect(notifier.resolve('p2', 7), 7);
    });

    test('Kart override\'ı izler (kaynak sözleşmesi)', () {
      final src =
          _read('lib/features/social/post/social_post_card.dart');
      expect(src.contains('feedCommentCountOverrideProvider'), isTrue);
      expect(src.contains('_displayCommentCount'), isTrue);
      // Özet satırı model yerine override\'lı sayacı kullanır.
      expect(src.contains('commentCount: _displayCommentCount'), isTrue);
    });

    test('Yorum gönderiminde override artırılır (kaynak sözleşmesi)', () {
      final src =
          _read('lib/features/social/comments/comments_page.dart');
      expect(
        src.contains('feedCommentCountOverrideProvider.notifier'),
        isTrue,
      );
      expect(src.contains('.increment('), isTrue);
    });
  });

  group('Repo dispose lifecycle (rebuild leak önleme)', () {
    final reposWithDispose = <String>[
      'lib/features/dealers/repositories/supabase_dealer_repository.dart',
      'lib/features/feed/repositories/supabase_feed_repository.dart',
      'lib/features/social_groups/repositories/supabase_social_group_repository.dart',
    ];
    for (final path in reposWithDispose) {
      test('$path dispose() controller\'ları kapatır', () {
        final src = _read(path);
        expect(src.contains('void dispose()'), isTrue);
        expect(src.contains('.close()'), isTrue);
      });
    }

    final providersWithOnDispose = <String>[
      'lib/features/dealers/providers/dealer_providers.dart',
      'lib/features/feed/providers/feed_providers.dart',
      'lib/features/social_groups/providers/social_group_providers.dart',
    ];
    for (final path in providersWithOnDispose) {
      test('$path repo provider ref.onDispose ile kapatır', () {
        final src = _read(path);
        expect(src.contains('ref.onDispose(repo.dispose)'), isTrue);
      });
    }
  });

  group('Release minify/tree-shake config', () {
    test('build.gradle.kts release minify + shrink + proguard içerir', () {
      final src = _read('android/app/build.gradle.kts');
      expect(src.contains('isMinifyEnabled = true'), isTrue);
      expect(src.contains('isShrinkResources = true'), isTrue);
      expect(src.contains('proguard-rules.pro'), isTrue);
    });

    test('proguard-rules.pro Flutter + Supabase keep içerir', () {
      final src = _read('android/app/proguard-rules.pro');
      expect(src.contains('io.flutter'), isTrue);
      expect(src.contains('com.supabase'), isTrue);
    });
  });
}
