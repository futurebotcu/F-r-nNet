// V1 P1-C — Feed Share Reality Patch regresyon testi (source-level).
//
// Audit (Feed Interactions Reality Sprint, AUDIT ONLY) sonucu: feed
// like/save/comment akışları ZATEN gerçek Supabase üzerinde çalışıyor.
// Tek kalan fake: Share button — `onShare` yalnız bir snackbar
// gösteriyordu ("Paylaşım menüsü açılıyor…").
//
// Bu patch native share'ı (share_plus) aktif eder:
// - `Share.share(_buildShareText(post), subject: AppStrings.feedShareSubject)`
// - Hata snackbar'ı: AppStrings.feedShareError ("Paylaşım açılamadı...")
// - `_buildShareText` saf helper — URL eklemiyor (deep link prod hazır değil).
//
// Native share dialog widget testten platform plugin kanalıyla
// tetiklenemez. Bu yüzden regresyon source-level olarak doğrulanır
// (account_deletion_p0_test / create_profile_hydrate_submit_guard_test
// pattern'iyle aynı).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feed Share Reality Patch (V1 P1-C) — source-level', () {
    late String feedScreenSrc;
    late String appStringsSrc;

    setUpAll(() {
      feedScreenSrc =
          File('lib/features/feed/screens/feed_screen.dart').readAsStringSync();
      appStringsSrc =
          File('lib/core/constants/app_strings.dart').readAsStringSync();
    });

    test('feed_screen.dart share_plus import içerir', () {
      expect(
        feedScreenSrc.contains("import 'package:share_plus/share_plus.dart';"),
        isTrue,
        reason: 'Native share için share_plus import zorunlu',
      );
    });

    test('feed_screen.dart `Share.share(` çağrısı içerir', () {
      expect(
        feedScreenSrc.contains('Share.share('),
        isTrue,
        reason: 'onShare native share API çağırmalı',
      );
    });

    test('feed_screen.dart `_buildShareText` helper içerir', () {
      expect(
        feedScreenSrc.contains('_buildShareText'),
        isTrue,
        reason: 'Paylaşım metni saf helper ile inşa edilmeli',
      );
      // Helper FeedPost parametresi almalı (saf, test edilebilir).
      expect(
        feedScreenSrc.contains('_buildShareText(FeedPost'),
        isTrue,
        reason: '_buildShareText FeedPost parametresi almalı',
      );
    });

    test('feed_screen.dart `AppStrings.feedShareSubject` kullanır', () {
      expect(
        feedScreenSrc.contains('AppStrings.feedShareSubject'),
        isTrue,
        reason: 'Share.share çağrısı subject parametresi olarak '
            'feedShareSubject vermeli',
      );
    });

    test('feed_screen.dart `AppStrings.feedShareError` catch içinde kullanır',
        () {
      // Hata snackbar referansı mevcut olmalı.
      expect(
        feedScreenSrc.contains('AppStrings.feedShareError'),
        isTrue,
        reason: 'Native share hata olursa Türkçe snackbar fire etmeli',
      );

      // Yapısal sıra: try → Share.share → catch → feedShareError snackbar.
      final idxOnShare = feedScreenSrc.indexOf('onShare: () async {');
      expect(idxOnShare, greaterThan(-1),
          reason: 'onShare async handler olmalı');
      final idxTry = feedScreenSrc.indexOf('try {', idxOnShare);
      final idxShareCall = feedScreenSrc.indexOf('Share.share(', idxTry);
      final idxCatch = feedScreenSrc.indexOf('} catch (_) {', idxShareCall);
      final idxErrorString =
          feedScreenSrc.indexOf('AppStrings.feedShareError', idxCatch);

      // Tüm noktalar onShare içinde sırayla bulunmalı.
      expect(idxTry, greaterThan(idxOnShare));
      expect(idxShareCall, greaterThan(idxTry));
      expect(idxCatch, greaterThan(idxShareCall));
      expect(idxErrorString, greaterThan(idxCatch),
          reason: 'feedShareError sadece catch içinde fire etmeli');
    });

    test('feed_screen.dart `onShare` ARTIK `feedActionShareSnack` kullanmaz',
        () {
      // Eski fake snackbar referansı tüm dosyada bulunmamalı (string hâlâ
      // AppStrings'te tutuluyor; ama onShare içinden temizlenmiş olmalı).
      final idxOnShare = feedScreenSrc.indexOf('onShare:');
      expect(idxOnShare, greaterThan(-1));
      // Onshare bloğunun sonunu yakala — bir sonraki UI prop'u (`onTagTap:`).
      final idxNext = feedScreenSrc.indexOf('onTagTap:', idxOnShare);
      expect(idxNext, greaterThan(idxOnShare));
      final onShareBlock = feedScreenSrc.substring(idxOnShare, idxNext);
      expect(
        onShareBlock.contains('feedActionShareSnack'),
        isFalse,
        reason: 'Eski fake snackbar onShare bloğundan çıkarılmış olmalı',
      );
    });

    test('AppStrings.feedShareSubject + feedShareError mevcut', () {
      expect(
        appStringsSrc.contains(
          "static const String feedShareSubject = 'FırınNet — Paylaşım';",
        ),
        isTrue,
        reason: 'feedShareSubject string sabiti tanımlı olmalı',
      );
      // Çok satırlı tanım — sadece anahtar satırı kontrol et.
      expect(
        appStringsSrc.contains('static const String feedShareError ='),
        isTrue,
        reason: 'feedShareError string sabiti tanımlı olmalı',
      );
      expect(
        appStringsSrc
            .contains("'Paylaşım açılamadı. Lütfen tekrar dene.'"),
        isTrue,
        reason: 'feedShareError gövdesi Türkçe ve kullanıcı dostu olmalı',
      );
    });

    test('_buildShareText helper gerekli alanları stringify eder', () {
      final idxFn = feedScreenSrc
          .indexOf('static String _buildShareText(FeedPost post)');
      expect(idxFn, greaterThan(-1), reason: 'Helper saf static olmalı');
      // Helper bloğunu izole et (sonraki `}` blok kapanışına kadar yeterli
      // — gövde tek seviye blok içinde).
      final blockEnd = feedScreenSrc.indexOf('\n}', idxFn);
      final body = feedScreenSrc.substring(idxFn, blockEnd);

      expect(body.contains('post.text'), isTrue,
          reason: 'Paylaşım metni gönderi içeriğini içermeli');
      expect(body.contains('post.author'), isTrue,
          reason: 'Paylaşım metni yazarı içermeli');
      expect(body.contains('post.tags'), isTrue,
          reason: 'Etiketler tag listesinden inşa edilmeli');
      // Marka çıpası — paylaşılan metnin FırınNet'ten geldiği anlaşılsın.
      expect(body.contains("FırınNet"), isTrue,
          reason: 'Paylaşım metni FırınNet markasını içermeli');
    });
  });
}
