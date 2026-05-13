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
import '../../features/dealers/screens/dealer_list_screen.dart';
import '../../features/dealers/screens/dealer_payment_form_screen.dart';
import '../../features/dealers/screens/dealer_return_form_screen.dart';
import '../../features/dealers/screens/dealer_share_screen.dart';
import '../../features/dealers/screens/wholesale_customers_screen.dart';
import '../../features/auth/screens/auth_entry_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/role_select_screen.dart';
import '../../features/profile/models/bakery_profile.dart' as profile_models;
import '../../features/worker/screens/job_seek_post_form_screen.dart';
import '../../features/worker/screens/job_seek_posts_screen.dart';
import '../../features/worker/screens/worker_experiences_screen.dart';
import '../../features/worker/screens/worker_profile_screen.dart';
import '../../features/dealers/models/dealer.dart' as dealer_models;
import '../../features/feed/screens/feed_screen.dart';
import '../../features/social_groups/screens/group_create_screen.dart';
import '../../features/social_groups/screens/group_detail_screen.dart';
import '../../features/social_groups/screens/groups_list_screen.dart';
import '../../features/jobs/screens/jobs_screen.dart';
import '../../features/marketplace/screens/marketplace_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/onboarding/screens/splash_screen.dart';
import '../../features/profile/screens/create_profile_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding'; // legacy alias — Splash artık /auth'a gider
  static const String authEntry = '/auth';
  static const String roleSelect = '/auth/role-select';
  static const String login = '/login';
  static const String createProfile = '/profile/create';

  // Ana tablar
  static const String feed = '/feed';
  static const String market = '/market';
  static const String panel = '/panel';
  static const String jobs = '/jobs';
  static const String profile = '/profile';

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

  // V1.2: standalone Hesaplama Makinesi (ticari + bireysel ortak araç)
  static const String calculator = '/calculator';

  // V1.2: Bireysel (Usta) panel route'ları
  static const String workerProfile = '/worker/profile';
  static const String workerExperiences = '/worker/experiences';
  static const String jobSeek = '/worker/job-seek';
  static const String jobSeekNew = '/worker/job-seek/new';

  // V1.2: Toptancı müşteri yönetimi (dealers altyapısını paylaşır)
  static const String wholesaleCustomers = '/wholesale/customers';
  static const String wholesaleCustomerNew = '/wholesale/customers/new';

  // Sosyal gruplar (V1)
  static const String groups = '/groups';
  static const String groupCreate = '/groups/create';
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
            path: AppRoutes.feed,
            pageBuilder: (_, state) =>
                _noTransition(state, const FeedScreen()),
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

      // Bayi Yönetimi (PASS Dealer V1).
      GoRoute(
        path: AppRoutes.dealers,
        builder: (_, __) => const DealerListScreen(),
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
        builder: (_, __) => const JobSeekPostFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.jobSeek}/:id/edit',
        builder: (_, state) =>
            JobSeekPostFormScreen(postId: state.pathParameters['id']!),
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
