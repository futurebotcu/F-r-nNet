// FırınNet Market V1 M2 — UI source-level kontrolleri.
//
// V1 sprint pattern (market_v1_schema_and_repo_test.dart): UI dosyalarını
// String olarak okuyup invariants doğrula. ToBuildAndPump cost'u olmadan
// regressionları yakalar (composer/story sprint dersi).
//
// Doğrulananlar:
//   * marketplace_screen.dart — filteredMarketListingsProvider + filter sheet
//     push + detail navigation.
//   * marketplace_listing_card.dart — image + type badge + save toggle + title.
//   * marketplace_image_gallery.dart — PageView + fullscreen + dot indicator.
//   * marketplace_detail_screen.dart — body sections (gallery + info +
//     description + attributes + owner) + contact panel + owner ⋮ menu.
//   * marketplace_filters_sheet.dart — showModalBottomSheet + listing_type
//     chips + price range + apply CTA.
//   * marketplace_contact_panel.dart — phone/whatsapp/save/share + url_launcher.
//   * market_listing_form_screen.dart — photos picker + listing_type 2-value +
//     equipment/transfer conditional fields + sticky publish CTA.
//   * app_router.dart — /market/listings/:id route bağlı.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M2 — MarketplaceScreen UI', () {
    late String src;
    setUpAll(() {
      src =
          File('lib/features/marketplace/screens/marketplace_screen.dart')
              .readAsStringSync();
    });

    test('filteredMarketListingsProvider kullanır + filter UI bağlı', () {
      expect(src.contains('filteredMarketListingsProvider'), isTrue);
      expect(src.contains('MarketplaceFiltersSheet'), isTrue,
          reason: 'Filter sheet açılabilmeli');
      expect(src.contains('MarketplaceListingCard'), isTrue,
          reason: 'Yeni listing card render edilmeli');
    });

    test('Detail navigation /market/listings/:id push eder', () {
      expect(src.contains("'/market/listings/\${l.id}'"), isTrue,
          reason: 'Card tap detail route\'a push etmeli');
    });

    test('Listing_type chip row + active filter chip row', () {
      expect(src.contains('_ListingTypeChipRow'), isTrue);
      expect(src.contains('_ActiveFilterChipRow'), isTrue);
    });

    test('İlan ekleme CTA marketListingNew route\'una gider', () {
      expect(src.contains('AppRoutes.marketListingNew'), isTrue);
    });
  });

  group('M2 — MarketplaceListingCard', () {
    late String src;
    setUpAll(() {
      src = File(
              'lib/features/marketplace/widgets/marketplace_listing_card.dart')
          .readAsStringSync();
    });

    test('AspectRatio 4:3 görsel + CachedNetworkImage + placeholder', () {
      expect(src.contains('AspectRatio'), isTrue);
      expect(src.contains('CachedNetworkImage'), isTrue);
      expect(src.contains('_PlaceholderArt'), isTrue);
    });

    test('Type badge + bookmark save toggle', () {
      expect(src.contains('_TypeBadge'), isTrue);
      expect(src.contains('Icons.bookmark_rounded'), isTrue);
      expect(src.contains('Icons.bookmark_border_rounded'), isTrue);
    });

    test('Bakery transfer için devir/kira variant fiyatı', () {
      expect(src.contains('isBakeryTransfer'), isTrue);
      expect(src.contains('transferPrice'), isTrue);
      expect(src.contains('rentPrice'), isTrue);
    });
  });

  group('M2 — MarketplaceImageGallery', () {
    late String src;
    setUpAll(() {
      src = File(
              'lib/features/marketplace/widgets/marketplace_image_gallery.dart')
          .readAsStringSync();
    });

    test('PageView + dot indicator + fullscreen InteractiveViewer', () {
      expect(src.contains('PageView'), isTrue);
      expect(src.contains('InteractiveViewer'), isTrue);
    });
  });

  group('M2 — MarketplaceDetailScreen', () {
    late String src;
    setUpAll(() {
      src = File(
              'lib/features/marketplace/screens/marketplace_detail_screen.dart')
          .readAsStringSync();
    });

    test('Gallery + InfoSection + Description + Attributes + Owner', () {
      expect(src.contains('MarketplaceImageGallery'), isTrue);
      expect(src.contains('_InfoSection'), isTrue);
      expect(src.contains('marketDetailDescription'), isTrue);
      expect(src.contains('_AttributesGrid'), isTrue);
      expect(src.contains('_OwnerSection'), isTrue);
    });

    test('Contact panel sticky bottomNavigationBar olarak monte', () {
      expect(src.contains('bottomNavigationBar'), isTrue);
      expect(src.contains('MarketplaceContactPanel'), isTrue);
    });

    test('Owner menü: Düzenle / pause / sold / delete', () {
      expect(src.contains("case 'edit':"), isTrue);
      expect(src.contains("case 'pause':"), isTrue);
      expect(src.contains("case 'sold':"), isTrue);
      expect(src.contains("case 'delete':"), isTrue);
      expect(src.contains('softDeleteListing'), isTrue);
      expect(src.contains("setStatus(l.id!, 'paused')"), isTrue);
      expect(src.contains("setStatus(l.id!, 'sold')"), isTrue);
    });

    test('Owner profile push /u/:userId sosyal route\'a', () {
      expect(src.contains('AppRoutes.userPublicProfile'), isTrue);
    });
  });

  group('M2 — MarketplaceFiltersSheet', () {
    late String src;
    setUpAll(() {
      src = File(
              'lib/features/marketplace/widgets/marketplace_filters_sheet.dart')
          .readAsStringSync();
    });

    test('showModalBottomSheet<MarketFilters> + Apply CTA', () {
      expect(src.contains('showModalBottomSheet<MarketFilters>'), isTrue);
      expect(src.contains('marketFilterApply'), isTrue);
      expect(src.contains('marketFilterClearAll'), isTrue);
    });

    test('Listing type chips + conditional equipment_category', () {
      // V1 M2 controlled-data fix sonrası: AppStrings.marketListingTypeLabels
      // yerine MarketplaceTaxonomy.listingTypes; equipment kategori conditional
      // listingTypeEquipmentSale sabitiyle eşleşir.
      expect(src.contains('MarketplaceTaxonomy.listingTypes'), isTrue);
      expect(
          src.contains('MarketplaceTaxonomy.listingTypeEquipmentSale'), isTrue,
          reason: 'Equipment kategorisi sadece equipment_sale seçilince');
      expect(src.contains('MarketplaceTaxonomy.equipmentCategories'), isTrue);
    });

    test('Price range min/max + condition + negotiable', () {
      expect(src.contains('marketFilterMinPrice'), isTrue);
      expect(src.contains('marketFilterMaxPrice'), isTrue);
      expect(src.contains('MarketplaceTaxonomy.conditions'), isTrue);
      expect(src.contains('marketFilterNegotiable'), isTrue);
    });
  });

  group('M2 — MarketplaceContactPanel', () {
    late String src;
    setUpAll(() {
      src = File(
              'lib/features/marketplace/widgets/marketplace_contact_panel.dart')
          .readAsStringSync();
    });

    test('Phone (tel:) + WhatsApp (wa.me) + url_launcher', () {
      expect(src.contains("scheme: 'tel'"), isTrue);
      expect(src.contains('https://wa.me/'), isTrue);
      expect(src.contains("import 'package:url_launcher/url_launcher.dart'"),
          isTrue);
    });

    test('Save / Share / In-app message CTA', () {
      expect(src.contains('marketContactSaveCta'), isTrue);
      expect(src.contains('marketContactShareCta'), isTrue);
      expect(src.contains('marketContactInApp'), isTrue);
      expect(src.contains('share_plus'), isTrue);
    });
  });

  group('M2 — MarketListingFormScreen genişletme', () {
    late String src;
    setUpAll(() {
      src = File(
              'lib/features/marketplace/screens/market_listing_form_screen.dart')
          .readAsStringSync();
    });

    test('Photos picker (galeri + kamera) + max 6', () {
      expect(src.contains('image_picker'), isTrue);
      expect(src.contains('ImageSource.gallery'), isTrue);
      expect(src.contains('ImageSource.camera'), isTrue);
      expect(src.contains('_maxPhotos = 6'), isTrue);
      expect(src.contains('uploadListingImage'), isTrue);
    });

    test('Default listing_type equipment_sale (product YOK)', () {
      // V1 M2 controlled-data fix sonrası: default değer taxonomy
      // sabitinden gelir; literal 'equipment_sale' yerine
      // MarketplaceTaxonomy.defaultListingType kullanılır.
      expect(src.contains('MarketplaceTaxonomy.defaultListingType'), isTrue);
      // V1 M1 narrowing — kodda artık 'product' atama/değer literal'ı yok.
      final codeOnly = src
          .split('\n')
          .map((l) => l.trimLeft())
          .where((l) => !l.startsWith('//'))
          .join('\n');
      expect(codeOnly.contains("'product'"), isFalse,
          reason: 'V1 M1 narrowing — product literal kodda artık geçersiz');
    });

    test('Equipment-conditional alanlar + bakery_transfer-conditional alanlar',
        () {
      expect(src.contains('if (isEquip)'), isTrue);
      expect(src.contains('if (isTransfer)'), isTrue);
      expect(src.contains('marketListingFieldBrand'), isTrue);
      expect(src.contains('marketListingFieldModel'), isTrue);
      expect(src.contains('marketListingFieldYear'), isTrue);
      expect(src.contains('marketListingFieldRentPrice'), isTrue);
      expect(src.contains('marketListingFieldTransferPrice'), isTrue);
      expect(src.contains('marketListingFieldAreaM2'), isTrue);
    });

    test('Sticky publish CTA bottomNavigationBar + negotiable + contact', () {
      expect(src.contains('bottomNavigationBar: SafeArea'), isTrue);
      expect(src.contains('marketListingPublishCta'), isTrue);
      expect(src.contains('marketListingFieldNegotiable'), isTrue);
      expect(src.contains('marketListingFieldContactPhone'), isTrue);
      expect(src.contains('marketListingFieldContactWhatsapp'), isTrue);
      // V1 M2 controlled-data fix: default value taxonomy sabitinden gelir.
      expect(src.contains('MarketplaceTaxonomy.defaultContactPreference'),
          isTrue);
    });
  });

  group('M2 — AppShell exposure', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/dashboard/screens/app_shell.dart')
          .readAsStringSync();
    });
    test('Market AppShell._tabs içinde ve label "Market"', () {
      expect(src.contains('AppRoutes.market'), isTrue,
          reason: 'Market tab ana bottom nav\'da görünmeli');
      expect(src.contains("label: 'Market'"), isTrue);
      expect(src.contains('Icons.storefront_outlined'), isTrue);
    });
  });

  group('M2 — Router detail route', () {
    late String src;
    setUpAll(() {
      src = File('lib/app/router/app_router.dart').readAsStringSync();
    });

    test('/market/listings/:id detail route + MarketplaceDetailScreen', () {
      expect(src.contains('MarketplaceDetailScreen'), isTrue);
      expect(src.contains("'/market/listings/:id'"), isTrue);
      expect(src.contains('marketListingDetail'), isTrue);
    });
  });

  group('M2 — pubspec url_launcher', () {
    test('url_launcher dependency tanımlı', () {
      final ps = File('pubspec.yaml').readAsStringSync();
      expect(ps.contains('url_launcher:'), isTrue);
    });
  });

  group('M2 — AppStrings yeni sabitler', () {
    test('marketListingTypeLabels yalnız equipment_sale + bakery_transfer', () {
      expect(AppStrings.marketListingTypeLabels.keys.toSet(),
          {'equipment_sale', 'bakery_transfer'});
    });
    test('marketEquipmentCategoryLabels mevcut 8 kategori', () {
      expect(AppStrings.marketEquipmentCategoryLabels.length, 8);
    });
    test('marketConditionLabels: refurbished (as_is değil)', () {
      expect(AppStrings.marketConditionLabels.containsKey('refurbished'),
          isTrue);
      expect(AppStrings.marketConditionLabels.containsKey('as_is'), isFalse);
    });
    test('Filter / contact / attribute / form sabitleri tanımlı', () {
      expect(AppStrings.marketFilterApply, isNotEmpty);
      expect(AppStrings.marketFilterClearAll, isNotEmpty);
      expect(AppStrings.marketContactInApp, isNotEmpty);
      expect(AppStrings.marketContactWhatsapp, isNotEmpty);
      expect(AppStrings.marketAttrTransferPrice, isNotEmpty);
      expect(AppStrings.marketAttrRentPrice, isNotEmpty);
      expect(AppStrings.marketListingPublishCta, isNotEmpty);
      expect(AppStrings.marketListingPhotoMaxHint, isNotEmpty);
    });
  });
}
