// Üç rolün (Fırın/İşletme · Usta/Çalışan · Tedarikçi) Panel ana ekranı ve
// alıcı Pazar sekmeleri — 320px · 1.0/1.3/1.5x taşma ve boş durum kontrolü.

import 'package:firin_defter/features/b2b_market/providers/b2b_providers.dart';
import 'package:firin_defter/features/b2b_market/repositories/local_b2b_repository.dart';
import 'package:firin_defter/features/b2b_market/screens/b2b_shell_screen.dart';
import 'package:firin_defter/features/branches/providers/branch_providers.dart';
import 'package:firin_defter/features/branches/repositories/local_branch_repository.dart';
import 'package:firin_defter/features/dashboard/screens/role_dashboard_screen.dart';
import 'package:firin_defter/features/messaging/providers/messaging_providers.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/subscriptions/data/local_subscription_repository.dart';
import 'package:firin_defter/features/subscriptions/models/business_plan.dart';
import 'package:firin_defter/features/subscriptions/providers/subscription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Profile extends ProfileController {
  _Profile(super.ref, AccountType t) {
    state = BakeryProfile(
      displayName: 'Çok Uzun İsimli Kullanıcı Adı Soyadı',
      accountType: t,
      city: 'İstanbul',
      roleBadge: 'Uzun Bir Meslek Rozeti Metni',
      email: 't@t.com',
    );
  }
}

Future<void> _surface(WidgetTester t, double scale) async {
  t.view.physicalSize = const Size(320, 3600);
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearAllTestValues);
}

List<String> _captureOverflows() {
  final out = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) {
      final s = d.toString();
      final i = s.indexOf('The relevant error-causing widget was');
      out.add(i >= 0 ? s.substring(i, (i + 200).clamp(0, s.length)) : s);
    } else {
      debugPrint('[test] non-overflow error: ${d.exceptionAsString()}');
      previous?.call(d);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
  return out;
}

List<Override> _base(AccountType t, BusinessPlan plan) => [
  profileControllerProvider.overrideWith((ref) => _Profile(ref, t)),
  totalUnreadMessagesProvider.overrideWith((ref) => 12),
  subscriptionRepositoryProvider.overrideWithValue(
    LocalSubscriptionRepository(plan: plan),
  ),
  branchRepositoryProvider.overrideWithValue(LocalBranchRepository()),
  b2bRepositoryProvider.overrideWithValue(LocalB2bRepository()),
];

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  final cases = <String, Widget Function()>{
    'Panel · Fırın/İşletme (Free)': () => ProviderScope(
      overrides: _base(AccountType.commercial, BusinessPlan.free),
      child: const MaterialApp(home: RoleDashboardScreen()),
    ),
    'Panel · Usta/Çalışan': () => ProviderScope(
      overrides: _base(AccountType.individual, BusinessPlan.free),
      child: const MaterialApp(home: RoleDashboardScreen()),
    ),
    'Panel · Tedarikçi (Free)': () => ProviderScope(
      overrides: _base(AccountType.wholesaler, BusinessPlan.free),
      child: const MaterialApp(home: RoleDashboardScreen()),
    ),
    'Pazar · alıcı Ürünler': () => ProviderScope(
      overrides: [
        ..._base(AccountType.commercial, BusinessPlan.free),
        b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.buyer),
      ],
      child: const MaterialApp(home: B2bShellScreen(initialTab: 'urunler')),
    ),
    'Pazar · alıcı Kampanyalar': () => ProviderScope(
      overrides: [
        ..._base(AccountType.commercial, BusinessPlan.free),
        b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.buyer),
      ],
      child: const MaterialApp(home: B2bShellScreen(initialTab: 'kampanyalar')),
    ),
    'Pazar · alıcı Tedarikçiler': () => ProviderScope(
      overrides: [
        ..._base(AccountType.commercial, BusinessPlan.free),
        b2bRoleOverrideProvider.overrideWith((ref) => B2bRole.buyer),
      ],
      child: const MaterialApp(
        home: B2bShellScreen(initialTab: 'tedarikciler'),
      ),
    ),
  };

  for (final scale in const [1.0, 1.3, 1.5]) {
    cases.forEach((name, build) {
      testWidgets('320px · ${scale}x — $name', (t) async {
        await _surface(t, scale);
        final overflows = _captureOverflows();
        await t.pumpWidget(build());
        await t.pumpAndSettle();
        expect(overflows, isEmpty, reason: overflows.join('\n'));
      });
    });
  }
}
