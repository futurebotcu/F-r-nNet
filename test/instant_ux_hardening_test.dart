// FırınNet Whole-App Instant UX Hardening — mutation sonrası full-screen
// spinner flash önleme (skipLoadingOnReload), finansal formlarda çift-gönderim
// koruması ve medya decode boyutu sözleşmeleri.
//
// Bu testler kaynak-sözleşmesidir: kırılgan UI selector'ı yerine, performans
// regresyonunu yakalayan dayanıklı "kod içinde bu güvence var mı" kontrolü.
// (Birisi skipLoadingOnReload'u kaldırırsa veya bir forma çift-submit yolu
// açarsa test kırılır.)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Instant UX — mutation sonrası spinner flash yok (skipLoadingOnReload)',
      () {
    // Mutasyon sonrası kullanıcının gördüğü ekranlar: kayıt/hareket/ilan
    // sonrası liste/detay eski içeriği korumalı, full-screen spinner'a
    // düşmemeli. Spinner yalnız ilk yüklemede.
    final mutationVisibleScreens = <String>[
      'lib/features/dealers/screens/dealer_detail_screen.dart',
      'lib/features/dealers/screens/dealer_list_screen.dart',
      'lib/features/dealers/screens/dealer_overview_screen.dart',
      'lib/features/dealers/screens/dealer_activity_screen.dart',
      'lib/features/dealers/screens/dealer_end_of_day_tab_screen.dart',
      'lib/features/dealers/screens/dealer_reports_tab_screen.dart',
      'lib/features/dealers/screens/dealer_range_report_screen.dart',
      'lib/features/dealers/screens/wholesale_customers_screen.dart',
      'lib/features/bakery_panel/screens/recipes_list_screen.dart',
      'lib/features/bakery_panel/screens/recipe_detail_screen.dart',
      'lib/features/bakery_panel/screens/bakery_panel_screen.dart',
      'lib/features/marketplace/screens/marketplace_screen.dart',
      'lib/features/marketplace/screens/marketplace_detail_screen.dart',
      'lib/features/jobs/screens/jobs_screen.dart',
      'lib/features/social/feed/social_feed_page.dart',
      'lib/features/social/comments/comments_page.dart',
    ];

    for (final path in mutationVisibleScreens) {
      test('$path skipLoadingOnReload kullanır', () {
        final src = _read(path);
        expect(src.contains('skipLoadingOnReload: true'), isTrue,
            reason: '$path mutasyon sonrası reload\'da spinner flash atmamalı');
      });
    }

    test('dealer_detail tüm bölümlerde (bakiye/işlem/not) flash önlenir', () {
      final src = _read('lib/features/dealers/screens/dealer_detail_screen.dart');
      // 5 ayrı .when (dealer/balance/prices/tx/notes) hepsi korunmalı.
      final count = 'skipLoadingOnReload: true'.allMatches(src).length;
      expect(count, greaterThanOrEqualTo(5),
          reason: 'Hareket eklenince bakiye/işlem/not bölümleri ayrı ayrı '
              'flash atmamalı (5 when bloğu)');
    });
  });

  group('Instant UX — finansal/kayıt formlarında çift-gönderim koruması', () {
    // Hızlı çift tıklama mükerrer finansal hareket / mükerrer kayıt
    // oluşturmamalı: _saving guard + buton null'a düşmeli.
    final guardedForms = <String>[
      'lib/features/dealers/screens/dealer_delivery_form_screen.dart',
      'lib/features/dealers/screens/dealer_payment_form_screen.dart',
      'lib/features/dealers/screens/dealer_adjustment_form_screen.dart',
      'lib/features/dealers/screens/add_dealer_screen.dart',
    ];

    for (final path in guardedForms) {
      test('$path çift-submit guard içerir', () {
        final src = _read(path);
        expect(src.contains('bool _saving = false'), isTrue,
            reason: '$path _saving state\'i tutmalı');
        expect(src.contains('if (_saving) return;'), isTrue,
            reason: '$path _save başında re-entry guard olmalı');
        expect(src.contains('_saving ? null :'), isTrue,
            reason: '$path kaydet butonu kayıt sırasında devre dışı olmalı');
      });
    }
  });

  group('Instant UX — medya decode boyutu (full-res decode + bellek spike yok)',
      () {
    test('profil avatar (header) memCacheWidth kullanır', () {
      final src =
          _read('lib/features/social/profile/widgets/profile_header.dart');
      expect(src.contains('memCacheWidth:'), isTrue);
    });

    test('profil avatar (düzenleme sheet) memCacheWidth kullanır', () {
      final src = _read('lib/features/profile/widgets/profile_edit_sheet.dart');
      expect(src.contains('memCacheWidth:'), isTrue);
    });

    test('marketplace görsel galeri carousel memCacheWidth kullanır', () {
      final src = _read(
          'lib/features/marketplace/widgets/marketplace_image_gallery.dart');
      expect(src.contains('memCacheWidth: 720'), isTrue);
    });

    test('story viewer tam ekran görsel memCacheWidth kullanır', () {
      final src =
          _read('lib/features/social/stories/story_viewer_page.dart');
      expect(src.contains('memCacheWidth: 1080'), isTrue);
    });
  });
}
