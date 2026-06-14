// Professional Profile Center Sprint 1 — çalışma geçmişi + iş arama + durum
// profil vitrinine bağlandı.
//
// SocialProfilePage tam-sayfa pump'ı 7+ provider override (paged AsyncNotifier
// family dahil) gerektirir; mevcut `unified_profile_test.dart` deseniyle
// uyumlu olarak: (1) yeni provider davranışı container ile, (2) profil
// sayfasının yeni bölümlerinin kaynak-seviyesi varlığı doğrulanır.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/worker/models/job_seek_post.dart';
import 'package:firin_defter/features/worker/providers/worker_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Professional Profile Center — activeJobSeekOfProvider', () {
    test('owner filtreler: eşleşen owner\'ın aktif ilanı döner', () async {
      final container = ProviderContainer(
        overrides: [
          activeJobSeekPostsProvider.overrideWith((ref) async => const [
                JobSeekPost(id: 'j1', ownerId: 'owner_a', title: 'A ilanı'),
                JobSeekPost(id: 'j2', ownerId: 'owner_b', title: 'B ilanı'),
              ]),
        ],
      );
      addTearDown(container.dispose);

      final a = await container.read(activeJobSeekOfProvider('owner_a').future);
      expect(a?.id, 'j1');
      final b = await container.read(activeJobSeekOfProvider('owner_b').future);
      expect(b?.id, 'j2');
    });

    test('eşleşme yoksa null döner', () async {
      final container = ProviderContainer(
        overrides: [
          activeJobSeekPostsProvider.overrideWith((ref) async => const [
                JobSeekPost(id: 'j1', ownerId: 'owner_a', title: 'A'),
              ]),
        ],
      );
      addTearDown(container.dispose);

      final c = await container.read(activeJobSeekOfProvider('owner_x').future);
      expect(c, isNull);
    });
  });

  group('Professional Profile Center — profile_page kaynak', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/social/profile/profile_page.dart')
          .readAsStringSync();
    });

    test('Çalışma Geçmişi bölümü eklendi ve experiences render ediliyor', () {
      expect(src.contains('_ExperienceSection'), isTrue);
      expect(src.contains('AppStrings.profileSectionExperience'), isTrue);
      expect(src.contains('d.experiences'), isTrue,
          reason: 'worker_experiences artık UI\'da render ediliyor (P1 fix)');
    });

    test('boş çalışma geçmişi: self CTA var / başkası bakınca gizli', () {
      expect(src.contains('AppStrings.profileExperienceAddCta'), isTrue);
      expect(
        src.contains('if (!hasContent && !isSelf) return const SizedBox.shrink();'),
        isTrue,
        reason: 'başkası + boş → bölüm gizlenir',
      );
    });

    test('İş Arıyor kartı eklendi ve ilana yönlendiriyor (P1 fix)', () {
      expect(src.contains('_JobSeekCard'), isTrue);
      expect(src.contains('AppStrings.profileJobSeekTitle'), isTrue);
      expect(src.contains('activeJobSeekOfProvider'), isTrue);
      expect(src.contains('AppRoutes.jobs'), isTrue);
    });

    test('Son durum chip + tüm türetme branch\'leri mevcut', () {
      expect(src.contains('_StatusChip'), isTrue);
      expect(src.contains('AppStrings.profileStatusSeeking'), isTrue);
      expect(src.contains('AppStrings.profileStatusBakery'), isTrue);
      expect(src.contains('AppStrings.profileStatusWholesaler'), isTrue);
      expect(src.contains('AppStrings.profileStatusWorking'), isTrue);
    });
  });

  group('Profile Routing + Panel Consolidation — /profile redirect', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/profile/screens/profile_screen.dart')
          .readAsStringSync();
    });

    test('authenticated → /u/:id vitrin profiline yönlenir', () {
      expect(
        src.contains(
          "context.pushReplacement('\${AppRoutes.userPublicProfile}/\${user.id}')",
        ),
        isTrue,
        reason: '/profile kendi vitrin profiline (SocialProfilePage) '
            'pushReplacement ile yönlenir (back-stack korunur)',
      );
    });

    test('guest → authEntry (crash yok, auth guard)', () {
      expect(src.contains('AppRoutes.authEntry'), isTrue);
      expect(src.contains('user == null'), isTrue);
    });
  });

  group('Unified CV Center — vitrin self düzenleme tek merkeze yönlenir', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/social/profile/profile_page.dart')
          .readAsStringSync();
    });

    test('self CV düzenleme CTA\'ları /profile/cv merkezine yönlenir', () {
      expect(src.contains('AppRoutes.professionalCv'), isTrue,
          reason: 'mesleki bilgi + çalışma geçmişi + iş arama tek CV merkezine');
      expect(src.contains('_CvHeader'), isTrue,
          reason: 'tek "Mesleki CV" çatı başlığı eklendi');
      expect(src.contains('AppStrings.profileSectionCv'), isTrue);
    });

    test('hesap ayarları (settings) AppBar\'dan erişilebilir kalır', () {
      expect(src.contains('AppRoutes.settings'), isTrue);
    });

    test('job-seek self manage CTA mevcut', () {
      expect(src.contains('profile_job_seek_manage_cta'), isTrue);
      expect(src.contains('AppStrings.profileJobSeekManageCta'), isTrue);
    });
  });

  group('Professional Visitor View — Mesleki Bilgi tab self/visitor ayrımı', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/social/profile/profile_page.dart')
          .readAsStringSync();
    });

    test('visitor başlığı "Mesleki Bilgi", self "Mesleki CV"', () {
      expect(
        src.contains(
            'isSelf ? AppStrings.profileSectionCv : AppStrings.profileTabCv'),
        isTrue,
      );
    });

    test('owner-dili alt açıklama yalnız self (visitor\'da gizli)', () {
      expect(src.contains('AppStrings.profileCvSectionSubtitle'), isTrue);
      expect(src.contains('// Owner\'a hitap eden açıklama yalnız self'),
          isTrue, reason: 'subtitle if (isSelf) ile koşullu');
    });

    test('visitor + public mesleki içerik yoksa sade empty state', () {
      expect(src.contains('AppStrings.profileCvVisitorEmpty'), isTrue);
      expect(src.contains('if (!isSelf)'), isTrue);
    });

    test('iş arıyor kart başlığı ilk harf büyütülür', () {
      expect(src.contains('_capitalizeFirst(post.title)'), isTrue);
    });
  });

  group('Professional Profile Center — yeni string\'ler', () {
    test('profil string\'leri boş değil', () {
      expect(AppStrings.profileSectionExperience, isNotEmpty);
      expect(AppStrings.profileEmptyExperience, isNotEmpty);
      expect(AppStrings.profileExperienceAddCta, isNotEmpty);
      expect(AppStrings.profileJobSeekTitle, isNotEmpty);
      expect(AppStrings.profileJobSeekViewCta, isNotEmpty);
      expect(AppStrings.profileStatusSeeking, isNotEmpty);
      expect(AppStrings.profileStatusBakery, isNotEmpty);
      expect(AppStrings.profileStatusWholesaler, isNotEmpty);
      expect(AppStrings.profileStatusWorking, isNotEmpty);
      expect(AppStrings.profileJobSeekManageCta, isNotEmpty);
      expect(AppStrings.cardProfileCv, isNotEmpty);
      expect(AppStrings.cardProfileCvSubIndividual, isNotEmpty);
      expect(AppStrings.cardProfileCvSubCommercial, isNotEmpty);
    });
  });
}
