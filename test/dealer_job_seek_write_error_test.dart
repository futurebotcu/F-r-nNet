// V1.4 P1.22 / P1.24 / P1.25 — Dealer price update + Job seek toggle/delete
// hata yönetimi regression.
//
// Risk register kanıtları:
//   P1.22  dealer_detail_screen.dart `_PriceSheet._save` no try/catch
//   P1.24  job_seek_posts_screen.dart `_toggleActive` silent
//   P1.25  job_seek_posts_screen.dart `_delete` silent
//
// Bu test her üç handler için:
//   - Repo throws → Türkçe hata snackbar görünür
//   - Guest guard / runGuardedMutation davranışı bozulmaz
//   - State temiz kalır (sheet açık kalır / confirm dialog akışı)

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/app_primary_button.dart';
import 'package:firin_defter/features/dealers/models/dealer_price.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/dealer_detail_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/worker/models/job_seek_post.dart';
import 'package:firin_defter/features/worker/providers/worker_providers.dart';
import 'package:firin_defter/features/worker/repositories/local_worker_repository.dart';
import 'package:firin_defter/features/worker/screens/job_seek_posts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ─────────────────────────────────────── Fakes

class _ThrowingDealerRepository extends LocalDealerRepository {
  _ThrowingDealerRepository() : super(seed: false);

  int addPriceCalls = 0;

  @override
  Future<void> addPrice(DealerPrice price) {
    addPriceCalls++;
    return Future<void>.error(Exception('network boom (addPrice)'));
  }

  // Note: addNote'a dokunulmadı; LocalDealerRepository default davranışı korunur.
}

class _ThrowingWorkerRepository extends LocalWorkerRepository {
  _ThrowingWorkerRepository({
    this.throwOnUpsert = false,
    this.throwOnDelete = false,
  });

  final bool throwOnUpsert;
  final bool throwOnDelete;
  int upsertCalls = 0;
  int deleteCalls = 0;

  @override
  Future<JobSeekPost> upsertJobSeekPost(JobSeekPost post) {
    upsertCalls++;
    if (throwOnUpsert) {
      return Future<JobSeekPost>.error(Exception('network boom (upsert)'));
    }
    return super.upsertJobSeekPost(post);
  }

  @override
  Future<void> deleteJobSeekPost(String id) {
    deleteCalls++;
    if (throwOnDelete) {
      return Future<void>.error(Exception('network boom (delete)'));
    }
    return super.deleteJobSeekPost(id);
  }
}

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _realProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

JobSeekPost _samplePost({bool isActive = true}) {
  return JobSeekPost(
    id: 'jsp_1',
    title: 'Vardiyalı fırıncı arıyorum',
    city: 'Konya',
    isActive: isActive,
    createdAt: DateTime(2026, 5, 17, 8),
  );
}

Widget _wrapDealer(LocalDealerRepository repo, Widget child) {
  return ProviderScope(
    overrides: [
      dealerRepositoryProvider.overrideWithValue(repo),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, _realProfile),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );
}

Widget _wrapWorker(LocalWorkerRepository repo, Widget child) {
  return ProviderScope(
    overrides: [
      workerRepositoryProvider.overrideWithValue(repo),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, _realProfile),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    // JobSeekPostCard.build içinde `DateFormat('d MMM yyyy', 'tr_TR')` var.
    await initializeDateFormatting('tr_TR', null);
  });

  // ─────────────────────────────────────── P1.22

  testWidgets(
    'P1.22 — addPrice throws → Türkçe hata snackbar; sheet açık kalır',
    (tester) async {
      final repo = _ThrowingDealerRepository();
      await tester.pumpWidget(
        _wrapDealer(repo, DealerPriceSheet(dealerId: 'd_test')),
      );

      // Ürün seç (ProductChoiceChips içinde "Ekmek" chip'i).
      await tester.tap(find.text('Ekmek'));
      await tester.pump();

      // Fiyat gir.
      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();

      // Kaydet — addPrice fırlatır.
      await tester.tap(find.byType(AppPrimaryButton));
      await tester.pumpAndSettle();

      expect(repo.addPriceCalls, 1);
      expect(
        find.text(AppStrings.dealerPriceSaveError),
        findsOneWidget,
        reason: 'addPrice fırlattığında Türkçe hata gösterilmeli.',
      );

      // Sheet AÇIK kalır — başarı snackbar'ı gözükmemeli.
      expect(
        find.textContaining(AppStrings.dealerPriceSheetSaved),
        findsNothing,
        reason: 'Hata yolunda success snackbar gösterilmemeli.',
      );
      // TextField hâlâ render'da → sheet pop edilmedi.
      expect(find.byType(TextField), findsOneWidget);
    },
  );

  // ─────────────────────────────────────── P1.24

  testWidgets('P1.24 — upsertJobSeekPost throws → Türkçe hata snackbar; '
      'runGuardedMutation guest contract korunur', (tester) async {
    final repo = _ThrowingWorkerRepository(throwOnUpsert: true);
    await tester.pumpWidget(
      _wrapWorker(repo, JobSeekPostCard(post: _samplePost(isActive: true))),
    );

    // isActive=true → toggle_on_rounded ikonu görünür.
    expect(find.byIcon(Icons.toggle_on_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.toggle_on_rounded));
    await tester.pumpAndSettle();

    expect(repo.upsertCalls, 1);
    expect(
      find.text(AppStrings.jobSeekPostToggleError),
      findsOneWidget,
      reason: 'upsertJobSeekPost fırlattığında Türkçe hata gösterilmeli.',
    );
  });

  // ─────────────────────────────────────── P1.25

  testWidgets('P1.25 — deleteJobSeekPost throws → Türkçe hata snackbar; '
      'confirm dialog davranışı bozulmaz', (tester) async {
    final repo = _ThrowingWorkerRepository(throwOnDelete: true);
    await tester.pumpWidget(
      _wrapWorker(repo, JobSeekPostCard(post: _samplePost())),
    );

    // Sil ikonunu tıkla → confirm dialog açılır.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Confirm dialog: "Sil" buton text'i ile FilledButton.
    expect(find.text('İlanı sil'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);

    // Sil onayı.
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    expect(
      find.text(AppStrings.jobSeekPostDeleteError),
      findsOneWidget,
      reason: 'deleteJobSeekPost fırlattığında Türkçe hata gösterilmeli.',
    );

    // Dialog kapanmış — "İlanı sil" başlık metni artık görünmez.
    expect(find.text('İlanı sil'), findsNothing);
  });
}
