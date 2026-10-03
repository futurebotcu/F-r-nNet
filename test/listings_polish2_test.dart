// İlanlar polish 2 — widget testleri.
//
//   * Kart + detay + oluşturma formu: 320px genişlik × 1.0/1.3/1.5 yazı
//     ölçeği, uzun başlık/işletme/şehir → taşma yok.
//   * Görselsiz market kartı ortak "görsel yok" durumunu gösterir (kırık
//     görsel ikonu yok).
//   * Aynı ilan türünde kart ve detay birincil CTA etiketi aynı.
//   * Detay boş alanları gizler ("—" yok).
//   * İş arayan / personel arayan rozetleri hâlâ ayrışır.
//   * İlk yüklemede kart iskeleti (tek büyük spinner değil).
//   * Silme onayı ortak onay dialoguyla (app_confirm_dialog).

import 'dart:async';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/listing_phone_cta.dart';
import 'package:firin_defter/core/widgets/premium/job_opportunity_card.dart';
import 'package:firin_defter/features/auth/models/auth_user.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/jobs/models/job_offer_post.dart';
import 'package:firin_defter/features/jobs/providers/job_offer_providers.dart';
import 'package:firin_defter/features/jobs/screens/job_offer_form_screen.dart';
import 'package:firin_defter/features/jobs/screens/jobs_screen.dart';
import 'package:firin_defter/features/marketplace/models/market_filters.dart';
import 'package:firin_defter/features/marketplace/models/market_listing.dart';
import 'package:firin_defter/features/marketplace/providers/market_listing_providers.dart';
import 'package:firin_defter/features/marketplace/repositories/local_market_listing_repository.dart';
import 'package:firin_defter/features/marketplace/screens/market_listing_form_screen.dart';
import 'package:firin_defter/features/marketplace/screens/marketplace_detail_screen.dart';
import 'package:firin_defter/features/marketplace/screens/marketplace_screen.dart';
import 'package:firin_defter/features/marketplace/widgets/marketplace_listing_card.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/worker/models/job_seek_post.dart';
import 'package:firin_defter/features/worker/providers/worker_providers.dart';
import 'package:firin_defter/features/worker/screens/job_seek_post_form_screen.dart';
import 'package:firin_defter/features/worker/screens/job_seek_posts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _longTitle =
    'Çok uzun bir ilan başlığı: Taş fırın ustası ve hamur ustası aranıyor, '
    'gece vardiyası, sigortalı, yemek ve yol dahil, hemen başlanacak';
const _longCity = 'Afyonkarahisar';
const _longDistrict = 'Sandıklı Merkez Mahallesi Çok Uzun İlçe Adı';
const _longOwner =
    'Kahramanmaraş Geleneksel Taş Fırın ve Unlu Mamuller Sanayi Ticaret Ltd';

const _scales = <double>[1.0, 1.3, 1.5];

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

class _FixedMarketRepo extends LocalMarketListingRepository {
  _FixedMarketRepo(this.existing);
  final MarketListing? existing;

  @override
  Future<MarketListing?> getListing(String id) async => existing;
}

MarketListing _longMarketListing({bool withContact = true}) => MarketListing(
  id: 'm1',
  ownerId: 'owner-1',
  title: _longTitle,
  category: 'devren_firin',
  listingType: 'bakery_transfer',
  city: _longCity,
  district: _longDistrict,
  transferPrice: 12500000,
  rentPrice: 85000,
  negotiable: true,
  areaM2: 240,
  hasLicense: true,
  description: 'Açıklama ' * 40,
  authorName: _longOwner,
  contactPreference: withContact ? 'phone' : 'in_app',
  contactPhone: withContact ? '05321234567' : null,
  contactWhatsapp: withContact ? '05321234567' : null,
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

/// Dar ekran + yazı ölçeği. [child] tam ekran (Scaffold'lu) olabilir.
Future<void> _pumpScaled(
  WidgetTester tester,
  Widget child, {
  required double scale,
  List<Override> overrides = const [],
  Size size = const Size(320, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        builder: (ctx, w) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Widget _scroll(Widget child) => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  ),
);

void main() {
  group('320px × 1.0/1.3/1.5 — taşma yok', () {
    for (final s in _scales) {
      testWidgets('iş kartı (personel aranıyor) uzun alanlar @${s}x', (
        tester,
      ) async {
        await _pumpScaled(
          tester,
          _scroll(
            JobOpportunityCard(
              kind: JobListingKind.hiring,
              title: _longTitle,
              keyFact: '₺ 125.000 – 180.000',
              location: '$_longCity · $_longDistrict',
              owner: _longOwner,
              timeLabel: '12 dk önce',
              tags: const ['Tecrübe şartı aranmaz', 'Vardiyalı (gece)'],
              onMore: () {},
              onApply: () {},
              applyLabel: offerPrimaryCtaLabel,
              secondaryAction: const ListingPhoneCta(
                phone: '05321234567',
                compact: true,
              ),
            ),
          ),
          scale: s,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('market kartı görselsiz uzun alanlar @${s}x', (tester) async {
        await _pumpScaled(
          tester,
          _scroll(
            MarketplaceListingCard(
              listing: _longMarketListing(),
              onTap: () {},
              onToggleSave: () {},
            ),
          ),
          scale: s,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('iş ilanı detay görünümü @${s}x', (tester) async {
        await _pumpScaled(
          tester,
          Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: JobListingDetailView(
                kind: JobListingKind.hiring,
                title: _longTitle,
                keyFact: '₺ 125.000 – 180.000',
                location: '$_longCity · $_longDistrict',
                ownerName: _longOwner,
                rows: const [
                  MapEntry(AppStrings.listingsDetailRole, 'Usta Fırıncı'),
                  MapEntry(AppStrings.listingsDetailShift, 'Gece vardiyası'),
                ],
                description: 'Açıklama ' * 60,
                createdAt: DateTime(2026, 9, 1),
                expiresAt: DateTime(2026, 10, 1),
                primaryLabel: offerPrimaryCtaLabel,
                onPrimary: () {},
                phone: '05321234567',
              ),
            ),
          ),
          scale: s,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('market detay ekranı (ziyaretçi) @${s}x', (tester) async {
        await _pumpScaled(
          tester,
          const MarketplaceDetailScreen(listingId: 'm1'),
          scale: s,
          overrides: [
            currentAuthUserProvider.overrideWith((_) => null),
            marketListingRepositoryProvider.overrideWith(
              (ref) => _FixedMarketRepo(_longMarketListing()),
            ),
          ],
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.text(_longTitle), findsOneWidget);
      });

      testWidgets('market ilan formu (yeni, fırın devri) @${s}x', (
        tester,
      ) async {
        await _pumpScaled(
          tester,
          const MarketListingFormScreen(initialListingType: 'bakery_transfer'),
          scale: s,
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _SeededProfileController(ref, _individualProfile),
            ),
            marketListingRepositoryProvider.overrideWith(
              (ref) => _FixedMarketRepo(null),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.listingsSectionBasics), findsOneWidget);
      });

      testWidgets('personel ilanı formu @${s}x', (tester) async {
        await _pumpScaled(
          tester,
          const JobOfferFormScreen(),
          scale: s,
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _SeededProfileController(ref, _commercialProfile),
            ),
            currentAuthUserProvider.overrideWith((_) => null),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.listingsSectionSalary), findsOneWidget);
      });

      testWidgets('iş arıyorum formu @${s}x', (tester) async {
        await _pumpScaled(
          tester,
          const JobSeekPostFormScreen(),
          scale: s,
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _SeededProfileController(ref, _individualProfile),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.listingsSectionBasics), findsOneWidget);
      });
    }
  });

  group('Görselsiz market kartı', () {
    testWidgets('ortak "görsel yok" durumu + tür ikonu; kırık ikon yok', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketplaceListingCard(
              listing: const MarketListing(
                id: 'm2',
                title: 'Spiral mikser',
                category: 'ekipman',
              ),
              onTap: () {},
              onToggleSave: () {},
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('market_card_no_photo')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('app_image_empty')), findsOneWidget);
      expect(find.text(AppStrings.listingsNoPhoto), findsOneWidget);
      expect(find.byIcon(Icons.kitchen_outlined), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(find.byIcon(Icons.broken_image), findsNothing);
      // Kaydet: 44px dokunma alanı + tooltip.
      final save = tester.getSize(
        find.byKey(const ValueKey('market_card_save')),
      );
      expect(save.width, greaterThanOrEqualTo(44));
      expect(save.height, greaterThanOrEqualTo(44));
      expect(find.byTooltip(AppStrings.listingsSaveTooltip), findsOneWidget);
    });
  });

  group('Kart ↔ detay birincil CTA aynı', () {
    final offer = JobOfferPost(
      id: 'o1',
      ownerId: 'other',
      title: 'Ekmek ustası aranıyor',
      roleTitle: 'Usta Fırıncı',
      city: 'Konya',
      salaryMin: 30000,
      authorName: 'Konya Fırını',
      createdAt: DateTime.now(),
    );
    final seek = JobSeekPost(
      id: 's1',
      ownerId: 'other',
      title: 'Hamur ustası iş arıyor',
      city: 'Konya',
      createdAt: DateTime.now(),
    );

    Future<void> pumpJobs(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _SeededProfileController(ref, _commercialProfile),
            ),
            currentAuthUserProvider.overrideWith((_) => null),
            activeJobOffersProvider.overrideWith((ref) async => [offer]),
            activeJobSeekPostsProvider.overrideWith((ref) async => [seek]),
          ],
          child: const MaterialApp(home: JobsScreen(embedded: true)),
        ),
      );
      await tester.pumpAndSettle();
    }

    String primaryLabelInDetail(WidgetTester tester) {
      final btn = find.byKey(const ValueKey('job_detail_primary'));
      expect(btn, findsOneWidget);
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: btn, matching: find.byType(Text)),
          )
          .map((t) => t.data)
          .toList();
      return texts.single!;
    }

    testWidgets('personel ilanı: kart "Başvur" = detay "Başvur"', (
      tester,
    ) async {
      await pumpJobs(tester);
      expect(find.text(offerPrimaryCtaLabel), findsOneWidget);
      expect(find.byKey(const ValueKey('job_badge_hiring')), findsOneWidget);
      await tester.tap(find.text('Ekmek ustası aranıyor'));
      await tester.pumpAndSettle();
      expect(primaryLabelInDetail(tester), offerPrimaryCtaLabel);
      expect(offerPrimaryCtaLabel, AppStrings.jobsApply);
    });

    testWidgets('iş arayan: kart "Mesaj gönder" = detay "Mesaj gönder"; '
        '"İletişime geç" yok', (tester) async {
      await pumpJobs(tester);
      await tester.tap(find.text(AppStrings.jobsSegLooking));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('job_badge_seeking')), findsOneWidget);
      expect(find.text(seekPrimaryCtaLabel), findsOneWidget);
      expect(find.text(AppStrings.jobsContact), findsNothing);
      await tester.tap(find.text('Hamur ustası iş arıyor'));
      await tester.pumpAndSettle();
      expect(primaryLabelInDetail(tester), seekPrimaryCtaLabel);
      expect(seekPrimaryCtaLabel, 'Mesaj gönder');
      expect(find.text(AppStrings.jobsContact), findsNothing);
    });

    testWidgets('market: detayda tek birincil CTA "Mesaj gönder"; "Ara" '
        'ikincil (outlined)', (tester) async {
      await _pumpScaled(
        tester,
        const MarketplaceDetailScreen(listingId: 'm1'),
        scale: 1.0,
        size: const Size(400, 1200),
        overrides: [
          currentAuthUserProvider.overrideWith((_) => null),
          marketListingRepositoryProvider.overrideWith(
            (ref) => _FixedMarketRepo(_longMarketListing()),
          ),
        ],
      );
      await tester.pumpAndSettle();
      final primary = find.byKey(const ValueKey('market_detail_primary'));
      expect(primary, findsOneWidget);
      expect(
        find.descendant(of: primary, matching: find.text('Mesaj gönder')),
        findsOneWidget,
      );
      // Panelde tek dolu (birincil) düğme.
      expect(find.byWidgetPredicate((w) => w is FilledButton), findsOneWidget);
      final call = find.byKey(const ValueKey('market_detail_call'));
      expect(
        find.ancestor(
          of: find.text('Ara'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
        findsWidgets,
      );
      expect(call, findsOneWidget);
    });
  });

  group('Detay boş alanları gizler', () {
    testWidgets('market detay: açıklama/detay bölümü yoksa çizilmez; "—" yok', (
      tester,
    ) async {
      await _pumpScaled(
        tester,
        const MarketplaceDetailScreen(listingId: 'm9'),
        scale: 1.0,
        size: const Size(400, 1200),
        overrides: [
          currentAuthUserProvider.overrideWith((_) => null),
          marketListingRepositoryProvider.overrideWith(
            (ref) => _FixedMarketRepo(
              const MarketListing(
                id: 'm9',
                ownerId: 'o9',
                title: 'Sade ilan',
                category: 'ekipman',
                contactPreference: 'in_app',
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Sade ilan'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(find.text('Detay belirtilmemiş.'), findsNothing);
      expect(find.text(AppStrings.marketDetailDescription), findsNothing);
      expect(find.text('null'), findsNothing);
    });

    testWidgets('iş detay: boş/"—" satırlar ve boş açıklama çizilmez', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: JobListingDetailView(
                kind: JobListingKind.seeking,
                title: 'Simitçi iş arıyor',
                keyFact: AppStrings.listingsSalaryNegotiable,
                keyFactIsFallback: true,
                rows: const [
                  MapEntry(AppStrings.listingsDetailProfession, ''),
                  MapEntry(AppStrings.listingsDetailExperience, '—'),
                  MapEntry(AppStrings.listingsDetailShift, 'null'),
                ],
                description: '   ',
              ),
            ),
          ),
        ),
      );
      expect(find.text('—'), findsNothing);
      expect(find.text('null'), findsNothing);
      expect(find.text(AppStrings.listingsDetailProfession), findsNothing);
      expect(find.text(AppStrings.listingsSectionDetails), findsNothing);
      expect(find.text(AppStrings.listingsDetailDescription), findsNothing);
      expect(find.byKey(const ValueKey('job_detail_owner')), findsNothing);
      expect(find.byKey(const ValueKey('job_detail_primary')), findsNothing);
      // Kapat: ≥ 48px dokunma alanı + tooltip.
      expect(find.byTooltip(AppStrings.listingsCloseTooltip), findsOneWidget);
      final close = tester.getSize(
        find.byKey(const ValueKey('job_detail_close')),
      );
      expect(close.height, greaterThanOrEqualTo(48));
    });
  });

  group('Tür rozetleri ayrışır', () {
    testWidgets('PERSONEL ARANIYOR ≠ İŞ ARIYOR (aynı rozet boyutu)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                JobKindBadge(kind: JobListingKind.hiring),
                JobKindBadge(kind: JobListingKind.seeking),
              ],
            ),
          ),
        ),
      );
      expect(find.text('PERSONEL ARANIYOR'), findsOneWidget);
      expect(find.text('İŞ ARIYOR'), findsOneWidget);
      final a = tester.widget<Text>(find.text('PERSONEL ARANIYOR'));
      final b = tester.widget<Text>(find.text('İŞ ARIYOR'));
      expect(a.style?.fontSize, b.style?.fontSize);
      expect(a.style?.color, isNot(b.style?.color));
      final ia = tester.getSize(find.byKey(const ValueKey('job_badge_hiring')));
      final ib = tester.getSize(
        find.byKey(const ValueKey('job_badge_seeking')),
      );
      expect(ia.height, ib.height);
    });
  });

  group('İlk yükleme iskeleti', () {
    testWidgets('iş ilanları: kart iskeleti, tek büyük spinner yok', (
      tester,
    ) async {
      final pending = Completer<List<JobOfferPost>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _SeededProfileController(ref, _commercialProfile),
            ),
            currentAuthUserProvider.overrideWith((_) => null),
            activeJobOffersProvider.overrideWith((ref) => pending.future),
          ],
          child: const MaterialApp(home: JobsScreen(embedded: true)),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('listing_skeleton')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('market ilanları: görselli kart iskeleti', (tester) async {
      final pending = Completer<List<MarketListing>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAuthUserProvider.overrideWith((_) => null),
            filteredMarketListingsProvider.overrideWith(
              (ref, MarketFilters f) => pending.future,
            ),
          ],
          child: const MaterialApp(
            home: MarketplaceScreen(
              embedded: true,
              forceListingType: 'equipment_sale',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('listing_skeleton')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('Silme onayı ortak dialogla', () {
    testWidgets('iş arıyorum ilanım: Sil → app_confirm_dialog (yıkıcı)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _SeededProfileController(ref, _individualProfile),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: JobSeekPostCard(
                post: JobSeekPost(id: 'p1', title: 'Fırıncı arıyorum'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip(AppStrings.listingsDeleteTooltip));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app_confirm_dialog')), findsOneWidget);
      expect(find.text(AppStrings.listingsDeleteConfirmBody), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('app_confirm_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app_confirm_dialog')), findsNothing);
    });

    testWidgets('market ilanım: ⋮ → İlanı sil → app_confirm_dialog', (
      tester,
    ) async {
      await _pumpScaled(
        tester,
        const MarketplaceDetailScreen(listingId: 'm1'),
        scale: 1.0,
        size: const Size(400, 1200),
        overrides: [
          currentAuthUserProvider.overrideWith(
            (_) => const AuthUser(id: 'owner-1', email: 'o@x.co'),
          ),
          marketListingRepositoryProvider.overrideWith(
            (ref) => _FixedMarketRepo(_longMarketListing()),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('market_owner_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İlanı sil'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app_confirm_dialog')), findsOneWidget);
      expect(find.text(AppStrings.listingsDeleteConfirmTitle), findsOneWidget);
    });
  });
}
