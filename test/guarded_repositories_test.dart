import 'package:firin_defter/features/auth/services/auth_required_guard.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_metadata.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_quantities.dart';
import 'package:firin_defter/features/bakery_panel/models/recipe_record.dart';
import 'package:firin_defter/features/bakery_panel/repositories/guarded_recipe_repository.dart';
import 'package:firin_defter/features/bakery_panel/repositories/local_recipe_repository.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_note.dart';
import 'package:firin_defter/features/dealers/models/dealer_price.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/repositories/guarded_dealer_repository.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/repositories/guarded_feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/models/group_message.dart';
import 'package:firin_defter/features/social_groups/repositories/guarded_social_group_repository.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:firin_defter/features/worker/models/job_seek_post.dart';
import 'package:firin_defter/features/worker/models/worker_profile.dart';
import 'package:firin_defter/features/worker/repositories/guarded_worker_repository.dart';
import 'package:firin_defter/features/worker/repositories/local_worker_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────────
  // GUEST = canWrite false closure
  // AUTH  = canWrite true  closure
  // ─────────────────────────────────────────────────────────
  bool guestCheck() => false;
  bool authCheck() => true;

  group('V1.3.3 — GuardedFeedRepository', () {
    late LocalFeedRepository inner;
    setUp(() {
      inner = LocalFeedRepository(seed: false);
    });

    test('guest addPost → GuestActionRequiredException', () async {
      final repo = GuardedFeedRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.addPost(
          type: PostType.production,
          author: 'X',
          role: 'X',
          text: 'merhaba',
        ),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest toggleLike → exception', () async {
      final repo = GuardedFeedRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.toggleLike('x'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest toggleSave → exception', () async {
      final repo = GuardedFeedRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.toggleSave('x'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('auth addPost → forwards to inner', () async {
      final repo = GuardedFeedRepository(inner: inner, canWriteCheck: authCheck);
      final post = await repo.addPost(
        type: PostType.production,
        author: 'X',
        role: 'X',
        text: 'merhaba',
      );
      expect(post.id, isNotEmpty);
    });

    test('read forwards regardless of guest', () async {
      final repo = GuardedFeedRepository(inner: inner, canWriteCheck: guestCheck);
      final posts = await repo.listPosts();
      expect(posts, isEmpty); // seed=false
      // Insights statik mock — sayı önemli değil, guest yine de okuyabilir.
      final insights = await repo.listInsights();
      expect(insights, isNotNull);
    });
  });

  group('V1.3.3 — GuardedSocialGroupRepository', () {
    late LocalSocialGroupRepository inner;
    setUp(() {
      inner = LocalSocialGroupRepository(seed: false);
    });

    test('guest createGroup → exception', () async {
      final repo = GuardedSocialGroupRepository(
        inner: inner,
        canWriteCheck: guestCheck,
      );
      expect(
        () => repo.createGroup(
          name: 'Konya Fırıncıları',
          description: 'Sektör grubu',
          category: GroupCategory.bakers,
        ),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest joinGroup → exception', () async {
      final repo = GuardedSocialGroupRepository(
        inner: inner,
        canWriteCheck: guestCheck,
      );
      expect(
        () => repo.joinGroup('g1'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest leaveGroup → exception', () async {
      final repo = GuardedSocialGroupRepository(
        inner: inner,
        canWriteCheck: guestCheck,
      );
      expect(
        () => repo.leaveGroup('g1'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest postMessage → exception', () async {
      final repo = GuardedSocialGroupRepository(
        inner: inner,
        canWriteCheck: guestCheck,
      );
      expect(
        () => repo.postMessage(GroupMessage(
          id: 'm1',
          groupId: 'g1',
          authorName: 'X',
          authorRole: 'X',
          text: 'selam',
          createdAt: DateTime(2026, 5, 13),
        )),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('auth createGroup → forwards', () async {
      final repo = GuardedSocialGroupRepository(
        inner: inner,
        canWriteCheck: authCheck,
      );
      final g = await repo.createGroup(
        name: 'Konya',
        description: 'desc',
        category: GroupCategory.bakers,
      );
      expect(g.id, isNotEmpty);
    });

    test('read forwards regardless of guest', () async {
      final repo = GuardedSocialGroupRepository(
        inner: inner,
        canWriteCheck: guestCheck,
      );
      final groups = await repo.listGroups();
      expect(groups, isEmpty);
    });
  });

  group('V1.3.3 — GuardedRecipeRepository', () {
    late LocalRecipeRepository inner;
    setUp(() {
      inner = LocalRecipeRepository();
    });

    Recipe sampleDraft() => Recipe(
          id: '',
          productName: 'Ekmek',
          quantities: RecipeQuantities.defaults,
          result: const RecipeResult(
            waterLiters: 0,
            yeastKg: 0,
            saltKg: 0,
            totalDoughKg: 0,
            doughAfterWasteKg: 0,
            estimatedPieces: 0,
          ),
          metadata: RecipeMetadata.empty,
          createdAt: DateTime(2026, 5, 13),
        );

    test('guest save → exception', () async {
      final repo = GuardedRecipeRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.save(sampleDraft()),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest delete → exception', () async {
      final repo = GuardedRecipeRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.delete('x'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('auth save → forwards', () async {
      final repo = GuardedRecipeRepository(inner: inner, canWriteCheck: authCheck);
      final saved = await repo.save(sampleDraft());
      expect(saved.id, isNotEmpty);
    });

    test('read forwards', () async {
      final repo = GuardedRecipeRepository(inner: inner, canWriteCheck: guestCheck);
      final list = await repo.list();
      expect(list, isEmpty);
    });
  });

  group('V1.3.3 — GuardedDealerRepository', () {
    late LocalDealerRepository inner;
    setUp(() {
      inner = LocalDealerRepository(seed: false);
    });

    test('guest upsertDealer → exception', () async {
      final repo = GuardedDealerRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.upsertDealer(Dealer(
          id: 'd1',
          name: 'X',
          createdAt: DateTime(2026, 5, 13),
        )),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest setActive → exception', () async {
      final repo = GuardedDealerRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.setActive('d1', active: false),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest addPrice → exception', () async {
      final repo = GuardedDealerRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.addPrice(DealerPrice(
          id: 'p1',
          dealerId: 'd1',
          productName: 'Ekmek',
          unitPrice: 8,
          validFrom: DateTime(2026, 5, 13),
        )),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest addTransaction (payment) → exception', () async {
      final repo = GuardedDealerRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.addTransaction(DealerTransaction(
          id: 'tx1',
          dealerId: 'd1',
          type: DealerTransactionType.payment,
          amount: 100,
          createdAt: DateTime(2026, 5, 13),
        )),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest addNote → exception', () async {
      final repo = GuardedDealerRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.addNote(DealerNote(
          id: 'n1',
          dealerId: 'd1',
          note: 'not',
          createdAt: DateTime(2026, 5, 13),
        )),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('auth upsertDealer → forwards', () async {
      final repo = GuardedDealerRepository(inner: inner, canWriteCheck: authCheck);
      await repo.upsertDealer(Dealer(
        id: 'd1',
        name: 'X',
        createdAt: DateTime(2026, 5, 13),
      ));
      final list = await repo.listDealers();
      expect(list, hasLength(1));
    });
  });

  group('V1.3.3 — GuardedWorkerRepository', () {
    late LocalWorkerRepository inner;
    setUp(() {
      inner = LocalWorkerRepository();
    });

    test('guest upsertMyProfile → exception', () async {
      final repo = GuardedWorkerRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.upsertMyProfile(const WorkerProfile()),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest addExperience → exception', () async {
      final repo = GuardedWorkerRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.addExperience(WorkerExperience(
          title: 'X',
          startDate: DateTime(2020),
        )),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest deleteExperience → exception', () async {
      final repo = GuardedWorkerRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.deleteExperience('e1'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest upsertJobSeekPost → exception', () async {
      final repo = GuardedWorkerRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.upsertJobSeekPost(const JobSeekPost(title: 'X')),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('guest deleteJobSeekPost → exception', () async {
      final repo = GuardedWorkerRepository(inner: inner, canWriteCheck: guestCheck);
      expect(
        () => repo.deleteJobSeekPost('j1'),
        throwsA(isA<GuestActionRequiredException>()),
      );
    });

    test('auth upsertJobSeekPost → forwards', () async {
      final repo = GuardedWorkerRepository(inner: inner, canWriteCheck: authCheck);
      final p = await repo.upsertJobSeekPost(const JobSeekPost(title: 'X'));
      expect(p.id, isNotNull);
    });
  });

  group('V1.3.3 — Exception contract', () {
    test('GuestActionRequiredException action alanı opsiyonel', () {
      const e = GuestActionRequiredException();
      expect(e.action, isNull);
      expect(e.toString(), contains('Guest action blocked'));
    });

    test('GuestActionRequiredException action verirse toString içerir', () {
      const e = GuestActionRequiredException(action: 'gruba katılmak');
      expect(e.action, 'gruba katılmak');
      expect(e.toString(), contains('gruba katılmak'));
    });
  });
}
