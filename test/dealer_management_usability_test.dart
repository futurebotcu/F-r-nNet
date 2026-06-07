import 'package:firin_defter/app/router/app_router.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/core/widgets/app_primary_button.dart';
import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/guest_mode_provider.dart';
import 'package:firin_defter/features/dealers/models/dealer.dart';
import 'package:firin_defter/features/dealers/models/dealer_transaction.dart';
import 'package:firin_defter/features/dealers/providers/dealer_providers.dart';
import 'package:firin_defter/features/dealers/repositories/local_dealer_repository.dart';
import 'package:firin_defter/features/dealers/screens/add_dealer_screen.dart';
import 'package:firin_defter/features/dealers/screens/dealer_detail_screen.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _commercialProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

Future<LocalDealerRepository> _repoWithDealer() async {
  final repo = LocalDealerRepository(seed: false);
  await repo.upsertDealer(
    Dealer(
      id: 'd1',
      name: 'Hamdi Bakkal',
      contactName: 'Hamdi Usta',
      phone: '0532 111 22 33',
      city: 'Konya',
      cityCode: '42',
      area: 'Selçuklu',
      districtCode: 'selcuklu',
      workingType: DealerWorkingType.term,
      note: 'Cuma tahsilatı',
      createdAt: DateTime(2026, 1, 1),
    ),
  );
  await repo.addTransaction(
    DealerTransaction(
      id: 't1',
      dealerId: 'd1',
      type: DealerTransactionType.delivery,
      amount: 120,
      createdAt: DateTime(2026, 5, 1),
    ),
  );
  return repo;
}

List<Override> _overrides(LocalDealerRepository repo, {bool guest = false}) {
  return [
    dealerRepositoryProvider.overrideWithValue(repo),
    profileControllerProvider.overrideWith(
      (ref) => _SeededProfileController(
        ref,
        guest ? BakeryProfile.guest : _commercialProfile,
      ),
    ),
    currentAuthUserProvider.overrideWith((_) => null),
    guestModeProvider.overrideWith((_) => GuestModeNotifier()..setGuest(guest)),
  ];
}

Widget _wrap(LocalDealerRepository repo, Widget child, {bool guest = false}) {
  return ProviderScope(
    overrides: _overrides(repo, guest: guest),
    child: MaterialApp(home: child),
  );
}

GoRouter _detailRouter(LocalDealerRepository repo, {bool guest = false}) {
  return GoRouter(
    initialLocation: '/dealers/d1',
    routes: [
      GoRoute(
        path: '${AppRoutes.dealers}/:id',
        builder: (_, state) =>
            DealerDetailScreen(dealerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.dealers}/:id/edit',
        builder: (_, state) =>
            AddDealerScreen(dealerId: state.pathParameters['id']!),
      ),
    ],
  );
}

Widget _wrapRouter(LocalDealerRepository repo, {bool guest = false}) {
  return ProviderScope(
    overrides: _overrides(repo, guest: guest),
    child: MaterialApp.router(routerConfig: _detailRouter(repo, guest: guest)),
  );
}

void _useTallViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapPrimaryButton(WidgetTester tester) async {
  final button = find.byType(AppPrimaryButton);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  testWidgets('AddDealerScreen create mode copy + phone validation', (
    tester,
  ) async {
    _useTallViewport(tester);
    final repo = LocalDealerRepository(seed: false);
    await tester.pumpWidget(_wrap(repo, const AddDealerScreen()));

    expect(find.text(AppStrings.dealerAddTitle), findsOneWidget);
    expect(find.text(AppStrings.dealerFormIntro), findsOneWidget);
    expect(find.text(AppStrings.dealerFieldContactHelper), findsOneWidget);
    expect(find.text(AppStrings.dealerFieldPhoneHelper), findsOneWidget);
    expect(find.text(AppStrings.dealerSaveButton), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Yeni Bayi');
    await tester.enterText(find.byType(TextFormField).at(2), '12345');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await _tapPrimaryButton(tester);
    await tester.pump();

    expect(find.text(AppStrings.dealerFieldPhoneInvalid), findsOneWidget);
  });

  testWidgets(
    'Dealer detail edit action opens prefilled form and saves update',
    (tester) async {
      _useTallViewport(tester);
      final repo = await _repoWithDealer();
      await tester.pumpWidget(_wrapRouter(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(AppStrings.dealerDetailEditTooltip));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.dealerEditTitle), findsOneWidget);
      expect(find.text('Hamdi Bakkal'), findsOneWidget);
      expect(find.text('Hamdi Usta'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Hamdi Market');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await _tapPrimaryButton(tester);
      await tester.pumpAndSettle();

      final updated = await repo.getDealer('d1');
      expect(updated!.name, 'Hamdi Market');
      expect(updated.isActive, isTrue);
      expect(updated.createdAt, DateTime(2026, 1, 1));
    },
  );

  testWidgets(
    'Dealer detail passive/active action uses confirmation and keeps history',
    (tester) async {
      final repo = await _repoWithDealer();
      final beforeTx = await repo.listTransactions('d1');
      await tester.pumpWidget(_wrapRouter(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(AppStrings.dealerDetailStatusTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.dealerDetailSetPassive));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.dealerStatusPassiveTitle), findsOneWidget);
      expect(find.text(AppStrings.dealerStatusPassiveBody), findsOneWidget);

      await tester.tap(find.text(AppStrings.dealerStatusPassiveConfirm));
      await tester.pumpAndSettle();

      final passive = await repo.getDealer('d1');
      final afterTx = await repo.listTransactions('d1');
      expect(passive!.isActive, isFalse);
      expect(afterTx.length, beforeTx.length);
      expect(find.text(AppStrings.dealerDetailPassiveInfo), findsOneWidget);
      expect(find.text(AppStrings.dealerStatusUpdated), findsOneWidget);
    },
  );

  testWidgets('Guest user active/passive action keeps auth guard', (
    tester,
  ) async {
    final repo = await _repoWithDealer();
    await tester.pumpWidget(_wrapRouter(repo, guest: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(AppStrings.dealerDetailStatusTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.dealerDetailSetPassive));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.authRequiredTitle), findsOneWidget);
    final dealer = await repo.getDealer('d1');
    expect(dealer!.isActive, isTrue);
  });
}
