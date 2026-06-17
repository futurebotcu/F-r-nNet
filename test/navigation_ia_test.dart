// Navigation IA Sprint — alt nav + sekme yapısı sözleşme/davranış testleri.
//
// Topluluk · Pazar · İlanlar · Mesajlar · Panel. Feed+Gruplar → Topluluk
// segmentleri; jobs+marketplace → İlanlar segmentleri; Pazar "Yakında";
// Mesajlar alt nav (unread badge); eski route'lar redirect ile korunur.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/premium/premium_bottom_nav.dart';
import 'package:firin_defter/features/community/screens/community_screen.dart';
import 'package:firin_defter/features/listings/screens/listings_screen.dart';
import 'package:firin_defter/features/marketplace/screens/pazar_coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('Alt nav — 5 tab + etiketler', () {
    late String shell;
    setUpAll(() {
      shell = _read('lib/features/dashboard/screens/app_shell.dart');
    });

    test('5 tab route: community · pazar · listings · messages · panel', () {
      for (final r in [
        'AppRoutes.community',
        'AppRoutes.pazar',
        'AppRoutes.listings',
        'AppRoutes.messages',
        'AppRoutes.panel',
      ]) {
        expect(shell.contains(r), isTrue, reason: '$r alt nav tab olmalı');
      }
    });

    test('nav etiketleri: Topluluk, Pazar, İlanlar, Mesajlar, Panel', () {
      expect(AppStrings.navCommunity, 'Topluluk');
      expect(AppStrings.navPazar, 'Pazar');
      expect(AppStrings.navListings, 'İlanlar');
      expect(AppStrings.navMessages, 'Mesajlar');
      expect(AppStrings.navPanel, 'Panel');
    });

    test('Mesajlar unread badge (totalUnreadMessagesProvider korunur)', () {
      expect(shell.contains('totalUnreadMessagesProvider'), isTrue);
      expect(shell.contains('badgeCount'), isTrue);
    });

    test('Pazar artık canlı B2B modülü → comingSoon rozeti yok', () {
      // B2B Pazar'a bağlandı: alt nav'da hiçbir tab "Yakında" rozeti taşımaz.
      expect(shell.contains('comingSoon'), isFalse);
    });
  });

  group('Router — yeni tablar + legacy redirect korunur', () {
    late String router;
    setUpAll(() {
      router = _read('lib/app/router/app_router.dart');
    });

    test('Shell yeni kapsayıcıları kullanır', () {
      expect(router.contains('CommunityScreen('), isTrue);
      expect(router.contains('ListingsScreen('), isTrue);
      // Pazar artık B2B native modül shell'i (PazarComingSoonScreen yerine).
      expect(router.contains('B2bShellScreen()'), isTrue);
      expect(router.contains('MessagesListScreen()'), isTrue);
    });

    test('/feed → /community redirect', () {
      final i = router.indexOf('path: AppRoutes.feed,');
      final body = router.substring(i, i + 140);
      expect(body.contains('redirect'), isTrue);
      expect(body.contains('AppRoutes.community'), isTrue);
    });

    test('/groups → /community?seg=groups redirect', () {
      final i = router.indexOf('path: AppRoutes.groups,');
      final body = router.substring(i, i + 160);
      expect(body.contains('redirect'), isTrue);
      expect(body.contains('seg=groups'), isTrue);
    });

    test('/jobs → /ilanlar, /market → /ilanlar?seg=isyeri redirect', () {
      final j = router.indexOf('path: AppRoutes.jobs,');
      expect(router.substring(j, j + 140).contains('AppRoutes.listings'),
          isTrue);
      final m = router.indexOf('path: AppRoutes.market,');
      expect(router.substring(m, m + 160).contains('seg=isyeri'), isTrue);
    });

    test('/messages/:id (ChatScreen) full-screen korunur', () {
      expect(router.contains("path: '/messages/:id'"), isTrue);
      expect(router.contains('ChatScreen('), isTrue);
    });

    test('Marketplace detail/form route\'ları korunur', () {
      expect(router.contains("'/market/listings/:id'"), isTrue);
      expect(router.contains('AppRoutes.marketListingNew'), isTrue);
    });
  });

  group('Embedded segment sözleşmeleri', () {
    test('SocialFeedPage + GroupsListScreen + JobsScreen embedded param', () {
      expect(
        _read('lib/features/social/feed/social_feed_page.dart')
            .contains('this.embedded = false'),
        isTrue,
      );
      expect(
        _read('lib/features/social_groups/screens/groups_list_screen.dart')
            .contains('this.embedded = false'),
        isTrue,
      );
      expect(
        _read('lib/features/jobs/screens/jobs_screen.dart')
            .contains('this.embedded = false'),
        isTrue,
      );
    });

    test('MarketplaceScreen embedded + forceListingType', () {
      final src =
          _read('lib/features/marketplace/screens/marketplace_screen.dart');
      expect(src.contains('this.embedded = false'), isTrue);
      expect(src.contains('this.forceListingType'), isTrue);
    });

    test('İlanlar İş yeri=bakery_transfer, Ekipman=equipment_sale', () {
      final src = _read('lib/features/listings/screens/listings_screen.dart');
      expect(src.contains('listingTypeBakeryTransfer'), isTrue);
      expect(src.contains('listingTypeEquipmentSale'), isTrue);
    });
  });

  group('Widget — yeni kapsayıcı ekranlar render olur', () {
    testWidgets('Topluluk varsayılan Genel Akış + segment çubuğu', (t) async {
      await t.pumpWidget(const ProviderScope(
        child: MaterialApp(home: CommunityScreen()),
      ));
      await t.pump();
      expect(find.text(AppStrings.communityTitle), findsWidgets);
      // "Genel Akış" hem Topluluk segment çubuğunda hem de feed'in kendi
      // takip/tümü toggle'ında geçer (feed segmenti korundu) → findsWidgets.
      expect(find.text(AppStrings.communitySegFeed), findsWidgets);
      expect(find.text(AppStrings.communitySegGroups), findsOneWidget);
    });

    testWidgets('Topluluk initialSegment=1 → Gruplar segmenti seçili', (t) async {
      await t.pumpWidget(const ProviderScope(
        child: MaterialApp(home: CommunityScreen(initialSegment: 1)),
      ));
      await t.pump();
      // "+" grup oluştur aksiyonu yalnız Gruplar segmentinde görünür.
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('Pazar yakında ekranı vizyon + Yakında rozeti', (t) async {
      await t.pumpWidget(const ProviderScope(
        child: MaterialApp(home: PazarComingSoonScreen()),
      ));
      await t.pump();
      expect(find.text(AppStrings.pazarComingTitle), findsOneWidget);
      expect(find.text(AppStrings.pazarComingBadge), findsOneWidget);
      expect(find.text(AppStrings.pazarBulletSuppliersTitle), findsOneWidget);
    });

    testWidgets('İlanlar üç segment: Eleman / İş yeri / Ekipman', (t) async {
      await t.pumpWidget(const ProviderScope(
        child: MaterialApp(home: ListingsScreen()),
      ));
      await t.pump();
      expect(find.text(AppStrings.listingsSegStaff), findsOneWidget);
      expect(find.text(AppStrings.listingsSegWorkplace), findsOneWidget);
      expect(find.text(AppStrings.listingsSegEquipment), findsOneWidget);
    });

    testWidgets('Bottom nav Yakında noktası + unread badge render', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: PremiumBottomNav(
            selectedIndex: 0,
            onSelect: (_) {},
            items: const [
              PremiumNavItem(
                icon: Icons.forum_outlined,
                activeIcon: Icons.forum_rounded,
                label: AppStrings.navCommunity,
              ),
              PremiumNavItem(
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront_rounded,
                label: AppStrings.navPazar,
                comingSoon: true,
              ),
              PremiumNavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: AppStrings.navMessages,
                badgeCount: 5,
              ),
            ],
          ),
        ),
      ));
      await t.pump();
      // Badge sayacı görünür.
      expect(find.text('5'), findsOneWidget);
      expect(find.text(AppStrings.navMessages), findsOneWidget);
    });
  });
}
