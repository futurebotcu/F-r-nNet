// FırınNet V1 Unified Profile M2 — invariant testleri.
//
// Tek public profile görünümü kararı:
//   * /u/:userId tek public profile (SocialProfilePage)
//   * /profile route redirector → /u/<my_id> (guest /auth'a)
//   * worker_profiles + worker_experiences edit-only kalır
//   * SocialProfilePage 5 section: Header + AccountTypeBadge +
//     Hakkında/İşletme + Mesleki Profil ve Deneyim + Açık Reçeteler +
//     Gönderiler
//   * profession_badge fallback: worker → profile
//   * RPC public_profile_detail aggregate whitelist (salary YOK)
//   * recipe section sadece is_public=true

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/models/public_profile_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M2 — Migration public_profile_detail RPC', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260520170000_unified_profile_public_rpc.sql',
      ).readAsStringSync();
    });

    test('worker_profiles + worker_experiences SELECT owner-only', () {
      expect(
        sql.contains('drop policy if exists worker_profiles_select_auth'),
        isTrue,
      );
      expect(
        sql.contains('worker_profiles_select_own'),
        isTrue,
      );
      expect(sql.contains('owner_id = auth.uid()'), isTrue);
      expect(
        sql.contains('worker_experiences_select_own'),
        isTrue,
      );
    });

    test('public_profile_detail fonksiyonu tanımlanmış', () {
      expect(
        sql.contains('function public.public_profile_detail(p_user_id uuid)'),
        isTrue,
      );
      expect(sql.contains('security definer'), isTrue);
      expect(sql.contains('set search_path = public, pg_temp'), isTrue);
      expect(sql.contains('stable'), isTrue);
    });

    test('Hassas alanlar RPC içinde YOK (whitelist)', () {
      // SQL yorumlarını ayıkla; sadece kod satırlarında ara.
      // Migration yorumlarında "salary_expectation hariç!" gibi açıklayıcı
      // text geçiyor — code-only kontrol yapıyoruz.
      final codeOnly = sql
          .split('\n')
          .map((l) => l.trimLeft())
          .where((l) => !l.startsWith('--'))
          .join('\n');
      expect(codeOnly.contains('salary_expectation'), isFalse,
          reason: 'Maaş beklentisi RPC SELECT clause\'ında olmamalı');
      expect(codeOnly.contains('email'), isFalse,
          reason: 'Email RPC SELECT clause\'ında olmamalı');
      expect(codeOnly.contains('phone'), isFalse,
          reason: 'Telefon RPC SELECT clause\'ında olmamalı');
    });

    test('Worker whitelist field setini içerir', () {
      // SELECT clause kontrolü
      expect(sql.contains('profession_badge'), isTrue);
      expect(sql.contains('experience_years'), isTrue);
      expect(sql.contains('cities'), isTrue);
      expect(sql.contains('skills'), isTrue);
      expect(sql.contains('shift_preference'), isTrue);
      expect(sql.contains('bio'), isTrue);
    });

    test('Bakery snippet (name/city/district/description) içerir', () {
      // SQL içinde bakery select satırı whitelist.
      final bakeryRegion =
          sql.substring(sql.indexOf('-- bakery snippet'));
      expect(bakeryRegion.contains('name'), isTrue);
      expect(bakeryRegion.contains('city'), isTrue);
      expect(bakeryRegion.contains('district'), isTrue);
      expect(bakeryRegion.contains('description'), isTrue);
    });

    test('Authenticated grant + revoke public', () {
      expect(
        sql.contains(
            'revoke all on function public.public_profile_detail(uuid) from public'),
        isTrue,
      );
      expect(
        sql.contains(
            'grant execute on function public.public_profile_detail(uuid)'),
        isTrue,
      );
    });
  });

  group('M2 — PublicProfileDetail model', () {
    test('fromRpcJson null/parse + effectiveProfessionBadge fallback', () {
      final detail = PublicProfileDetail.fromRpcJson(<String, dynamic>{
        'profile': {
          'id': 'u1',
          'display_name': 'Ahmet',
          'account_type': 'individual',
          'profession_badge': 'Çırak',
          'city': 'İstanbul',
        },
        'worker': {
          'profession_badge': 'Usta Fırıncı',
          'experience_years': 10,
          'cities': ['İstanbul', 'Bursa'],
          'skills': ['Hamur', 'Mayalama'],
          'shift_preference': 'Gece',
          'bio': 'kısa bio',
        },
        'experiences': [
          {
            'id': 'e1',
            'title': 'Pastane',
            'city': 'İstanbul',
            'start_date': '2022-01-01',
            'end_date': null,
            'description': 'açıklama',
          },
        ],
        'bakery': {
          'id': 'b1',
          'name': 'Fırın X',
          'city': 'İstanbul',
          'district': 'Kadıköy',
          'description': 'açıklama',
        },
      });
      expect(detail, isNotNull);
      expect(detail!.header.displayName, 'Ahmet');
      expect(detail.header.accountType, 'individual');
      // Worker öncelikli → 'Usta Fırıncı' (profiles fallback 'Çırak' değil)
      expect(detail.effectiveProfessionBadge, 'Usta Fırıncı');
      expect(detail.worker!.experienceYears, 10);
      expect(detail.worker!.skills, ['Hamur', 'Mayalama']);
      expect(detail.experiences, hasLength(1));
      expect(detail.experiences.first.isCurrent, isTrue);
      expect(detail.bakery!.name, 'Fırın X');
    });

    test('Worker yoksa profiles.profession_badge fallback', () {
      final detail = PublicProfileDetail.fromRpcJson(<String, dynamic>{
        'profile': {
          'id': 'u1',
          'display_name': 'Mehmet',
          'profession_badge': 'Toptancı',
        },
        'experiences': <dynamic>[],
      });
      expect(detail, isNotNull);
      expect(detail!.worker, isNull);
      expect(detail.effectiveProfessionBadge, 'Toptancı');
      expect(detail.hasWorkerInfo, isFalse);
      expect(detail.hasExperiences, isFalse);
      expect(detail.hasBakery, isFalse);
    });

    test('Null veya geçersiz JSON → null', () {
      expect(PublicProfileDetail.fromRpcJson(null), isNull);
      expect(PublicProfileDetail.fromRpcJson('string'), isNull);
      expect(
        PublicProfileDetail.fromRpcJson(<String, dynamic>{'profile': null}),
        isNull,
      );
    });
  });

  group('M2 — /profile redirector', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/profile/screens/profile_screen.dart')
          .readAsStringSync();
    });

    test('ProfileScreen kendi /u/<id> route\'una go eder', () {
      expect(
        src.contains(r"context.go('${AppRoutes.userPublicProfile}/${user.id}')"),
        isTrue,
      );
    });

    test('Guest ise /auth\'a yönlendirir', () {
      expect(src.contains('context.go(AppRoutes.authEntry)'), isTrue);
    });

    test('Eski public görünüm kodu kaldırıldı', () {
      expect(src.contains('_PublicRecipesSection'), isFalse,
          reason: 'Public reçete section SocialProfilePage\'e taşındı');
      expect(src.contains('FirinNetHeader'), isFalse,
          reason: 'Eski header görünümü kaldırıldı');
      expect(src.contains('SectionLabel'), isFalse);
    });
  });

  group('M2 — SocialProfilePage 5 section', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/social/profile/profile_page.dart')
          .readAsStringSync();
    });

    test('publicProfileDetailProvider watch eder', () {
      expect(src.contains('publicProfileDetailProvider(userId)'), isTrue);
    });

    test('5 yeni section + 1 mevcut posts section', () {
      expect(src.contains('_AccountTypeBadge'), isTrue);
      expect(src.contains('_AboutBakerySection'), isTrue);
      expect(src.contains('_ProfessionalSection'), isTrue);
      expect(src.contains('_PublicRecipesSection'), isTrue);
      expect(src.contains('profileSectionPosts'), isTrue);
    });

    test('Self → "Profili düzenle" CTA; non-self → Follow + Mesaj', () {
      expect(src.contains('_SelfEditCta'), isTrue);
      expect(src.contains('profileEditCta'), isTrue);
      expect(src.contains('FollowButton(userId: userId)'), isTrue);
      expect(src.contains('_ProfileMessageCta'), isTrue);
    });

    test('Ustalık Bilgisi tek sade section altında', () {
      // Profile Social Sprint — _ProfessionalSection sadece bio + uzmanlık
      // snapshot'ı (yıl + skills + cities + shift) gösterir; ayrı deneyim
      // timeline'ı (_ExperienceItem) sade tutmak için kaldırıldı.
      expect(src.contains('_WorkerSnapshot'), isTrue);
      expect(src.contains('_ExperienceItem'), isFalse);
      expect(src.contains('profileSectionProfessional'), isTrue);
      // İki ayrı section başlığı (Meslek bilgileri + Deneyimler) YOK
      final codeOnly = src
          .split('\n')
          .map((l) => l.trimLeft())
          .where((l) => !l.startsWith('//'))
          .join('\n');
      expect(codeOnly.contains("'Meslek bilgileri'"), isFalse);
      expect(codeOnly.contains("'Tecrübeler'"), isFalse);
    });

    test('AccountType rozet taxonomy label\'ından beslenir', () {
      expect(
        src.contains('AppStrings.profileAccountTypeLabels[code]'),
        isTrue,
      );
    });

    test('Recipes section publicRecipesByOwnerProvider kullanır', () {
      expect(
        src.contains('publicRecipesByOwnerProvider(userId)'),
        isTrue,
      );
    });

    test('Mesaj CTA findOrCreateDirectConversation profile_direct', () {
      expect(
        src.contains("contextType: 'profile_direct'"),
        isTrue,
      );
    });
  });

  group('M2 — AppStrings yeni section labels', () {
    test('profileAccountTypeLabels 3 değer içerir', () {
      expect(AppStrings.profileAccountTypeLabels.keys.toSet(), {
        'commercial',
        'individual',
        'wholesaler',
      });
    });

    test('Section + empty + edit sabitleri tanımlı', () {
      expect(AppStrings.profileSectionAbout, isNotEmpty);
      expect(AppStrings.profileSectionBakery, isNotEmpty);
      expect(AppStrings.profileSectionProfessional, isNotEmpty);
      expect(AppStrings.profileSectionPublicRecipes, isNotEmpty);
      expect(AppStrings.profileSectionPosts, isNotEmpty);
      expect(AppStrings.profileEditCta, isNotEmpty);
      expect(AppStrings.profileEmptyProfessional, isNotEmpty);
      expect(AppStrings.profileEmptyBakery, isNotEmpty);
      expect(AppStrings.profileEmptyRecipes, isNotEmpty);
    });
  });

  group('M2 — Worker edit ekranları edit-only kalır (route)', () {
    test('Router /worker/profile + /worker/experiences korunur', () {
      final src = File('lib/app/router/app_router.dart').readAsStringSync();
      expect(src.contains('AppRoutes.workerProfile'), isTrue);
      expect(src.contains('AppRoutes.workerExperiences'), isTrue);
      expect(src.contains('WorkerProfileScreen'), isTrue);
      expect(src.contains('WorkerExperiencesScreen'), isTrue);
    });
  });
}
