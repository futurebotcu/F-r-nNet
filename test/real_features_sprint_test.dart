// V1 — "Gerçek olmayan şeyleri gerçek yapma" sprint testleri.
//
// Kapsam:
//   1. FeedRepository interface — listComments/addComment/deleteComment
//      metotları zorunlu.
//   2. LocalFeedRepository unit — add + list (visible only) + soft delete.
//   3. JobOfferRepository interface + LocalJobOfferRepository unit.
//   4. MarketListingRepository interface + LocalMarketListingRepository unit.
//   5. Migration SQL string-smoke: job_offer_posts_v1, market_listings_v1
//      → RLS enabled, owner CRUD policy, no WITH CHECK(true).
//   6. JobsScreen kaynak kod: artık _HiringComingSoon yerine _HiringList
//      kullanılıyor; activeJobOffersProvider referansı var.
//   7. MarketplaceScreen kaynak kod: marketComingSoon yok, gerçek liste
//      bağlantısı var (activeMarketListingsProvider).

import 'dart:io';

import 'package:firin_defter/features/feed/models/feed_comment.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/repositories/feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/jobs/models/job_offer_post.dart';
import 'package:firin_defter/features/jobs/repositories/job_offer_repository.dart';
import 'package:firin_defter/features/jobs/repositories/local_job_offer_repository.dart';
import 'package:firin_defter/features/marketplace/models/market_listing.dart';
import 'package:firin_defter/features/marketplace/repositories/local_market_listing_repository.dart';
import 'package:firin_defter/features/marketplace/repositories/market_listing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feed comments (V1)', () {
    test('FeedRepository interface comment metotları içerir', () {
      // Compile-time assertion: LocalFeedRepository tüm metotları
      // implement etmek zorunda; aksi halde test compile etmez.
      const FeedRepository? typed = null;
      expect(typed, isNull);
      expect(LocalFeedRepository, isNotNull);
    });

    test('LocalFeedRepository addComment → listComments visible only', () async {
      final repo = LocalFeedRepository(seed: false);
      // Önce dummy post lazım — addPost ile oluştur.
      final post = await repo.addPost(
        type: PostType.question,
        author: 'Sen',
        role: 'Üye',
        text: 'Smoke post',
      );
      final c1 = await repo.addComment(
        postId: post.id,
        text: 'İlk yorum',
        currentAuthorName: 'Test',
        currentAuthorRole: 'Üye',
      );
      final c2 = await repo.addComment(
        postId: post.id,
        text: 'İkinci yorum',
      );
      var list = await repo.listComments(post.id);
      expect(list.length, 2);
      expect(list.map((c) => c.text).toList(), ['İlk yorum', 'İkinci yorum']);

      // Soft delete c1
      await repo.deleteComment(c1.id);
      list = await repo.listComments(post.id);
      expect(list.length, 1);
      expect(list.first.id, c2.id);
    });

    test('FeedComment.fromRow snapshot trigger çıktısını parse eder', () {
      final c = FeedComment.fromRow(<String, dynamic>{
        'id': 'abc',
        'post_id': 'fp_1',
        'owner_id': 'u_1',
        'text': 'hello',
        'author_name': 'Fatih',
        'author_role': 'Usta Fırıncı',
        'is_deleted': false,
        'created_at': '2026-05-16T10:00:00Z',
      });
      expect(c.authorName, 'Fatih');
      expect(c.authorRole, 'Usta Fırıncı');
      expect(c.text, 'hello');
      expect(c.isDeleted, isFalse);
    });
  });

  group('Job offers (V1)', () {
    test('JobOfferRepository tip', () {
      const JobOfferRepository? typed = null;
      expect(typed, isNull);
      expect(LocalJobOfferRepository, isNotNull);
    });

    test('LocalJobOfferRepository upsert + listActive + setActive + delete', () async {
      final repo = LocalJobOfferRepository();
      final p = await repo.upsertOffer(const JobOfferPost(
        title: 'Taş Fırın Ustası',
        roleTitle: 'Ekmek Ustası',
        city: 'İstanbul',
      ));
      var list = await repo.listActiveOffers();
      expect(list.length, 1);
      expect(list.first.title, 'Taş Fırın Ustası');

      // Pasifleştir → aktif listede görünmez
      await repo.setActive(p.id!, false);
      list = await repo.listActiveOffers();
      expect(list, isEmpty);

      // Tekrar aktif → gözükür
      await repo.setActive(p.id!, true);
      list = await repo.listActiveOffers();
      expect(list.length, 1);

      await repo.deleteOffer(p.id!);
      list = await repo.listActiveOffers();
      expect(list, isEmpty);
    });

    test('JobOfferPost.toInsertRow zorunlu alanları içerir', () {
      const post = JobOfferPost(
        title: 'X',
        roleTitle: 'Y',
        city: 'Ankara',
      );
      final row = post.toInsertRow('owner-1');
      expect(row['owner_id'], 'owner-1');
      expect(row['title'], 'X');
      expect(row['role_title'], 'Y');
      expect(row['city'], 'Ankara');
      expect(row['is_active'], isTrue);
      expect(row['contact_preference'], 'in_app');
    });
  });

  group('Marketplace listings (V1)', () {
    test('MarketListingRepository tip', () {
      const MarketListingRepository? typed = null;
      expect(typed, isNull);
      expect(LocalMarketListingRepository, isNotNull);
    });

    test('LocalMarketListingRepository upsert + filter + delete', () async {
      final repo = LocalMarketListingRepository();
      final m1 = await repo.upsertListing(const MarketListing(
        title: 'Spiral mikser',
        category: 'ekipman',
      ));
      await repo.upsertListing(const MarketListing(
        title: 'Tip 550 un',
        category: 'hammadde',
      ));
      var list = await repo.listActive();
      expect(list.length, 2);
      list = await repo.listActive(category: 'ekipman');
      expect(list.length, 1);
      expect(list.first.title, 'Spiral mikser');

      await repo.setActive(m1.id!, false);
      list = await repo.listActive();
      expect(list.length, 1);
      expect(list.first.title, 'Tip 550 un');
    });

    test('MarketListing.toInsertRow kategori + tür zorunlu', () {
      const m = MarketListing(
        title: 'X',
        category: 'ekipman',
        listingType: 'product',
        price: 1000,
      );
      final row = m.toInsertRow('owner-1');
      expect(row['owner_id'], 'owner-1');
      expect(row['category'], 'ekipman');
      expect(row['listing_type'], 'product');
      expect(row['price'], 1000);
      expect(row['is_active'], isTrue);
    });
  });

  group('Migration SQL — job_offer_posts_v1 smoke', () {
    late String sql;
    setUpAll(() {
      sql = File('supabase/migrations/20260516092824_job_offer_posts_v1.sql')
          .readAsStringSync()
          .toLowerCase();
    });

    test('table create + rls + policies', () {
      expect(sql.contains('create table public.job_offer_posts'), isTrue);
      expect(sql.contains('enable row level security'), isTrue);
      expect(sql.contains('job_offer_posts_select_active_or_own'), isTrue);
      expect(sql.contains('job_offer_posts_insert_own'), isTrue);
      expect(sql.contains('job_offer_posts_update_own'), isTrue);
      expect(sql.contains('job_offer_posts_delete_own'), isTrue);
    });

    test('owner check + no with check true', () {
      expect(sql.contains('owner_id = auth.uid()'), isTrue);
      expect(sql.contains('with check (true)'), isFalse);
    });

    test('snapshot trigger + grants', () {
      expect(sql.contains('snapshot_job_offer_post_author'), isTrue);
      expect(sql.contains('security definer'), isTrue);
      expect(sql.contains('set search_path = public'), isTrue);
      expect(sql.contains('grant select, insert, update, delete'), isTrue);
      expect(sql.contains('to authenticated'), isTrue);
    });
  });

  group('Migration SQL — market_listings_v1 smoke', () {
    late String sql;
    setUpAll(() {
      sql = File('supabase/migrations/20260516092830_market_listings_v1.sql')
          .readAsStringSync()
          .toLowerCase();
    });

    test('table create + rls + policies', () {
      expect(sql.contains('create table public.market_listings'), isTrue);
      expect(sql.contains('enable row level security'), isTrue);
      expect(sql.contains('market_listings_select_active_or_own'), isTrue);
      expect(sql.contains('market_listings_insert_own'), isTrue);
      expect(sql.contains('market_listings_update_own'), isTrue);
      expect(sql.contains('market_listings_delete_own'), isTrue);
    });

    test('owner check + no with check true', () {
      expect(sql.contains('owner_id = auth.uid()'), isTrue);
      expect(sql.contains('with check (true)'), isFalse);
    });

    test('category check + snapshot trigger', () {
      expect(sql.contains("category in ('hammadde','ekipman'"), isTrue);
      expect(sql.contains('snapshot_market_listing_author'), isTrue);
    });
  });

  group('JobsScreen UI source — V2 sprint sonrası', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/jobs/screens/jobs_screen.dart')
          .readAsStringSync();
    });

    test('Usta Arıyor segmenti gerçek provider\'a bağlı', () {
      expect(src.contains('_HiringList'), isTrue);
      expect(src.contains('activeJobOffersProvider'), isTrue,
          reason: 'Hiring segment artık job_offer_posts\'a bağlı olmalı');
    });

    test('Job offer form route push var', () {
      expect(src.contains('AppRoutes.jobOfferNew'), isTrue);
    });
  });

  group('MarketplaceScreen UI source — V2 sprint sonrası', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/marketplace/screens/marketplace_screen.dart')
          .readAsStringSync();
    });

    test('coming-soon ekran yerine gerçek liste var', () {
      // Eski coming-soon başlığı kaldırıldı; activeMarketListingsProvider gözüküyor.
      expect(src.contains('activeMarketListingsProvider'), isTrue,
          reason: 'Marketplace artık gerçek listingleri çekmeli');
      expect(src.contains('marketComingSoonTitle'), isFalse,
          reason: 'Eski coming-soon kart kaldırılmalı');
    });
  });
}

