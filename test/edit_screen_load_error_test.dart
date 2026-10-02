// Final audit P1 — düzenleme ekranı ilk yüklemesi ağ hatası verirse spinner
// sonsuza dek dönmemeli: hata durumu + Tekrar dene görünür, retry başarıyla
// formu açar.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/error_retry_state.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_record.dart';
import 'package:firin_defter/features/bakery_panel/providers/bakery_providers.dart';
import 'package:firin_defter/features/bakery_panel/repositories/local_recipe_repository.dart';
import 'package:firin_defter/features/bakery_panel/screens/recipe_editor_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/worker/models/job_seek_post.dart';
import 'package:firin_defter/features/worker/providers/worker_providers.dart';
import 'package:firin_defter/features/worker/repositories/local_worker_repository.dart';
import 'package:firin_defter/features/worker/screens/job_seek_post_form_screen.dart';
import 'package:firin_defter/features/jobs/models/job_offer_post.dart';
import 'package:firin_defter/features/jobs/providers/job_offer_providers.dart';
import 'package:firin_defter/features/jobs/repositories/local_job_offer_repository.dart';
import 'package:firin_defter/features/jobs/screens/job_offer_form_screen.dart';
import 'package:firin_defter/features/marketplace/models/market_listing.dart';
import 'package:firin_defter/features/marketplace/providers/market_listing_providers.dart';
import 'package:firin_defter/features/marketplace/repositories/local_market_listing_repository.dart';
import 'package:firin_defter/features/marketplace/screens/market_listing_form_screen.dart';
import 'package:firin_defter/features/worker/models/worker_profile.dart';
import 'package:firin_defter/features/worker/screens/worker_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FlakyRecipeRepository extends LocalRecipeRepository {
  int calls = 0;

  @override
  Future<Recipe?> getById(String id) async {
    calls++;
    if (calls == 1) throw Exception('network down');
    return null; // ikinci deneme: bulunamadı → ekran kapanır
  }
}

class _FlakyWorkerRepository extends LocalWorkerRepository {
  int calls = 0;

  @override
  Future<JobSeekPost?> getJobSeekPost(String id) async {
    calls++;
    throw Exception('network down');
  }
}

class _FlakyOfferRepo extends LocalJobOfferRepository {
  int calls = 0;
  @override
  Future<JobOfferPost?> getOffer(String id) async {
    calls++;
    throw Exception('network down');
  }
}

class _FlakyMarketRepo extends LocalMarketListingRepository {
  int calls = 0;
  @override
  Future<MarketListing?> getListing(String id) async {
    calls++;
    throw Exception('network down');
  }
}

class _FlakyWorkerProfileRepo extends LocalWorkerRepository {
  int calls = 0;
  @override
  Future<WorkerProfile?> getMyProfile() async {
    calls++;
    throw Exception('network down');
  }
}

Future<void> _expectErrorThenRetry(
  WidgetTester tester,
  Widget screen,
  List<Override> overrides,
  String key,
  int Function() calls,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(CircularProgressIndicator), findsNothing);
  expect(find.byKey(ValueKey(key)), findsOneWidget);
  await tester.tap(find.text(AppStrings.retry));
  await tester.pumpAndSettle();
  expect(calls(), 2);
  expect(find.byKey(ValueKey(key)), findsOneWidget);
}

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref) {
    state = const BakeryProfile(
      displayName: 'Hasan Usta',
      accountType: AccountType.commercial,
      city: 'Konya',
      roleBadge: 'Fırıncı',
      email: 'hasan@example.com',
    );
  }
}

void main() {
  testWidgets(
    'RecipeEditor: getById hatası → hata durumu, retry yeniden ister',
    (tester) async {
      final repo = _FlakyRecipeRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipeRepositoryProvider.overrideWithValue(repo),
            profileControllerProvider.overrideWith(
              _SeededProfileController.new,
            ),
          ],
          child: const MaterialApp(home: RecipeEditorScreen(recipeId: 'r1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byKey(const ValueKey('recipe_editor_load_error')),
        findsOneWidget,
      );
      expect(find.textContaining('network down'), findsNothing);

      await tester.tap(find.text(AppStrings.retry));
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
    },
  );

  testWidgets('JobSeekForm: getJobSeekPost hatası → sonsuz spinner yok', (
    tester,
  ) async {
    final repo = _FlakyWorkerRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workerRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: JobSeekPostFormScreen(postId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byKey(const ValueKey('job_seek_form_load_error')),
      findsOneWidget,
    );
    expect(find.byType(ErrorRetryState), findsOneWidget);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(
      find.byKey(const ValueKey('job_seek_form_load_error')),
      findsOneWidget,
    );
  });

  testWidgets('JobOfferForm: getOffer hatası → sonsuz spinner yok', (
    tester,
  ) async {
    final repo = _FlakyOfferRepo();
    await _expectErrorThenRetry(
      tester,
      const JobOfferFormScreen(postId: 'o1'),
      [jobOfferRepositoryProvider.overrideWithValue(repo)],
      'job_offer_form_load_error',
      () => repo.calls,
    );
  });

  testWidgets('MarketListingForm: getListing hatası → sonsuz spinner yok', (
    tester,
  ) async {
    final repo = _FlakyMarketRepo();
    await _expectErrorThenRetry(
      tester,
      const MarketListingFormScreen(listingId: 'm1'),
      [marketListingRepositoryProvider.overrideWithValue(repo)],
      'market_form_load_error',
      () => repo.calls,
    );
  });

  testWidgets('WorkerProfile: getMyProfile hatası → sonsuz spinner yok', (
    tester,
  ) async {
    final repo = _FlakyWorkerProfileRepo();
    await _expectErrorThenRetry(
      tester,
      const WorkerProfileScreen(),
      [workerRepositoryProvider.overrideWithValue(repo)],
      'worker_profile_load_error',
      () => repo.calls,
    );
  });
}
