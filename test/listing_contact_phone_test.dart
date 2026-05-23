// FırınNet — Listing Contact Phone Sprint invariant testleri.
//
// Karar:
//   * job_offer_posts + job_seek_posts.contact_phone text nullable (yeni).
//   * job_seek_posts.contact_preference text not null default 'in_app' +
//     CHECK in_app/phone/whatsapp.
//   * Market'e dokunulmadı (mevcut sistem).
//   * Doğrulama YOK; sahibinin rızasıyla public.
//   * UI: form'da opsiyonel TextField + Türkçe helper metni; detail/list'te
//     telefon varsa "Ara" CTA görünür, yoksa görünmez.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/listing_phone_cta.dart';
import 'package:firin_defter/features/jobs/models/job_offer_post.dart';
import 'package:firin_defter/features/worker/models/job_seek_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Listing Contact Phone — Migration source', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260524080000_listing_contact_phone.sql',
      ).readAsStringSync();
    });

    test('job_offer + job_seek contact_phone (additive nullable)', () {
      expect(
          sql.contains(
              'alter table public.job_offer_posts\n  add column if not exists contact_phone text'),
          isTrue);
      expect(
          sql.contains(
              'alter table public.job_seek_posts\n  add column if not exists contact_phone text'),
          isTrue);
    });

    test('job_seek_posts.contact_preference yeni + default in_app', () {
      expect(
          sql.contains(
              "add column if not exists contact_preference text not null default 'in_app'"),
          isTrue);
    });

    test('CHECK constraint: contact_preference in (in_app, phone, whatsapp)',
        () {
      expect(sql.contains('job_offer_posts_contact_preference_chk'), isTrue);
      expect(sql.contains('job_seek_posts_contact_preference_chk'), isTrue);
      expect(
          sql.contains(
              "check (contact_preference in ('in_app', 'phone', 'whatsapp'))"),
          isTrue);
    });

    test("Market'e dokunulmuyor (alter table public.market_listings yok)",
        () {
      expect(sql.contains('alter table public.market_listings'), isFalse);
    });
  });

  group('Listing Contact Phone — JobOfferPost model dual-write', () {
    test('contactPhone alanı opsiyonel; toInsertRow boş → field eklenmez',
        () {
      const p = JobOfferPost(title: 'X', roleTitle: 'Y');
      final row = p.toInsertRow('owner1');
      expect(row.containsKey('contact_phone'), isFalse);
    });

    test('contactPhone dolu → row\'da contact_phone yazılır', () {
      const p = JobOfferPost(
        title: 'X',
        roleTitle: 'Y',
        contactPhone: '05321234567',
      );
      final row = p.toInsertRow('owner1');
      expect(row['contact_phone'], '05321234567');
    });

    test('fromRow contact_phone parse eder', () {
      final p = JobOfferPost.fromRow(<String, dynamic>{
        'id': 'p1',
        'title': 'X',
        'role_title': 'Y',
        'contact_phone': '05321234567',
        'is_active': true,
        'contact_preference': 'phone',
      });
      expect(p.contactPhone, '05321234567');
      expect(p.contactPreference, 'phone');
    });
  });

  group('Listing Contact Phone — JobSeekPost model dual-write', () {
    test('contactPhone + contactPreference defaultlar', () {
      const p = JobSeekPost(title: 'X');
      expect(p.contactPhone, isNull);
      expect(p.contactPreference, 'in_app');
    });

    test('toInsertRow contact_phone + contact_preference yazar', () {
      const p = JobSeekPost(
        title: 'X',
        contactPhone: '05321234567',
        contactPreference: 'phone',
      );
      final row = p.toInsertRow('owner1');
      expect(row['contact_phone'], '05321234567');
      expect(row['contact_preference'], 'phone');
    });

    test('fromRow contact_phone parse + default in_app fallback', () {
      final p = JobSeekPost.fromRow(<String, dynamic>{
        'id': 'p1',
        'title': 'X',
        'contact_phone': '05321234567',
        'is_active': true,
      });
      expect(p.contactPhone, '05321234567');
      expect(p.contactPreference, 'in_app');
    });
  });

  group('Listing Contact Phone — ListingPhoneCta helper', () {
    test('hasPhone null/boş/whitespace → false', () {
      expect(ListingPhoneCta.hasPhone(null), isFalse);
      expect(ListingPhoneCta.hasPhone(''), isFalse);
      expect(ListingPhoneCta.hasPhone('   '), isFalse);
    });

    test('hasPhone gerçek numara → true', () {
      expect(ListingPhoneCta.hasPhone('05321234567'), isTrue);
      expect(ListingPhoneCta.hasPhone('+90 532 123 45 67'), isTrue);
    });

    test('telUri tel:<phone> şeması üretir', () {
      final uri = ListingPhoneCta.telUri('05321234567');
      expect(uri.scheme, 'tel');
      expect(uri.path, '05321234567');
    });

    test('telUri trim yapar', () {
      final uri = ListingPhoneCta.telUri('  05321234567  ');
      expect(uri.path, '05321234567');
    });
  });

  group('Listing Contact Phone — AppStrings sabitleri', () {
    test('Türkçe label + helper + CTA + error sabitleri tanımlı', () {
      expect(AppStrings.listingContactPhoneLabel, isNotEmpty);
      expect(AppStrings.listingContactPhoneHint, isNotEmpty);
      expect(AppStrings.listingContactPhoneHelper, isNotEmpty);
      expect(AppStrings.listingContactCallCta, 'Ara');
      expect(AppStrings.listingContactCallError, isNotEmpty);
      // Helper kullanıcıya açık uyarı içermeli (rıza + doğrulama yok).
      expect(
          AppStrings.listingContactPhoneHelper
              .toLowerCase()
              .contains('görünür'),
          isTrue);
      expect(
          AppStrings.listingContactPhoneHelper
              .toLowerCase()
              .contains('doğrulama'),
          isTrue);
    });
  });

  group('Listing Contact Phone — UI source-level', () {
    test('JobOfferFormScreen contact phone TextField içerir', () {
      final src = File(
        'lib/features/jobs/screens/job_offer_form_screen.dart',
      ).readAsStringSync();
      expect(src.contains('_contactPhone'), isTrue);
      expect(src.contains('listingContactPhoneLabel'), isTrue);
      expect(src.contains('listingContactPhoneHelper'), isTrue);
    });

    test('JobSeekPostFormScreen contact phone TextField içerir', () {
      final src = File(
        'lib/features/worker/screens/job_seek_post_form_screen.dart',
      ).readAsStringSync();
      expect(src.contains('_contactPhone'), isTrue);
      expect(src.contains('listingContactPhoneLabel'), isTrue);
    });

    test('jobs_screen _JobOfferCard ListingPhoneCta kullanıyor', () {
      final src = File(
        'lib/features/jobs/screens/jobs_screen.dart',
      ).readAsStringSync();
      expect(src.contains('ListingPhoneCta'), isTrue);
      expect(src.contains('hasPhone(offer.contactPhone)'), isTrue);
      expect(src.contains('hasPhone(post.contactPhone)'), isTrue);
    });

    test('Market contact panel\'e dokunulmadı (mevcut tel: launchUrl)', () {
      final src = File(
        'lib/features/marketplace/widgets/marketplace_contact_panel.dart',
      ).readAsStringSync();
      expect(src.contains('listing.contactPhone'), isTrue,
          reason: 'Market mevcut contact alanları korunmalı');
      expect(src.contains("Uri(scheme: 'tel'"), isTrue);
    });
  });
}
