import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/branches/models/branch_models.dart';
import 'package:firin_defter/features/branches/providers/branch_providers.dart';
import 'package:firin_defter/features/branches/repositories/local_branch_repository.dart';
import 'package:firin_defter/features/branches/screens/add_branch_staff_screen.dart';
import 'package:firin_defter/features/branches/screens/branch_detail_screen.dart';
import 'package:firin_defter/features/branches/screens/branch_management_screen.dart';
import 'package:firin_defter/features/branches/screens/my_branch_screen.dart';
import 'package:firin_defter/features/dashboard/screens/role_dashboard_screen.dart';
import 'package:firin_defter/features/messaging/providers/messaging_providers.dart';
import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Şube Yönetimi V1 — ekran/görünürlük testleri.
class _FixedProfileController extends ProfileController {
  _FixedProfileController(super.ref, BakeryProfile? profile) {
    state = profile;
  }
}

BakeryProfile _profile(AccountType type) => BakeryProfile(
  displayName: 'Test',
  accountType: type,
  city: 'Ankara',
  roleBadge: 'Usta',
  email: 't@t.com',
);

Widget _wrap(
  Widget home, {
  required LocalBranchRepository repo,
  required AccountType account,
}) {
  return ProviderScope(
    overrides: [
      branchRepositoryProvider.overrideWithValue(repo),
      profileControllerProvider.overrideWith(
        (ref) => _FixedProfileController(ref, _profile(account)),
      ),
      totalUnreadMessagesProvider.overrideWith((ref) => 0),
    ],
    child: MaterialApp(home: home),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required LocalBranchRepository repo,
  AccountType account = AccountType.commercial,
  Size size = const Size(1200, 3200),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(_wrap(home, repo: repo, account: account));
  await tester.pumpAndSettle();
}

void main() {
  group('BranchManagementScreen (ticari)', () {
    testWidgets('KPI + şube kartları + Yeni Şube CTA render olur', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(tester, const BranchManagementScreen(), repo: repo);
      expect(find.text(AppStrings.branchMgmtTitle), findsOneWidget);
      expect(find.text(AppStrings.branchMgmtHighlights), findsOneWidget);
      expect(find.text('Merkez Şube'), findsOneWidget);
      expect(find.text('Çarşı Şube'), findsOneWidget);
      expect(find.byKey(const ValueKey('branch_create_cta')), findsOneWidget);
      // Attention süreçli şube "Dikkat" rozeti alır (türetilmiş durum).
      expect(find.text(AppStrings.branchStatusAttention), findsOneWidget);
    });

    testWidgets('320dp + 1.3x dar ekranda taşma yapmaz', (tester) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(
        tester,
        const BranchManagementScreen(),
        repo: repo,
        size: const Size(320, 4000),
        textScale: 1.3,
      );
      expect(find.text(AppStrings.branchMgmtHighlights), findsOneWidget);
      expect(find.text('Merkez Şube'), findsOneWidget);
    });
  });

  group('BranchDetailScreen', () {
    testWidgets('4 tab render olur; personel ve süreçler dolu', (tester) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(
        tester,
        const BranchDetailScreen(branchId: 'branch-1'),
        repo: repo,
      );
      // 'Personel' metni Genel tab özetinde de geçer → Tab widget'ına bak.
      expect(
        find.widgetWithText(Tab, AppStrings.branchTabGeneral),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(Tab, AppStrings.branchTabStaff),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(Tab, AppStrings.branchTabProcesses),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(Tab, AppStrings.branchTabPermissions),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(Tab, AppStrings.branchTabStaff));
      await tester.pumpAndSettle();
      expect(find.text('Ahmet Usta'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('branch_staff_add_cta')),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(Tab, AppStrings.branchTabProcesses));
      await tester.pumpAndSettle();
      expect(find.text('Sabah açılış kontrolü'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('branch_process_add_cta')),
        findsOneWidget,
      );
    });
  });

  group('AddBranchStaffScreen', () {
    testWidgets('rehber paneli görünür (Çalışan nasıl eklenir?)', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(tester, const AddBranchStaffScreen(), repo: repo);
      expect(find.text(AppStrings.branchStaffGuideTitle), findsOneWidget);
      expect(find.text(AppStrings.branchStaffGuideStep1Title), findsOneWidget);
      expect(find.text(AppStrings.branchStaffGuideStep6Title), findsOneWidget);
      expect(find.text(AppStrings.branchStaffGuideFootnote), findsOneWidget);
    });

    testWidgets('form hatasında rehber küçülür; hata görünür', (tester) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(tester, const AddBranchStaffScreen(), repo: repo);
      await tester.tap(find.byKey(const ValueKey('branch_invite_send')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.branchInviteFnIdRequired), findsOneWidget);
      expect(find.text(AppStrings.branchStaffGuideStep1Title), findsNothing);
      expect(find.text(AppStrings.branchStaffGuideTitle), findsOneWidget);
    });

    testWidgets('FN-ID + şube + rol ile davet → success banner + pop', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open_add_staff'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const AddBranchStaffScreen(initialBranchId: 'branch-2'),
                  ),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
        repo: repo,
      );
      await tester.tap(find.byKey(const ValueKey('open_add_staff')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.branchInviteFnIdLabel),
        'FN-2026-000002',
      );
      await tester.tap(find.byKey(const ValueKey('branch_invite_send')));
      await tester.pumpAndSettle();

      // Ekran kapandı + davet akışına uygun success şeridi.
      expect(find.byKey(const ValueKey('open_add_staff')), findsOneWidget);
      expect(find.text(AppStrings.branchInviteSentBannerTitle), findsOneWidget);
      expect((await repo.branchPendingInvites('branch-2')), hasLength(1));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text(AppStrings.branchInviteSentBannerTitle), findsNothing);
    });
  });

  group('bireysel görünürlük (panel + Şube İşlerim)', () {
    testWidgets('aktif üyelik yoksa panelde Şube İşlerim kartı YOK', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true, currentUserId: 'staff-2');
      await _pump(
        tester,
        const RoleDashboardScreen(),
        repo: repo,
        account: AccountType.individual,
      );
      expect(find.text(AppStrings.myBranchTitle), findsNothing);
      expect(find.text(AppStrings.branchMgmtTitle), findsNothing);
    });

    testWidgets('aktif üyelik varsa panelde Şube İşlerim kartı VAR', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true, currentUserId: 'staff-1');
      await _pump(
        tester,
        const RoleDashboardScreen(),
        repo: repo,
        account: AccountType.individual,
      );
      expect(find.text(AppStrings.myBranchTitle), findsOneWidget);
      // Ticari "Şube Yönetimi" bireyselde yine görünmez.
      expect(find.text(AppStrings.branchMgmtTitle), findsNothing);
    });

    testWidgets('ticari panelde Şube Yönetimi kartı var', (tester) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(
        tester,
        const RoleDashboardScreen(),
        repo: repo,
        account: AccountType.commercial,
      );
      expect(find.text(AppStrings.branchMgmtTitle), findsOneWidget);
      expect(find.text(AppStrings.myBranchTitle), findsNothing);
    });
  });

  group('MyBranchScreen (bireysel şube personeli)', () {
    testWidgets('üyelik yoksa sade boş durum; yönetim araçları yok', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true, currentUserId: 'staff-2');
      await _pump(
        tester,
        const MyBranchScreen(),
        repo: repo,
        account: AccountType.individual,
      );
      expect(find.text(AppStrings.myBranchEmpty), findsOneWidget);
      expect(find.text(AppStrings.branchCreateCta), findsNothing);
      expect(find.text(AppStrings.branchStaffAddCta), findsNothing);
    });

    testWidgets('aktif üye: şubesi + süreçleri + izinli süreç ekleme', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true, currentUserId: 'staff-1');
      await _pump(
        tester,
        const MyBranchScreen(),
        repo: repo,
        account: AccountType.individual,
      );
      expect(find.text('Merkez Şube'), findsOneWidget);
      expect(find.text('Sabah açılış kontrolü'), findsOneWidget);

      // Süreç ekle: yalnız İZİNLİ tipler listelenir (account_note yok).
      await tester.tap(find.byKey(const ValueKey('my_branch_process_add')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('process_type_production_note')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('process_type_account_note')),
        findsNothing,
      );
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.branchProcessFormTitleField),
        'Akşam hamuru hazırlandı',
      );
      await tester.tap(find.byKey(const ValueKey('process_sheet_save')));
      await tester.pumpAndSettle();
      expect(find.text('Akşam hamuru hazırlandı'), findsOneWidget);
    });

    testWidgets('bekleyen davet kartı kabul edilince şube açılır', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true);
      final inviteId = await repo.createStaffInvite(
        branchId: 'branch-2',
        firinnetId: 'FN-2026-000002',
        role: BranchRole.counter,
        permissions: const [BranchProcessType.generalNote],
      );
      repo.currentUserId = 'staff-2';
      await _pump(
        tester,
        const MyBranchScreen(),
        repo: repo,
        account: AccountType.individual,
      );
      expect(find.text(AppStrings.myBranchInviteSection), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('branch_invite_accept_$inviteId')));
      await tester.pumpAndSettle();
      expect(find.text('Çarşı Şube'), findsOneWidget);
      expect(find.text(AppStrings.myBranchInviteSection), findsNothing);
    });
  });

  // ── V1 polish (audit sonrası akış düzeltmeleri) ──

  group('V1 polish — davet kartı netliği', () {
    testWidgets('davet kartında şube adı + davet eden görünür', (tester) async {
      final repo = LocalBranchRepository(seed: true);
      await repo.createStaffInvite(
        branchId: 'branch-2',
        firinnetId: 'FN-2026-000002',
        role: BranchRole.counter,
      );
      repo.currentUserId = 'staff-2';
      await _pump(
        tester,
        const MyBranchScreen(),
        repo: repo,
        account: AccountType.individual,
      );
      expect(find.text('Çarşı Şube'), findsOneWidget);
      expect(
        find.textContaining('${AppStrings.myBranchInviteFrom}: Patron'),
        findsOneWidget,
      );
    });

    testWidgets('adlar gelmezse güvenli fallback başlık gösterilir', (
      tester,
    ) async {
      final repo = _NamelessInviteRepository();
      await _pump(
        tester,
        const MyBranchScreen(),
        repo: repo,
        account: AccountType.individual,
      );
      expect(find.text(AppStrings.myBranchInviteFallbackTitle), findsOneWidget);
      // Davet eden bilinmiyorsa satır yalnız rolü gösterir.
      expect(find.textContaining(AppStrings.myBranchInviteFrom), findsNothing);
      expect(find.text(BranchRole.counter.label), findsOneWidget);
    });
  });

  group('V1 polish — şube preselect', () {
    testWidgets('detaydan Personel Ekle şube önceden seçili açılır', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true);
      final router = GoRouter(
        initialLocation: AppRoutes.branchDetail('branch-1'),
        routes: [
          GoRoute(
            path: '/branches/:branchId',
            builder: (_, state) =>
                BranchDetailScreen(branchId: state.pathParameters['branchId']!),
          ),
          GoRoute(
            path: AppRoutes.branchStaffNew,
            builder: (_, state) => AddBranchStaffScreen(
              initialBranchId: state.uri.queryParameters['branch'],
            ),
          ),
        ],
      );
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            branchRepositoryProvider.overrideWithValue(repo),
            profileControllerProvider.overrideWith(
              (ref) => _FixedProfileController(
                ref,
                _profile(AccountType.commercial),
              ),
            ),
            totalUnreadMessagesProvider.overrideWith((ref) => 0),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, AppStrings.branchTabStaff));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('branch_staff_add_cta')));
      await tester.pumpAndSettle();

      // Davet ekranı açıldı; şube dropdown'ında Merkez Şube seçili geldi.
      expect(find.text(AppStrings.branchInviteTitle), findsOneWidget);
      expect(find.text('Merkez Şube'), findsOneWidget);
    });
  });

  group('V1 polish — personel durum onayı', () {
    Future<void> openMemberMenu(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(Tab, AppStrings.branchTabStaff));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member_menu_member-1')));
      await tester.pumpAndSettle();
    }

    testWidgets('Çıkar onay ister; Vazgeç durumu değiştirmez', (tester) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(
        tester,
        const BranchDetailScreen(branchId: 'branch-1'),
        repo: repo,
      );
      await openMemberMenu(tester);
      await tester.tap(find.text(AppStrings.branchStaffRemove));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.branchStaffRemoveConfirmTitle),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('member_action_cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Ahmet Usta'), findsOneWidget);
      expect(
        (await repo.branchMembers('branch-1')).single.status,
        BranchMembershipStatus.active,
      );
    });

    testWidgets('Çıkar onaylanınca personel listeden düşer', (tester) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(
        tester,
        const BranchDetailScreen(branchId: 'branch-1'),
        repo: repo,
      );
      await openMemberMenu(tester);
      await tester.tap(find.text(AppStrings.branchStaffRemove));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member_action_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Ahmet Usta'), findsNothing);
      expect(await repo.branchMembers('branch-1'), isEmpty);
    });

    testWidgets('Askıya Al onay ister; onaylanınca Askıda görünür', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(
        tester,
        const BranchDetailScreen(branchId: 'branch-1'),
        repo: repo,
      );
      await openMemberMenu(tester);
      await tester.tap(find.text(AppStrings.branchStaffSuspend));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.branchStaffSuspendConfirmTitle),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('member_action_confirm')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(BranchMembershipStatus.suspended.label),
        findsOneWidget,
      );
    });
  });

  group('V1 polish — davet ekranı bilgi notu + hata dili', () {
    testWidgets('izin seçilmemişse bilgi notu görünür, seçilince kaybolur', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(tester, const AddBranchStaffScreen(), repo: repo);
      expect(
        find.byKey(const ValueKey('branch_invite_permission_note')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('branch_perm_production_note')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('branch_invite_permission_note')),
        findsNothing,
      );

      // Şube sorumlusu zaten tüm tiplere yetkili — not orada da gösterilmez.
      await tester.tap(
        find.byKey(const ValueKey('branch_role_branch_manager')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('branch_invite_permission_note')),
        findsNothing,
      );
    });

    testWidgets('geçersiz hedefte nötr davet hatası korunur', (tester) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(
        tester,
        const AddBranchStaffScreen(initialBranchId: 'branch-1'),
        repo: repo,
      );
      // Toptancı hedef → server nötr reddi (tip bilgisi sızmaz).
      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.branchInviteFnIdLabel),
        'FN-2026-000003',
      );
      await tester.tap(find.byKey(const ValueKey('branch_invite_send')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.branchInviteFnIdRequired), findsOneWidget);
    });
  });

  group('V1 polish — şube pasifleştirme erişimi', () {
    testWidgets('Genel tabda pasifleştir onaylı çalışır; geri aktifleşir', (
      tester,
    ) async {
      final repo = LocalBranchRepository(seed: true);
      await _pump(
        tester,
        const BranchDetailScreen(branchId: 'branch-2'),
        repo: repo,
      );
      expect(find.text(AppStrings.branchDeactivateCta), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('branch_toggle_active')));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.branchDeactivateConfirmTitle),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('branch_deactivate_confirm')));
      await tester.pumpAndSettle();
      expect((await repo.branchById('branch-2'))!.isActive, isFalse);
      expect(find.text(AppStrings.branchActivateCta), findsOneWidget);

      // Aktifleştirme onay istemeden geri açar.
      await tester.tap(find.byKey(const ValueKey('branch_toggle_active')));
      await tester.pumpAndSettle();
      expect((await repo.branchById('branch-2'))!.isActive, isTrue);
    });
  });
}

/// Ad çözümü başarısız Supabase durumunun aynası: davet var ama şube/patron
/// adları boş → UI güvenli fallback göstermeli.
class _NamelessInviteRepository extends LocalBranchRepository {
  _NamelessInviteRepository() : super(currentUserId: 'staff-2');

  @override
  Future<List<BranchInvite>> myPendingInvites() async => [
    const BranchInvite(
      id: 'invite-x',
      branchId: 'branch-x',
      role: BranchRole.counter,
    ),
  ];
}
