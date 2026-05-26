// FırınNet Data Foundation M8 — controlled job_offer_posts code invariant
// testleri.
//
// Karar:
//   * job_offer_posts.role_code / shift_code / experience_code text
//     nullable + 3 CHECK (17 profession / 4 shift / 4 experience bracket).
//   * Eski role_title (NOT NULL) + shift_type + experience_required text
//     KORUNUR (display fallback + backward compat).
//   * Taxonomy: shifts (4) + experienceBrackets (4) FirinnetTaxonomy'ye
//     eklendi.
//   * UI: JobOfferFormScreen 3 TextField → 3 chip cluster (single-select).
//     Save dual-write (label + code).
//   * Display: _JobOfferCard _formatExperience + _formatShift code-aware.

import 'dart:io';

import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/data/firinnet_taxonomy.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/jobs/models/job_offer_post.dart';
import 'package:firin_defter/features/jobs/providers/job_offer_providers.dart';
import 'package:firin_defter/features/jobs/repositories/local_job_offer_repository.dart';
import 'package:firin_defter/features/jobs/screens/job_offer_form_screen.dart';
import 'package:firin_defter/features/jobs/screens/jobs_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('M8 — Taxonomy shifts', () {
    test('4 entry: gunduz/gece/vardiyali/esnek', () {
      expect(FirinnetTaxonomy.shifts.keys.toSet(),
          {'gunduz', 'gece', 'vardiyali', 'esnek'});
      expect(FirinnetTaxonomy.shifts['gunduz'], 'Gündüz');
      expect(FirinnetTaxonomy.shifts['vardiyali'], 'Vardiyalı');
    });

    test('shiftLabel ve isValidShiftCode', () {
      expect(FirinnetTaxonomy.shiftLabel('gece'), 'Gece');
      expect(FirinnetTaxonomy.shiftLabel('unknown'), isNull);
      expect(FirinnetTaxonomy.isValidShiftCode(null), isTrue);
      expect(FirinnetTaxonomy.isValidShiftCode('gunduz'), isTrue);
      expect(FirinnetTaxonomy.isValidShiftCode('unknown'), isFalse);
    });
  });

  group('M8 — Taxonomy experienceBrackets', () {
    test('4 entry: none/0_2/3_5/5_plus', () {
      expect(FirinnetTaxonomy.experienceBrackets.keys.toSet(),
          {'none', '0_2', '3_5', '5_plus'});
      expect(FirinnetTaxonomy.experienceBrackets['none'], 'Şart değil');
      expect(FirinnetTaxonomy.experienceBrackets['5_plus'], '5+ yıl');
    });

    test('experienceLabel ve isValidExperienceCode', () {
      expect(FirinnetTaxonomy.experienceLabel('3_5'), '3-5 yıl');
      expect(FirinnetTaxonomy.experienceLabel('unknown'), isNull);
      expect(FirinnetTaxonomy.isValidExperienceCode('none'), isTrue);
      expect(FirinnetTaxonomy.isValidExperienceCode('unknown'), isFalse);
    });
  });

  group('M8 — Migration source', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260524150000_job_offer_codes_m8.sql',
      ).readAsStringSync();
    });

    test('3 yeni nullable code kolonu (additive)', () {
      expect(
          sql.contains(
              'add column if not exists role_code text,\n  add column if not exists shift_code text,\n  add column if not exists experience_code text'),
          isTrue);
    });

    test('role_code CHECK: 17 profession code', () {
      expect(sql.contains('job_offer_posts_role_code_chk'), isTrue);
      // Spot check
      expect(sql.contains("'usta_firinci'"), isTrue);
      expect(sql.contains("'ekipman_satici'"), isTrue);
      expect(sql.contains("'other'"), isTrue);
    });

    test('shift_code CHECK: 4 entry', () {
      expect(sql.contains('job_offer_posts_shift_code_chk'), isTrue);
      expect(
          sql.contains(
              "shift_code in ('gunduz', 'gece', 'vardiyali', 'esnek')"),
          isTrue);
    });

    test('experience_code CHECK: 4 bracket', () {
      expect(sql.contains('job_offer_posts_experience_code_chk'), isTrue);
      expect(
          sql.contains(
              "experience_code in ('none', '0_2', '3_5', '5_plus')"),
          isTrue);
    });

    test('Eski role_title/shift_type/experience_required korunur', () {
      // *_code drop edilebilir rollback'te; ana text kolonlar DROP yok.
      final dropPattern = RegExp(
        r'drop column (role_title|shift_type|experience_required)(?:\s*;|\s+|$)',
        multiLine: true,
      );
      expect(dropPattern.hasMatch(sql), isFalse);
    });
  });

  group('M8 — JobOfferPost model dual-write', () {
    test('3 yeni code alanı default null', () {
      const p = JobOfferPost(title: 'X', roleTitle: 'Y');
      expect(p.roleCode, isNull);
      expect(p.shiftCode, isNull);
      expect(p.experienceCode, isNull);
    });

    test('toInsertRow code\'ları yazar', () {
      const p = JobOfferPost(
        title: 'X',
        roleTitle: 'Usta Fırıncı',
        roleCode: 'usta_firinci',
        shiftType: 'Gece',
        shiftCode: 'gece',
        experienceRequired: '3-5 yıl',
        experienceCode: '3_5',
      );
      final row = p.toInsertRow('owner-id');
      expect(row['role_code'], 'usta_firinci');
      expect(row['shift_code'], 'gece');
      expect(row['experience_code'], '3_5');
      // Eski label'lar da yazılır (dual-write)
      expect(row['role_title'], 'Usta Fırıncı');
      expect(row['shift_type'], 'Gece');
      expect(row['experience_required'], '3-5 yıl');
    });

    test('toInsertRow boş code → field eklenmez', () {
      const p = JobOfferPost(title: 'X', roleTitle: 'Y');
      final row = p.toInsertRow('owner-id');
      expect(row.containsKey('role_code'), isFalse);
      expect(row.containsKey('shift_code'), isFalse);
      expect(row.containsKey('experience_code'), isFalse);
    });

    test('fromRow code\'ları parse eder', () {
      final p = JobOfferPost.fromRow(<String, dynamic>{
        'id': 'p1',
        'title': 'X',
        'role_title': 'Usta Fırıncı',
        'role_code': 'usta_firinci',
        'shift_code': 'gunduz',
        'experience_code': '5_plus',
        'is_active': true,
        'contact_preference': 'in_app',
      });
      expect(p.roleCode, 'usta_firinci');
      expect(p.shiftCode, 'gunduz');
      expect(p.experienceCode, '5_plus');
    });

    test('copyWith code\'ları değiştirir', () {
      const p = JobOfferPost(title: 'X', roleTitle: 'Y', roleCode: 'cirak');
      final c = p.copyWith(
        roleCode: 'usta_firinci',
        shiftCode: 'esnek',
        experienceCode: 'none',
      );
      expect(c.roleCode, 'usta_firinci');
      expect(c.shiftCode, 'esnek');
      expect(c.experienceCode, 'none');
    });
  });

  group('M8 — Repository select clause', () {
    test('SupabaseJobOfferRepository._columns 3 yeni code alanı', () {
      final src = File(
        'lib/features/jobs/repositories/supabase_job_offer_repository.dart',
      ).readAsStringSync();
      expect(src.contains('role_title, role_code'), isTrue);
      expect(src.contains('shift_type, shift_code'), isTrue);
      expect(src.contains('experience_required, experience_code'), isTrue);
    });
  });

  group('M8 — UI source-level', () {
    test('JobOfferFormScreen 3 TextField yok, _CodeChipPicker var', () {
      final src = File(
        'lib/features/jobs/screens/job_offer_form_screen.dart',
      ).readAsStringSync();
      expect(src.contains('final _roleTitle = TextEditingController'), isFalse,
          reason: 'Eski roleTitle controller kaldırılmalı');
      expect(src.contains('final _shiftType = TextEditingController'), isFalse);
      expect(src.contains('final _experience = TextEditingController'),
          isFalse);
      expect(src.contains('_CodeChipPicker'), isTrue);
      // 3 chip picker entry kaynağı taxonomy
      expect(src.contains('FirinnetTaxonomy.professionEntries'), isTrue);
      expect(src.contains('FirinnetTaxonomy.shiftEntries'), isTrue);
      expect(src.contains('FirinnetTaxonomy.experienceEntries'), isTrue);
      // Save dual-write
      expect(src.contains('roleCode: _roleCode'), isTrue);
      expect(src.contains('shiftCode: _shiftCode'), isTrue);
      expect(src.contains('experienceCode: _experienceCode'), isTrue);
    });

    test('jobs_screen _JobOfferCard code-aware display getter\'ları', () {
      final src = File(
        'lib/features/jobs/screens/jobs_screen.dart',
      ).readAsStringSync();
      expect(src.contains('_formatShift()'), isTrue);
      expect(src.contains('FirinnetTaxonomy.experienceLabel'), isTrue);
      expect(src.contains('FirinnetTaxonomy.shiftLabel'), isTrue);
      // shift artık taxonomy üzerinden çiziliyor (eski direkt offer.shiftType
      // kullanımı kaldırıldı).
      expect(src.contains('shift: _formatShift()'), isTrue);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // M8 Cleanup — bireysel role guard + salary validation + role AppStrings
  // ────────────────────────────────────────────────────────────────────

  group('M8 Cleanup — AppStrings', () {
    test('jobOfferFieldRoleRequired = "Aranan rolü seç."', () {
      expect(AppStrings.jobOfferFieldRoleRequired, 'Aranan rolü seç.');
    });

    test('jobOfferCommercialOnly mesajı tanımlı', () {
      expect(
        AppStrings.jobOfferCommercialOnly,
        contains('ticari veya toptancı hesap'),
      );
    });

    test('jobOfferSalaryNegative + jobOfferSalaryMinGtMax tanımlı', () {
      expect(AppStrings.jobOfferSalaryNegative, 'Maaş negatif olamaz.');
      expect(
        AppStrings.jobOfferSalaryMinGtMax,
        'Asgari maaş azamiyi aşamaz.',
      );
    });
  });

  group('M8 Cleanup — source-level guardrails', () {
    test('JobOfferFormScreen literal "Aranan rolü seç." yok; '
        'AppStrings.jobOfferFieldRoleRequired kullanıyor', () {
      final src = File(
        'lib/features/jobs/screens/job_offer_form_screen.dart',
      ).readAsStringSync();
      // Literal Text('Aranan rolü seç.') artık form'da yok.
      final literalPattern = RegExp(r"Text\('Aranan rolü seç\.'\)");
      expect(literalPattern.hasMatch(src), isFalse,
          reason: 'Role required snackbar AppStrings.jobOfferFieldRoleRequired '
              'üzerinden çağrılmalı');
      // AppStrings reference var
      expect(
        src.contains('AppStrings.jobOfferFieldRoleRequired'),
        isTrue,
      );
    });

    test('JobsScreen _onAddPressed bireysel guard kodu içerir', () {
      final src = File(
        'lib/features/jobs/screens/jobs_screen.dart',
      ).readAsStringSync();
      expect(
        src.contains('AppStrings.jobOfferCommercialOnly'),
        isTrue,
        reason: 'JobsScreen._onAddPressed bireysel kullanıcı için snackbar '
            'göstermeli',
      );
    });

    test('JobOfferFormScreen initState defansif route guard içerir', () {
      final src = File(
        'lib/features/jobs/screens/job_offer_form_screen.dart',
      ).readAsStringSync();
      // Post-frame callback ile bireysel pop
      expect(src.contains('addPostFrameCallback'), isTrue);
      expect(src.contains('AppStrings.jobOfferCommercialOnly'), isTrue);
    });

    test('JobOfferFormScreen _onSavePressed salary validation içerir', () {
      final src = File(
        'lib/features/jobs/screens/job_offer_form_screen.dart',
      ).readAsStringSync();
      expect(src.contains('AppStrings.jobOfferSalaryNegative'), isTrue);
      expect(src.contains('AppStrings.jobOfferSalaryMinGtMax'), isTrue);
    });
  });

  group('M8 Cleanup — JobsScreen role guard widget', () {
    testWidgets(
        'Bireysel + segment 0 (Hiring) + "+" tap → snackbar + route push yok',
        (tester) async {
      final router = _testRouter(initialLocation: '/jobs');
      await tester.pumpWidget(
        _wrap(
          router: router,
          profile: _individualProfile,
          fakeAuth: true,
        ),
      );
      await tester.pumpAndSettle();

      // Bireysel + boş liste: empty-state CTA `canPostOffer=false` ile gizli;
      // sadece header "+" görünür. "+" tap.
      final addBtn = find.byIcon(Icons.add_rounded);
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Snackbar görünür, form route'a push EDİLMEDİ → form header yok.
      expect(
        find.text(AppStrings.jobOfferCommercialOnly),
        findsOneWidget,
      );
      expect(find.text(AppStrings.jobOfferFormTitleNew), findsNothing);
    });

    testWidgets('Ticari + segment 0 + "+" tap → form açılır (route push)',
        (tester) async {
      final router = _testRouter(initialLocation: '/jobs');
      await tester.pumpWidget(
        _wrap(
          router: router,
          profile: _commercialProfile,
          fakeAuth: true,
        ),
      );
      await tester.pumpAndSettle();

      // Ticari + boş liste → 2 add_rounded ikonu olur (header CTA +
      // empty-state "Usta Arıyorum İlanı Ver"). Header ilk gelen.
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      // Form route'una push edildi → form header görünür, snackbar yok.
      expect(find.text(AppStrings.jobOfferFormTitleNew), findsOneWidget);
      expect(
        find.text(AppStrings.jobOfferCommercialOnly),
        findsNothing,
      );
    });
  });

  group('M8 Cleanup — JobOfferFormScreen deep-link guard widget', () {
    testWidgets(
        'Bireysel deep-link → form render edilmez (snackbar + post-frame pop)',
        (tester) async {
      // Form'a direkt push (parent /jobs üzerinden) — canPop true olur.
      final router = _testRouter(initialLocation: '/jobs');
      await tester.pumpWidget(
        _wrap(
          router: router,
          profile: _individualProfile,
          fakeAuth: true,
        ),
      );
      await tester.pumpAndSettle();
      // Programatik push (kullanıcı CTA katmanını atlamış gibi)
      router.push(AppRoutes.jobOfferNew);
      await tester.pumpAndSettle();

      // Snackbar görünür + form header görünmez (pop sonrası /jobs'a döndük)
      expect(
        find.text(AppStrings.jobOfferCommercialOnly),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.jobOfferFormTitleNew),
        findsNothing,
      );
    });

    testWidgets(
        'Ticari deep-link → form normal render (header + role chip cluster)',
        (tester) async {
      final router = _testRouter(initialLocation: '/jobs');
      await tester.pumpWidget(
        _wrap(
          router: router,
          profile: _commercialProfile,
          fakeAuth: true,
        ),
      );
      await tester.pumpAndSettle();
      router.push(AppRoutes.jobOfferNew);
      await tester.pumpAndSettle();

      // Form header görünür, snackbar yok
      expect(
        find.text(AppStrings.jobOfferFormTitleNew),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.jobOfferCommercialOnly),
        findsNothing,
      );
    });
  });

  group('M8 Cleanup — JobOfferFormScreen salary validation widget', () {
    Future<void> openForm(WidgetTester tester) async {
      final router = _testRouter(initialLocation: '/jobs');
      await tester.pumpWidget(
        _wrap(
          router: router,
          profile: _commercialProfile,
          fakeAuth: true,
        ),
      );
      await tester.pumpAndSettle();
      router.push(AppRoutes.jobOfferNew);
      await tester.pumpAndSettle();
    }

    Future<void> fillBaseFields(WidgetTester tester) async {
      // Title gerekli
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.jobOfferFieldTitle),
        'Ekmek Ustası Aranıyor',
      );
      // Role chip (taxonomy ilk profession)
      final firstProfLabel =
          FirinnetTaxonomy.professions.values.first;
      await tester.ensureVisible(find.text(firstProfLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(firstProfLabel));
      await tester.pumpAndSettle();
    }

    Future<void> tapSave(WidgetTester tester) async {
      final saveBtn = find.text(AppStrings.jobOfferFormSaveCta);
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
    }

    testWidgets('salaryMin negatif → negatif snackbar', (tester) async {
      await openForm(tester);
      await fillBaseFields(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.jobOfferFieldSalaryMin),
        '-100',
      );
      await tapSave(tester);

      expect(
        find.text(AppStrings.jobOfferSalaryNegative),
        findsOneWidget,
      );
      // Save success snack çıkmamış olmalı
      expect(find.text(AppStrings.jobOfferSavedSnack), findsNothing);
    });

    testWidgets('salaryMax negatif → negatif snackbar', (tester) async {
      await openForm(tester);
      await fillBaseFields(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.jobOfferFieldSalaryMax),
        '-50',
      );
      await tapSave(tester);

      expect(
        find.text(AppStrings.jobOfferSalaryNegative),
        findsOneWidget,
      );
    });

    testWidgets('salaryMin > salaryMax → min>max snackbar', (tester) async {
      await openForm(tester);
      await fillBaseFields(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.jobOfferFieldSalaryMin),
        '10000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.jobOfferFieldSalaryMax),
        '5000',
      );
      await tapSave(tester);

      expect(
        find.text(AppStrings.jobOfferSalaryMinGtMax),
        findsOneWidget,
      );
      expect(find.text(AppStrings.jobOfferSavedSnack), findsNothing);
    });

    testWidgets('Boş salary alanları validation error üretmez (save geçer)',
        (tester) async {
      await openForm(tester);
      await fillBaseFields(tester);
      // Salary alanları dokunulmaz (boş)
      await tapSave(tester);

      // Salary snackbar'ları görünmez
      expect(find.text(AppStrings.jobOfferSalaryNegative), findsNothing);
      expect(find.text(AppStrings.jobOfferSalaryMinGtMax), findsNothing);
      // Save success snack görünür (Local repo flush sonrası)
      expect(find.text(AppStrings.jobOfferSavedSnack), findsOneWidget);
    });
  });
}

// ────────────────────────────────────────────────────────────────────
// M8 Cleanup widget test helpers
// ────────────────────────────────────────────────────────────────────

const BakeryProfile _commercialProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

const BakeryProfile _individualProfile = BakeryProfile(
  displayName: 'Ali Usta',
  accountType: AccountType.individual,
  city: 'Konya',
  roleBadge: 'Usta Fırıncı',
  email: 'ali@example.com',
);

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

GoRouter _testRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/jobs',
        builder: (_, __) => const JobsScreen(),
      ),
      GoRoute(
        path: '/jobs/offers/new',
        builder: (_, __) => const JobOfferFormScreen(),
      ),
      // Stub: gerçek route'da test'in başka feature'ları tetiklenmesin.
      GoRoute(
        path: '/jobs/offers/new-stub',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('OFFER-NEW-STUB')),
        ),
      ),
      GoRoute(
        path: '/worker/job-seek/new',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('SEEK-NEW-STUB')),
        ),
      ),
    ],
  );
}

/// Test wrapper — profile + repo override + AppConfig kapalı (Local repo).
Widget _wrap({
  required GoRouter router,
  required BakeryProfile profile,
  bool fakeAuth = true,
}) {
  return ProviderScope(
    overrides: [
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, profile),
      ),
      // Guest guard'ı bypass etmek için authenticated user simülasyonu yok;
      // bunun yerine local repo doğrudan override + AppConfig.supabaseEnabled
      // false ile guard sarmasız Local repo döner.
      currentAuthUserProvider.overrideWith((_) => null),
      jobOfferRepositoryProvider.overrideWith(
        (ref) => LocalJobOfferRepository(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}
