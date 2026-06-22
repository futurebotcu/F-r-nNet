// FırınNet Social V2 Commit 3.5 — Media composer flow fix testleri.
//
// Kapsam:
//   * Composer: 4-buton (Foto seç / Foto çek / Video seç / Video çek) +
//     prompt headline + sticky bottom "Paylaş" CTA + _canShare durumu.
//   * Story create: 2-buton (Foto seç / Foto çek) + sticky bottom
//     "Hikayeyi paylaş" CTA + hasPicked durumuna göre enabled/disabled.
//   * AppStrings yeni sabitler.
//   * ImageSource.camera + ImageSource.gallery iki yol da kullanılıyor.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:firin_defter/core/constants/app_strings.dart';

String _strip(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .where((l) => !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('V2 Commit 3.5 — AppStrings yeni composer/story sabitleri', () {
    test('Composer prompt + 4 buton + sticky CTA', () {
      expect(
        AppStrings.composerPromptHeadline,
        'Fotoğraf, video veya deneyimini paylaş.',
      );
      expect(AppStrings.composerPickPhotoCta, 'Foto seç');
      expect(AppStrings.composerCapturePhotoCta, 'Foto çek');
      expect(AppStrings.composerPickVideoCta, 'Video seç');
      expect(AppStrings.composerCaptureVideoCta, 'Video çek');
      expect(AppStrings.composerShareCta, 'Paylaş');
      expect(AppStrings.composerSharingCta, 'Paylaşılıyor…');
      expect(AppStrings.composerMediaSectionLabel, 'Medya');
    });

    test('Story create CTA + kamera çek', () {
      expect(AppStrings.storyCapturePhotoCta, 'Foto çek');
      expect(AppStrings.storyShareCta, 'Hikayeyi paylaş');
      expect(AppStrings.storySharingCta, 'Paylaşılıyor…');
    });
  });

  group('V2 Commit 3.5 — SocialComposerPage source', () {
    final src = _strip(
      File('lib/features/social/composer/social_composer_page.dart')
          .readAsStringSync(),
    );

    test('Foto seç + Foto çek metodları (camera + gallery yolları)', () {
      expect(src.contains('Future<void> _pickImage()'), isTrue);
      expect(src.contains('Future<void> _capturePhoto()'), isTrue);
      expect(src.contains('ImageSource.gallery'), isTrue);
      expect(src.contains('ImageSource.camera'), isTrue);
      // Helper birleştirici
      expect(src.contains('_captureOrPickImage'), isTrue);
    });

    test('Video seç + Video çek metodları', () {
      expect(src.contains('Future<void> _pickVideo()'), isTrue);
      expect(src.contains('Future<void> _captureVideo()'), isTrue);
      expect(src.contains('_captureOrPickVideo'), isTrue);
    });

    test('4 _MediaButton kullanımı (Foto seç + çek + Video seç + çek)', () {
      // Pattern: _MediaButton(... label: AppStrings.composer{Pick|Capture}{Photo|Video}Cta ...)
      expect(src.contains('AppStrings.composerPickPhotoCta'), isTrue);
      expect(src.contains('AppStrings.composerCapturePhotoCta'), isTrue);
      expect(src.contains('AppStrings.composerPickVideoCta'), isTrue);
      expect(src.contains('AppStrings.composerCaptureVideoCta'), isTrue);
      // _MediaButton class tanımlı
      expect(src.contains('class _MediaButton'), isTrue);
    });

    test('Sticky bottom Paylaş CTA — bottomNavigationBar + 52px', () {
      expect(src.contains('bottomNavigationBar:'), isTrue);
      expect(src.contains('height: 52,'), isTrue);
      expect(src.contains('AppStrings.composerShareCta'), isTrue);
      expect(src.contains('AppStrings.composerSharingCta'), isTrue);
    });

    test('_canShare disabled/enabled durumu (metin VEYA medya)', () {
      expect(src.contains('bool get _canShare'), isTrue);
      expect(src.contains('onPressed: _canShare ? _submit : null'), isTrue);
      // TextField onChanged → setState (PR-UI-2: ayrıca _dirty işaretler →
      // sticky CTA hâlâ metin değişimine reaktif).
      expect(
        src.contains('onChanged: (_) => setState(() => _dirty = true)'),
        isTrue,
        reason: 'Sticky CTA TextField değişimine reaktif',
      );
    });

    test('Mutually exclusive: image picked → video reset (composer)', () {
      expect(src.contains('_pickedVideoBytes = null'), isTrue);
      expect(src.contains('_pickedBytes = null'), isTrue);
    });

    test('AppBar Paylaş kaldırıldı — sticky bottom yerine', () {
      // AppBar actions block kalkmalı (eski büyük FilledButton AppBar'da).
      // Yeni sticky bottom CTA var.
      final appBarStart = src.indexOf('appBar: AppBar(');
      final bodyStart = src.indexOf('body: SafeArea(');
      expect(appBarStart, greaterThan(0));
      expect(bodyStart, greaterThan(appBarStart));
      final appBarSrc = src.substring(appBarStart, bodyStart);
      expect(
        appBarSrc.contains('actions:'),
        isFalse,
        reason: 'AppBar action button yok; sticky bottom CTA kullanılır',
      );
    });
  });

  group('V2 Commit 3.5 — SocialStoryCreatePage source', () {
    final src = _strip(
      File('lib/features/social/stories/story_create_page.dart')
          .readAsStringSync(),
    );

    test('Foto seç + Foto çek metodları', () {
      expect(src.contains('Future<void> _pickImage()'), isTrue);
      expect(src.contains('Future<void> _capturePhoto()'), isTrue);
      expect(src.contains('ImageSource.gallery'), isTrue);
      expect(src.contains('ImageSource.camera'), isTrue);
    });

    test('Empty state 2 buton: Foto seç (FilledButton) + Foto çek (Outlined)',
        () {
      expect(src.contains('AppStrings.storyCreatePickCta'), isTrue);
      expect(src.contains('AppStrings.storyCapturePhotoCta'), isTrue);
    });

    test('Sticky bottom Hikayeyi paylaş CTA + 52px', () {
      expect(src.contains('bottomNavigationBar:'), isTrue);
      expect(src.contains('height: 52,'), isTrue);
      expect(src.contains('AppStrings.storyShareCta'), isTrue);
      expect(src.contains('AppStrings.storySharingCta'), isTrue);
    });

    test('hasPicked disabled/enabled durumu', () {
      // CTA: onPressed: (hasPicked && !_saving) ? _share : null
      expect(
        src.contains('(hasPicked && !_saving) ? _share : null'),
        isTrue,
      );
    });

    test('AppBar Paylaş kaldırıldı — sticky bottom yerine', () {
      final appBarStart = src.indexOf('appBar: AppBar(');
      final bottomNavStart = src.indexOf('bottomNavigationBar:');
      expect(appBarStart, greaterThan(0));
      expect(bottomNavStart, greaterThan(appBarStart));
      final appBarSrc = src.substring(appBarStart, bottomNavStart);
      expect(
        appBarSrc.contains('actions:'),
        isFalse,
        reason: 'Story AppBar action button yok; sticky bottom CTA',
      );
    });
  });
}
