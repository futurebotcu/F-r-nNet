// FırınNet Market V1 M3 — polish invariant testleri.
//
// M3 = A + B + C polish + final smoke (Market V1 kapanışı):
//   A. Active filter chip district desteği — il + ilçe rozet olarak görünür.
//   B. Detail screen lokasyon vurgusu + controlled-data taxonomy attribute.
//   C. Empty state — filter aktif vs boş durum için farklı CTA + ipucu.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M3 — A: Active filter chip district desteği', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/marketplace/screens/marketplace_screen.dart')
          .readAsStringSync();
    });

    test('_ActiveFilterChipRow onRemoveDistrict callback tanımlı', () {
      expect(src.contains('onRemoveDistrict'), isTrue,
          reason: 'District chip için remove callback gerekli');
    });

    test('Wrap içinde district label chip render eden blok var', () {
      expect(src.contains("(filters.district ?? '').isNotEmpty"), isTrue);
      expect(
        src.contains('label: filters.district!'),
        isTrue,
        reason: 'District display label chip olarak render edilmeli',
      );
    });

    test('clearDistrict flag ile temizleme', () {
      expect(src.contains('clearDistrict: true'), isTrue);
    });
  });

  group('M3 — B: Detail lokasyon + controlled-data attribute', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/marketplace/screens/marketplace_detail_screen.dart',
      ).readAsStringSync();
    });

    test('InfoSection _LocationChip rozet kullanır', () {
      expect(src.contains('_LocationChip'), isTrue);
      expect(src.contains('Icons.place_outlined'), isTrue);
    });

    test('AttributesGrid taxonomy iletişim tercihi label\'ı ekler', () {
      expect(
        src.contains('MarketplaceTaxonomy.contactPreferenceLabel'),
        isTrue,
        reason: 'Detail attribute taxonomy üzerinden contact label vermeli',
      );
      expect(src.contains("MapEntry('İletişim'"), isTrue);
    });

    test('Currency default\'dan farklıysa attribute olarak gösterilir', () {
      expect(src.contains('MarketplaceTaxonomy.currencyLabel'), isTrue);
      expect(src.contains('MarketplaceTaxonomy.defaultCurrency'), isTrue,
          reason: 'TRY default ise gizli kalmalı');
      expect(src.contains('marketAttrCurrency'), isTrue);
    });
  });

  group('M3 — C: Empty state polish', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/marketplace/screens/marketplace_screen.dart')
          .readAsStringSync();
    });

    test('_MarketEmptyState widget tanımlı', () {
      expect(src.contains('class _MarketEmptyState'), isTrue);
    });

    test('Filter aktif: marketEmptyFilteredTitle + ClearFiltersCta', () {
      expect(src.contains('marketEmptyFilteredTitle'), isTrue);
      expect(src.contains('marketEmptyFilteredSubtitle'), isTrue);
      expect(src.contains('marketEmptyClearFiltersCta'), isTrue);
    });

    test('Boş liste: marketEmptyTitle + Add CTA', () {
      expect(src.contains('marketEmptyTitle'), isTrue);
      expect(src.contains('marketEmptySubtitle'), isTrue);
      expect(src.contains('marketEmptyCta'), isTrue);
    });

    test('filterActive branch _filters.activeCount > 0 koşulu', () {
      expect(src.contains('_filters.activeCount > 0'), isTrue,
          reason: 'Filter aktif vs boş ayırımı yapılmalı');
    });

    test('Boş liste CTA add handler\'ı bağlı (onAddPressed)', () {
      expect(src.contains('onAddPressed: _onAddPressed'), isTrue);
    });

    test('Filter clear CTA MarketFilters() ile reset eder', () {
      expect(src.contains('const MarketFilters()'), isTrue);
    });
  });

  group('M3 — AppStrings yeni sabitler', () {
    test('Empty state stringleri tanımlı + non-empty', () {
      expect(AppStrings.marketEmptyTitle, isNotEmpty);
      expect(AppStrings.marketEmptySubtitle, isNotEmpty);
      expect(AppStrings.marketEmptyCta, isNotEmpty);
      expect(AppStrings.marketEmptyFilteredTitle, isNotEmpty);
      expect(AppStrings.marketEmptyFilteredSubtitle, isNotEmpty);
      expect(AppStrings.marketEmptyClearFiltersCta, isNotEmpty);
    });
  });
}
