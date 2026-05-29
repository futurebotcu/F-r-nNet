import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/bakery_panel/screens/bakery_panel_screen.dart';
import '../../features/bakery_panel/screens/calculator_screen.dart';
import '../../features/bakery_panel/screens/end_of_day_screen.dart';
import '../../features/bakery_panel/screens/production_entry_screen.dart';
import '../../features/bakery_panel/screens/recipe_detail_screen.dart';
import '../../features/bakery_panel/screens/recipe_editor_screen.dart';
import '../../features/bakery_panel/screens/recipes_list_screen.dart';
import '../../features/bakery_panel/screens/report_screen.dart';
import '../../features/bakery_panel/screens/waste_entry_screen.dart';
import '../../features/dashboard/screens/app_shell.dart';
import '../../features/dashboard/screens/role_dashboard_screen.dart';
import '../../features/dealers/screens/add_dealer_screen.dart';
import '../../features/dealers/screens/dealer_adjustment_form_screen.dart';
import '../../features/dealers/screens/dealer_delivery_form_screen.dart';
import '../../features/dealers/screens/dealer_detail_screen.dart';
import '../../features/dealers/screens/dealer_payment_form_screen.dart';
import '../../features/dealers/screens/dealer_range_report_screen.dart';
import '../../features/dealers/screens/dealer_return_form_screen.dart';
import '../../features/dealers/screens/dealer_share_screen.dart';
import '../../features/dealers/screens/dealer_shell_screen.dart';
import '../../features/dealers/screens/wholesale_customers_screen.dart';
import '../../features/auth/screens/auth_entry_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/role_select_screen.dart';
import '../../features/legal/screens/privacy_screen.dart';
import '../../features/legal/screens/terms_screen.dart';
import '../../features/profile/models/bakery_profile.dart' as profile_models;
import '../../features/worker/screens/job_seek_post_form_screen.dart';
import '../../features/worker/screens/job_seek_posts_screen.dart';
import '../../features/worker/screens/worker_experiences_screen.dart';
import '../../features/worker/screens/worker_profile_screen.dart';
import '../../features/dealers/models/dealer.dart' as dealer_models;
import '../../features/social/composer/social_composer_page.dart';
import '../../features/social/feed/social_feed_page.dart';
import '../../features/social/post/social_post_edit_page.dart';
import '../../features/social/stories/story_create_page.dart';
import '../../features/social/stories/story_viewer_page.dart';
import '../../features/social_groups/screens/group_create_screen.dart';
import '../../features/social_groups/screens/group_detail_screen.dart';
import '../../features/social_groups/screens/groups_list_screen.dart';
import '../../features/jobs/screens/job_offer_form_screen.dart';
import '../../features/jobs/screens/jobs_screen.dart';
import '../../features/marketplace/screens/market_listing_form_screen.dart';
import '../../features/marketplace/screens/marketplace_detail_screen.dart';
import '../../features/marketplace/screens/marketplace_screen.dart';
import '../../features/messages/screens/job_conversation_screen.dart';
import '../../features/messages/screens/messages_list_screen.dart';
import '../../features/messaging/screens/chat_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/onboarding/screens/splash_screen.dart';
import '../../features/profile/screens/create_profile_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/professional_cv_screen.dart';
import '../../features/social/profile/profile_page.dart';
import '../../features/social/profile/user_list_page.dart';
import '../../features/settings/screens/about_screen.dart';
import '../../features/settings/screens/data_info_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding'; // legacy alias — Splash artık /auth'a gider
  static const String authEntry = '/auth';
  static const String roleSelect = '/auth/role-select';
  static const String forgotPassword = '/auth/forgot';
  static const String login = '/login';
  static const String createProfile = '/profile/create';

  // V1.3.5 — Yasal metin route'ları
  static const String legalTerms = '/legal/terms';
  static const String legalPrivacy = '/legal/privacy';

  // V1.4 — Ayarlar menüsü (gear icon → /settings)
  static const String settings = '/settings';
  static const String settingsAbout = '/settings/about';
  static const String settingsDataInfo = '/settings/data-info';

  // V1 P1-D — Uygulama içi bildirimler.
  static const String notifications = '/notifications';

  // Ana tablar
  static const String feed = '/feed';
  static const String market = '/market';
  static const String panel = '/panel';
  static const String jobs = '/jobs';
  static const String profile = '/profile';

  /// Unified Professional CV Center — profil içinde tek mesleki CV düzenleme
  /// merkezi (bio + son durum + CV kayıtları + görünürlük + CV'den ilan).
  static const String professionalCv = '/profile/cv';

  // Fırın Paneli — Ticari rol için "/panel" altına nested giriş.
  // Eski "/panel" Fırın Paneli'ydi; rol bazlı dashboard'a taşındı,
  // Ticari kart üzerinden push ile bu route'a giriliyor.
  static const String bakeryPanel = '/panel/bakery';

  // Üretim Yönetimi sub-routes
  // Reçete Kütüphanesi — list/new/detail.
  // Legacy /panel/recipe alias olarak [recipes]'e yönlenir (router redirect).
  static const String recipes = '/recipes';
  static const String recipeNew = '/recipes/new';
  static const String recipe = '/panel/recipe'; // legacy alias
  static const String production = '/panel/production';
  static const String dealer = '/panel/dealer'; // legacy V1 — kullanılmıyor
  static const String waste = '/panel/waste';
  static const String endOfDay = '/panel/end-of-day';
  static const String report = '/panel/report';

  // Bayi Yönetimi sub-routes
  static const String dealers = '/dealers';
  static const String dealerNew = '/dealers/new';
  // Sprint 3 — Date-range metrics report screen.
  // Quality Patch v2: opsiyonel `period` query param — Raporlar tab'ından
  // gelirken seçili periyodu transfer eder (`last30Days` / `thisMonth`).
  // Eşleşmeyen veya boş değerlerde DealerRangeReportScreen kendi default'ına
  // (`last30Days`) düşer.
  static String dealerReport(String id, {String? period}) {
    if (period == null || period.isEmpty) return '/dealers/$id/report';
    return '/dealers/$id/report?period=$period';
  }

  // V1.2: standalone Hesaplama Makinesi (ticari + bireysel ortak araç)
  static const String calculator = '/calculator';

  // V1.2: Bireysel (Usta) panel route'ları
  static const String workerProfile = '/worker/profile';

  // V1 Social S1 — Public profile by user id (any user). Bottom nav profile
  // tab path'i (`/profile`) own-only; bu path başkasının profilini görmek
  // için. Yol kısa (`/u/:userId`) — gelecekte share URL şablonu için iyi.
  static const String userPublicProfile = '/u';

  // V1 Donor-First Social Rebuild — yeni composer ekranı (post oluşturma).
  // SocialFeedPage'deki FAB bu route'a push eder.
  static const String socialComposer = '/social/composer';

  // V2 Social Core — donor `AppRoutes.postEdit` muadili. Owner-only edit
  // ekranı; SocialPostCard ⋮ menüsünden "Düzenle" push eder.
  static const String socialPostEdit = '/social/post';
  static String socialPostEditFor(String postId) => '$socialPostEdit/$postId/edit';

  // V2 Social Core Commit 2 — story create + viewer (donor
  // `AppRoutes.createStories` + `AppRoutes.stories` muadili).
  static const String storyCreate = '/social/stories/create';
  static const String storyViewer = '/social/stories/viewer';
  static const String workerExperiences = '/worker/experiences';
  static const String jobSeek = '/worker/job-seek';
  static const String jobSeekNew = '/worker/job-seek/new';

  // V1.2: Toptancı müşteri yönetimi (dealers altyapısını paylaşır)
  static const String wholesaleCustomers = '/wholesale/customers';
  static const String wholesaleCustomerNew = '/wholesale/customers/new';

  // Sosyal gruplar (V1)
  static const String groups = '/groups';
  static const String groupCreate = '/groups/create';

  // V1 — Job offer ("Usta Arıyor / İş Veriyorum") ilanları
  static const String jobOfferNew = '/jobs/offers/new';
  static String jobOfferEdit(String id) => '/jobs/offers/$id/edit';

  // V1 — Marketplace ilanları
  static const String marketListingNew = '/market/listings/new';
  static String marketListingDetail(String id) => '/market/listings/$id';
  static String marketListingEdit(String id) => '/market/listings/$id/edit';

  // V1 — Job messaging (job_conversations + job_messages)
  static const String messages = '/messages';
  static String conversation(String id) => '/messages/$id';
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        // Legacy mock onboarding — V1.3'te boot landing /auth'a taşındı.
        // Backward compat için ekran korunuyor (Supabase-off senaryosunda da
        // splash artık /auth'a gidiyor; bu route hâlâ tanımlı kalıyor).
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.authEntry,
        builder: (_, __) => const AuthEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.roleSelect,
        builder: (_, __) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.legalTerms,
        builder: (_, __) => const TermsScreen(),
      ),
      GoRoute(
        path: AppRoutes.legalPrivacy,
        builder: (_, __) => const PrivacyScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.createProfile,
        builder: (_, state) {
          final roleKey = state.uri.queryParameters['role'];
          final account = _accountTypeFromKey(roleKey);
          return CreateProfileScreen(initialAccountType: account);
        },
      ),

      // Ana shell + tab'lar.
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            // V2 Commit 4 cleanup — Legacy FeedScreen tamamen silindi.
            // SocialFeedPage donor-first sosyal akış.
            path: AppRoutes.feed,
            pageBuilder: (_, state) =>
                _noTransition(state, const SocialFeedPage()),
          ),
          GoRoute(
            // Sosyal Gruplar — bottom nav 2. tab (V Nav-Social-Priority-Fix).
            path: AppRoutes.groups,
            pageBuilder: (_, state) =>
                _noTransition(state, const GroupsListScreen()),
          ),
          GoRoute(
            path: AppRoutes.market,
            pageBuilder: (_, state) =>
                _noTransition(state, const MarketplaceScreen()),
          ),
          GoRoute(
            // İlanlar — bottom nav 4. tab (V Nav-Profile-To-Jobs).
            path: AppRoutes.jobs,
            pageBuilder: (_, state) =>
                _noTransition(state, const JobsScreen()),
          ),
          GoRoute(
            path: AppRoutes.panel,
            pageBuilder: (_, state) =>
                _noTransition(state, const RoleDashboardScreen()),
          ),
        ],
      ),

      // Fırın Paneli — Ticari kart push'u; shell üstünde tam ekran.
      GoRoute(
        path: AppRoutes.bakeryPanel,
        builder: (_, __) => const BakeryPanelScreen(),
      ),

      // Profile — bottom nav'dan çıkarıldı ama route geriye dönük uyumluluk
      // için korunuyor (Feed header avatar tap'iyle full-screen push olarak
      // açılır; ana ekran tab'ı değil).
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),

      // V1 Social F2 — Donor-first SocialProfilePage (`/u/:userId`).
      // (V2 Commit 4 cleanup — eski PublicProfileScreen tamamen silindi.)
      GoRoute(
        path: '${AppRoutes.userPublicProfile}/:userId',
        builder: (_, state) => SocialProfilePage(
          userId: state.pathParameters['userId']!,
        ),
      ),
      // F2 — Followers list (`/u/:userId/followers`).
      GoRoute(
        path: '${AppRoutes.userPublicProfile}/:userId/followers',
        builder: (_, state) => SocialUserListPage(
          userId: state.pathParameters['userId']!,
          kind: UserListKind.followers,
        ),
      ),
      // F2 — Following list (`/u/:userId/following`).
      GoRoute(
        path: '${AppRoutes.userPublicProfile}/:userId/following',
        builder: (_, state) => SocialUserListPage(
          userId: state.pathParameters['userId']!,
          kind: UserListKind.following,
        ),
      ),

      // V1 Donor-First Social Rebuild — composer ayrı tam ekran route.
      // SocialFeedPage'deki FAB bu route'a push eder.
      // (V2 Commit 4 cleanup — eski FeedComposer tamamen silindi.)
      GoRoute(
        path: AppRoutes.socialComposer,
        builder: (_, __) => const SocialComposerPage(),
      ),

      // V2 Social Core — Post edit ekranı (donor `AppRoutes.postEdit`).
      // SocialPostCard ⋮ menüsünden "Düzenle" push eder; owner-only.
      GoRoute(
        path: '${AppRoutes.socialPostEdit}/:postId/edit',
        builder: (_, state) => SocialPostEditPage(
          postId: state.pathParameters['postId']!,
        ),
      ),

      // V2 Social Core Commit 2 — story create + viewer.
      GoRoute(
        path: AppRoutes.storyCreate,
        builder: (_, __) => const SocialStoryCreatePage(),
      ),
      GoRoute(
        path: AppRoutes.storyViewer,
        builder: (_, state) {
          final ownerId = state.uri.queryParameters['ownerId'] ?? '';
          return SocialStoryViewerPage(ownerId: ownerId);
        },
      ),

      // V1.4 — Ayarlar menüsü. Profile gear icon push'u ile açılır;
      // bottom nav tab değil, shell üstünde full-screen.
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsAbout,
        builder: (_, __) => const AboutScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsDataInfo,
        builder: (_, __) => const DataInfoScreen(),
      ),

      // V1 P1-D — Bildirimler ekranı.
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),

      // Üretim Yönetimi alt ekranları (shell dışında, tam ekran).
      // Reçete Kütüphanesi (V1.1) — list/new/detail/edit
      GoRoute(
        path: AppRoutes.recipes,
        builder: (_, __) => const RecipesListScreen(),
      ),
      GoRoute(
        path: AppRoutes.recipeNew,
        builder: (_, __) => const RecipeEditorScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.recipes}/:id',
        builder: (_, state) =>
            RecipeDetailScreen(recipeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.recipes}/:id/edit',
        builder: (_, state) =>
            RecipeEditorScreen(recipeId: state.pathParameters['id']!),
      ),
      // Legacy alias — eski /panel/recipe çağrılarını yeni listeye redirect.
      GoRoute(
        path: AppRoutes.recipe,
        redirect: (_, __) => AppRoutes.recipes,
      ),
      GoRoute(
        path: AppRoutes.production,
        builder: (_, __) => const ProductionEntryScreen(),
      ),
      GoRoute(
        // V1.3.3 — Legacy /panel/dealer route'u artık /dealers'a redirect.
        // Eski deeplink'ler (eski build / paylaşılan link) bozulmadan yeni
        // bayi paneline yönlenir; guest user için StateError leak'i engellenir.
        path: AppRoutes.dealer,
        redirect: (_, __) => AppRoutes.dealers,
      ),
      GoRoute(
        path: AppRoutes.waste,
        builder: (_, __) => const WasteEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.endOfDay,
        builder: (_, __) => const EndOfDayScreen(),
      ),
      GoRoute(
        path: AppRoutes.report,
        builder: (_, __) => const ReportScreen(),
      ),

      // Bayi Defteri mini-app shell (Sprint 6A). Eski DealerListScreen
      // shell'in "Bayiler" tab'ına embedlenir; tüm alt-route'lar
      // (`/dealers/:id`, `/dealers/:id/delivery` vs.) dokunulmadan kalır.
      GoRoute(
        path: AppRoutes.dealers,
        builder: (_, __) => const DealerShellScreen(),
      ),
      GoRoute(
        path: AppRoutes.dealerNew,
        builder: (_, __) => const AddDealerScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.dealers}/:id',
        builder: (_, state) =>
            DealerDetailScreen(dealerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.dealers}/:id/delivery',
        builder: (_, state) => DealerDeliveryFormScreen(
          dealerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.dealers}/:id/return',
        builder: (_, state) => DealerReturnFormScreen(
          dealerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.dealers}/:id/payment',
        builder: (_, state) => DealerPaymentFormScreen(
          dealerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.dealers}/:id/share',
        builder: (_, state) => DealerShareScreen(
          dealerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.dealers}/:id/adjustment',
        builder: (_, state) => DealerAdjustmentFormScreen(
          dealerId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.dealers}/:id/report',
        builder: (_, state) => DealerRangeReportScreen(
          dealerId: state.pathParameters['id']!,
          initialPeriodKey: state.uri.queryParameters['period'],
        ),
      ),

      // V1.2 — Standalone Hesaplama Makinesi
      GoRoute(
        path: AppRoutes.calculator,
        builder: (_, __) => const CalculatorScreen(),
      ),

      // V1.2 — Bireysel (Usta) panel ekranları
      GoRoute(
        path: AppRoutes.workerProfile,
        builder: (_, __) => const WorkerProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.workerExperiences,
        builder: (_, __) => const WorkerExperiencesScreen(),
      ),
      GoRoute(
        path: AppRoutes.jobSeek,
        builder: (_, __) => const JobSeekPostsScreen(),
      ),
      GoRoute(
        path: AppRoutes.jobSeekNew,
        builder: (_, state) => JobSeekPostFormScreen(
          // CV Center → "İş Arıyorum ilanı aç": meslek/şehir/deneyim/bio
          // prefill state.extra ile geçer. Menüden manuel açılışta extra
          // null → form normal/boş çalışır (mevcut akış korunur).
          prefill: state.extra is JobSeekPrefill
              ? state.extra as JobSeekPrefill
              : null,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.jobSeek}/:id/edit',
        builder: (_, state) =>
            JobSeekPostFormScreen(postId: state.pathParameters['id']!),
      ),

      // Unified Professional CV Center — tek mesleki CV düzenleme merkezi.
      GoRoute(
        path: AppRoutes.professionalCv,
        builder: (_, __) => const ProfessionalCvScreen(),
      ),

      // V1.2 — Toptancı müşteri yönetimi (dealers altyapısı paylaşılır)
      GoRoute(
        path: AppRoutes.wholesaleCustomers,
        builder: (_, __) => const WholesaleCustomersScreen(),
      ),
      GoRoute(
        path: AppRoutes.wholesaleCustomerNew,
        builder: (_, __) => const AddDealerScreen(
          customerType: dealer_models.DealerCustomerType.wholesaleCustomer,
        ),
      ),

      // Sosyal Gruplar — /groups artık ShellRoute içinde tab; create ve
      // detail ekranları shell üstünde full-screen kalır.
      GoRoute(
        path: AppRoutes.groupCreate,
        builder: (_, __) => const GroupCreateScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.groups}/:id',
        builder: (_, state) =>
            GroupDetailScreen(groupId: state.pathParameters['id']!),
      ),

      // V1 — Job offer form (Usta Arıyor) + edit
      GoRoute(
        path: AppRoutes.jobOfferNew,
        builder: (_, __) => const JobOfferFormScreen(),
      ),
      GoRoute(
        path: '/jobs/offers/:id/edit',
        builder: (_, state) =>
            JobOfferFormScreen(postId: state.pathParameters['id']!),
      ),

      // V1 — Market listing form + edit + detail.
      // Path sırası önemli: literal `/new` önce, sonra `/:id/edit` (3 segment),
      // sonra `/:id` (2 segment). Aksi halde `/new` yanlışlıkla `:id` olarak
      // yakalanabilir.
      GoRoute(
        path: AppRoutes.marketListingNew,
        builder: (_, __) => const MarketListingFormScreen(),
      ),
      GoRoute(
        path: '/market/listings/:id/edit',
        builder: (_, state) =>
            MarketListingFormScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/market/listings/:id',
        builder: (_, state) => MarketplaceDetailScreen(
          listingId: state.pathParameters['id']!,
        ),
      ),

      // V1 — Job messaging
      // M1.2: /messages → MessagesListScreen (generic conversations).
      // /messages/:id → ChatScreen (generic). Eski JobConversationScreen
      // legacy ekran olarak korunur ve job offer/seek detail içinde ayrı
      // /messages/legacy/:id route'tan ulaşılabilir kalır.
      GoRoute(
        path: AppRoutes.messages,
        builder: (_, __) => const MessagesListScreen(),
      ),
      GoRoute(
        path: '/messages/legacy/:id',
        builder: (_, state) => JobConversationScreen(
          conversationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/messages/:id',
        builder: (_, state) => ChatScreen(
          conversationId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}

CustomTransitionPage<void> _noTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, __, ___, c) => c,
  );
}

/// `?role=commercial|individual|wholesaler` query parametresinden enum'a
/// güvenli parse. Bilinmeyen veya boşsa null döner (form default'u kullanır).
profile_models.AccountType? _accountTypeFromKey(String? key) {
  switch (key) {
    case 'commercial':
      return profile_models.AccountType.commercial;
    case 'individual':
      return profile_models.AccountType.individual;
    case 'wholesaler':
      return profile_models.AccountType.wholesaler;
    default:
      return null;
  }
}
