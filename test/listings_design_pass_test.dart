// İlanlar tasarım geçişi — widget + birim testleri.
//
//   * İş ilanı kartı: "PERSONEL ARANIYOR" / "İŞ ARIYOR" tür rozetleri ayrışır.
//   * 320px + 1.3x yazı ölçeğinde uzun başlık/şehir/sahip → taşma yok
//     (iş kartı + market kartı).
//   * Görselsiz market kartı → "Fotoğraf yok" yer tutucusu.
//   * Tek fiyat biçimleyici: TRY/EUR/USD sembol + binlik ayıraç + giriş
//     ayrıştırma.
//   * Ödeme bekleyen ilan kaydı → "Ödeme sonrası yayınlanır" (yalan "yayında"
//     yok) — birim + iş ilanı formu widget akışı.
//   * Süresi dolmuş/bilinmeyen durumdaki ilan düzenleme formu çökmez.
//   * Sahip durum şeridi insan dili gösterir (ham enum değil).

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/data/firinnet_taxonomy.dart';
import 'package:firin_defter/core/widgets/premium/job_opportunity_card.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/jobs/models/job_offer_post.dart';
import 'package:firin_defter/features/jobs/providers/job_offer_providers.dart';
import 'package:firin_defter/features/jobs/repositories/local_job_offer_repository.dart';
import 'package:firin_defter/features/jobs/screens/job_offer_form_screen.dart';
import 'package:firin_defter/features/listings/utils/listing_format.dart';
import 'package:firin_defter/features/marketplace/models/market_listing.dart';
import 'package:firin_defter/features/marketplace/providers/market_listing_providers.dart';
import 'package:firin_defter/features/marketplace/repositories/local_market_listing_repository.dart';
import 'package:firin_defter/features/marketplace/screens/market_listing_form_screen.dart';
import 'package:firin_defter/features/marketplace/screens/marketplace_detail_screen.dart';
import 'package:firin_defter/features/marketplace/widgets/marketplace_listing_card.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _longTitle =
    'Çok uzun bir ilan başlığı: Taş fırın ustası ve hamur ustası aranıyor, '
    'gece vardiyası, sigortalı, yemek ve yol dahil, hemen başlanacak';
const _longCity = 'Afyonkarahisar · Sandıklı Merkez Mahallesi Uzun İlçe Adı';
const _longOwner =
    'Kahramanmaraş Geleneksel Taş Fırın ve Unlu Mamuller Sanayi Ticaret Ltd';

Future<void> _pumpNarrow(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 1400),
          textScaler: TextScaler.linear(1.3),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('JobOpportunityCard — tür rozeti', () {
    testWidgets('personel arayan ve iş arayan kartları farklı rozet taşır',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                JobOpportunityCard(
                  kind: JobListingKind.hiring,
                  title: 'Ekmek ustası aranıyor',
                  keyFact: '₺ 30.000',
                ),
                JobOpportunityCard(
                  kind: JobListingKind.seeking,
                  title: 'Hamur ustası iş arıyor',
                  keyFact: AppStrings.listingsSalaryNegotiable,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('PERSONEL ARANIYOR'), findsOneWidget);
      expect(find.text('İŞ ARIYOR'), findsOneWidget);
      expect(find.byKey(const ValueKey('job_badge_hiring')), findsOneWidget);
      expect(find.byKey(const ValueKey('job_badge_seeking')), findsOneWidget);
      expect(find.byIcon(Icons.work_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_search_outlined), findsOneWidget);
      // Eski "Aktif" gürültüsü kalktı.
      expect(find.text(AppStrings.jobsCardBadgeActive), findsNothing);
    });

    testWidgets('boş etiketler render edilmez ("—" yok)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JobOpportunityCard(
              kind: JobListingKind.seeking,
              title: 'Simitçi',
              keyFact: AppStrings.listingsSalaryNegotiable,
              tags: ['', '  ', '3 yıl tecrübe'],
            ),
          ),
        ),
      );
      expect(find.text('—'), findsNothing);
      expect(find.text('3 yıl tecrübe'), findsOneWidget);
    });
  });

  group('320px + 1.3x yazı ölçeği — taşma yok', () {
    testWidgets('iş kartı: uzun başlık/şehir/sahip + CTA + ikincil aksiyon',
        (tester) async {
      await _pumpNarrow(
        tester,
        JobOpportunityCard(
          kind: JobListingKind.hiring,
          title: _longTitle,
          keyFact: '₺ 125.000 – 180.000',
          location: _longCity,
          owner: _longOwner,
          timeLabel: '12 dk önce',
          tags: const [
            'Tecrübe şartı aranmaz, öğretilecek',
            'Vardiyalı (gece ağırlıklı)',
          ],
          statusBadge: const Text(AppStrings.listingFeePendingBadge),
          onMore: () {},
          onApply: () {},
          applyLabel: AppStrings.jobsApply,
          secondaryAction: OutlinedButton(
            onPressed: () {},
            child: const Text('Ara'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Çok uzun bir ilan'), findsOneWidget);
    });

    testWidgets('market kartı: uzun başlık/şehir/sahip, görselsiz',
        (tester) async {
      await _pumpNarrow(
        tester,
        MarketplaceListingCard(
          listing: MarketListing(
            id: 'm1',
            ownerId: 'u1',
            title: _longTitle,
            category: 'devren_firin',
            listingType: 'bakery_transfer',
            city: _longCity,
            district: 'Çok Uzun Bir İlçe Adı Daha',
            transferPrice: 12500000,
            negotiable: true,
            authorName: _longOwner,
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          onTap: () {},
          onToggleSave: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Market kartı — görselsiz yer tutucu', () {
    testWidgets('fotoğrafsız ilan "Fotoğraf yok" gösterir + fiyat yoksa '
        '"Fiyat sorunuz"', (tester) async {
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
              onToggleSave: null,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('market_card_no_photo')), findsOneWidget);
      expect(find.text(AppStrings.listingsNoPhoto), findsOneWidget);
      expect(find.text(AppStrings.finalListingsPriceAsk), findsOneWidget);
      final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ratio.aspectRatio, closeTo(16 / 9, 0.001));
    });
  });

  group('ListingFormat — tek fiyat biçimleyici', () {
    test('para birimi sembolü + binlik ayıraç', () {
      expect(ListingFormat.price(25000), '₺ 25.000');
      expect(ListingFormat.price(25000, currency: 'TRY'), '₺ 25.000');
      expect(ListingFormat.price(1200, currency: 'EUR'), '€ 1.200');
      expect(ListingFormat.price(950000, currency: 'USD'), r'$ 950.000');
      expect(ListingFormat.price(12.5), '₺ 12,5');
      expect(ListingFormat.currencySymbol(null), '₺');
      expect(ListingFormat.currencySymbol('xyz'), '₺');
    });

    test('ücret aralığı', () {
      expect(ListingFormat.priceRange(25000, 30000), '₺ 25.000 – 30.000');
      expect(ListingFormat.priceRange(null, 30000), '₺ 30.000');
      expect(ListingFormat.priceRange(30000, 30000), '₺ 30.000');
      expect(ListingFormat.priceRange(null, null), isNull);
      expect(ListingFormat.priceRange(0, 0), isNull);
    });

    test('form girişi doğru ayrışır ("25.000" → 25000)', () {
      expect(ListingFormat.parseAmount('25.000'), 25000);
      expect(ListingFormat.parseAmount('12,5'), 12.5);
      expect(ListingFormat.parseAmount('  '), isNull);
      expect(ListingFormat.editText(25000), '25000');
      expect(ListingFormat.editText(12.5), '12,5');
    });

    test('market kartı fiyatı ilan para birimini kullanır', () {
      const eur = MarketListing(
        title: 'Fırın',
        category: 'ekipman',
        price: 1200,
        currency: 'EUR',
        unit: 'adet',
      );
      expect(MarketplaceListingCard.priceLabel(eur), '€ 1.200 / adet');
      const transfer = MarketListing(
        title: 'Devren fırın',
        category: 'devren_firin',
        listingType: 'bakery_transfer',
        transferPrice: 850000,
      );
      expect(
        MarketplaceListingCard.priceLabel(transfer),
        '₺ 850.000 ${AppStrings.listingsPriceTransferSuffix}',
      );
    });
  });

  group('Kayıt geri bildirimi — ödeme bekleyen ilan', () {
    test('listingSavedMessage pending → "Ödeme sonrası yayınlanır"', () {
      expect(
        listingSavedMessage(isEdit: false, isPendingPayment: true),
        AppStrings.listingsSavedPendingPayment,
      );
      expect(
        listingSavedMessage(isEdit: false, isPendingPayment: false),
        AppStrings.listingsPublished,
      );
      expect(
        listingSavedMessage(isEdit: true, isPendingPayment: false),
        AppStrings.listingsUpdated,
      );
    });

    testWidgets('iş ilanı formu: pending kayıt "yayında" demez',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('HOME')),
          ),
          GoRoute(
            path: '/new',
            builder: (_, __) => const JobOfferFormScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _SeededProfileController(ref, _commercialProfile),
            ),
            currentAuthUserProvider.overrideWith((_) => null),
            jobOfferRepositoryProvider.overrideWith(
              (ref) => _PendingJobOfferRepo(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/new');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.jobOfferFieldTitle),
        'Ekmek Ustası Aranıyor',
      );
      final firstProf = FirinnetTaxonomy.professions.values.first;
      await tester.ensureVisible(find.text(firstProf));
      await tester.pumpAndSettle();
      await tester.tap(find.text(firstProf));
      await tester.pumpAndSettle();
      final save = find.text(AppStrings.jobOfferFormSaveCta);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.listingsSavedPendingPayment), findsOneWidget);
      expect(find.text(AppStrings.listingsPublished), findsNothing);
      expect(find.text(AppStrings.jobOfferSavedSnack), findsNothing);
    });
  });

  group('Market formu — durum + segment tipi', () {
    Future<void> pumpForm(
      WidgetTester tester,
      Widget form, {
      MarketListing? existing,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              (ref) => _SeededProfileController(ref, _individualProfile),
            ),
            marketListingRepositoryProvider.overrideWith(
              (ref) => _FixedMarketRepo(existing),
            ),
          ],
          child: MaterialApp(home: form),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('süresi dolmuş ilanın düzenleme formu çökmez', (tester) async {
      await pumpForm(
        tester,
        const MarketListingFormScreen(listingId: 'exp1'),
        existing: const MarketListing(
          id: 'exp1',
          title: 'Eski mikser',
          category: 'ekipman',
          status: 'expired',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.listingsStatusExpired), findsOneWidget);
      // Düzenlemede CTA "Güncelle".
      expect(find.text(AppStrings.listingsUpdateCta), findsOneWidget);
      expect(find.text(AppStrings.marketListingPublishCta), findsNothing);
    });

    testWidgets('bilinmeyen durum güvenli değere düşer (assert yok)',
        (tester) async {
      await pumpForm(
        tester,
        const MarketListingFormScreen(listingId: 'odd1'),
        existing: const MarketListing(
          id: 'odd1',
          title: 'Garip durum',
          category: 'ekipman',
          status: 'archived_unknown',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.listingsStatusPaused), findsOneWidget);
    });

    testWidgets('İş yeri segmentinden açılan form Fırın devri ile gelir; '
        'eski "Kategori" alanı yok', (tester) async {
      await pumpForm(
        tester,
        const MarketListingFormScreen(initialListingType: 'bakery_transfer'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Fırın devri'), findsOneWidget);
      expect(
        find.widgetWithText(
          TextFormField,
          AppStrings.marketListingFieldTransferPrice,
        ),
        findsOneWidget,
      );
      expect(find.text(AppStrings.marketListingFieldCategory), findsNothing);
    });
  });

  group('Market detay — sahip durum şeridi', () {
    Future<void> pumpBanner(WidgetTester tester, MarketListing l) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: MarketOwnerStatusBanner(listing: l)),
          ),
        );

    testWidgets('duraklatılmış ilan insan dili gösterir', (tester) async {
      await pumpBanner(
        tester,
        const MarketListing(title: 'x', category: 'ekipman', status: 'paused'),
      );
      expect(find.text(AppStrings.listingsStatusPaused), findsOneWidget);
      expect(find.text('paused'), findsNothing);
    });

    testWidgets('ödeme bekleyen ilan "Ödeme bekliyor"', (tester) async {
      await pumpBanner(
        tester,
        const MarketListing(
          title: 'x',
          category: 'ekipman',
          feeStatus: 'pending',
        ),
      );
      expect(find.text(AppStrings.listingFeePendingBadge), findsOneWidget);
      expect(find.text('pending'), findsNothing);
    });

    test('durum çözümleme: sold / expired / bitiş tarihi geçmiş', () {
      expect(
        marketOwnerStatusOf(
          const MarketListing(title: 'x', category: 'e', status: 'sold'),
        ),
        MarketOwnerStatus.sold,
      );
      expect(
        marketOwnerStatusOf(
          const MarketListing(title: 'x', category: 'e', status: 'expired'),
        ),
        MarketOwnerStatus.expired,
      );
      expect(
        marketOwnerStatusOf(
          MarketListing(
            title: 'x',
            category: 'e',
            expiresAt: DateTime(2020),
          ),
        ),
        MarketOwnerStatus.expired,
      );
      expect(
        marketOwnerStatusOf(
          const MarketListing(title: 'x', category: 'e'),
        ),
        MarketOwnerStatus.active,
      );
    });
  });
}

// ────────────────────────────────────────────────────────────────────
// Yardımcılar
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

/// Server'ın ücretli ilanı `fee_status='pending'` döndürmesini taklit eder.
class _PendingJobOfferRepo extends LocalJobOfferRepository {
  @override
  Future<JobOfferPost> upsertOffer(JobOfferPost post) async {
    final saved = await super.upsertOffer(post);
    return JobOfferPost.fromRow(<String, dynamic>{
      'id': saved.id,
      'title': saved.title,
      'role_title': saved.roleTitle,
      'fee_status': 'pending',
    });
  }
}

class _FixedMarketRepo extends LocalMarketListingRepository {
  _FixedMarketRepo(this.existing);
  final MarketListing? existing;

  @override
  Future<MarketListing?> getListing(String id) async => existing;
}
