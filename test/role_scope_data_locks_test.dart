// Rol/Scope veri kilidi (role_data_lock) — migration source kontratı +
// UI helper davranışı + mode/akış wiring source-assertion.

import 'dart:io';

import 'package:firin_defter/features/dealers/widgets/role_data_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('Migration — role_scope_data_locks', () {
    final mig = _read(
      'supabase/migrations/20260623160000_role_scope_data_locks.sql',
    );

    test('has_role_locked_data 6 işletme tablosunu kontrol eder', () {
      expect(mig.contains('function public.has_role_locked_data'), isTrue);
      for (final t in const [
        'public.dealers',
        'public.dealer_transactions',
        'public.dealer_deliveries',
        'public.dealer_prices',
        'public.dealer_notes',
        'public.debt_expense_entries',
      ]) {
        expect(mig.contains('from $t where owner_id = p_uid'), isTrue,
            reason: '$t kontrolü eksik');
      }
    });

    test('respond_driver_invite kabul dalında role_data_lock fırlatır', () {
      expect(mig.contains('function public.respond_driver_invite'), isTrue);
      expect(mig.contains('has_role_locked_data(v_uid)'), isTrue);
      expect(
        mig.contains(
            'role_data_lock: personal records must be cleared before accepting driver invite'),
        isTrue,
      );
    });

    test('profiles account_type guard trigger var (BEFORE UPDATE)', () {
      expect(mig.contains('function public.guard_account_type_change'), isTrue);
      expect(mig.contains('new.account_type is distinct from old.account_type'),
          isTrue);
      expect(
        mig.contains(
            'role_data_lock: existing business records block account type change'),
        isTrue,
      );
      expect(mig.contains('before update on public.profiles'), isTrue);
    });

    test('ADDITIVE — veri silme / drop tablo YOK', () {
      final ml = mig.toLowerCase();
      expect(ml.contains('drop table'), isFalse);
      expect(ml.contains('delete from'), isFalse);
      expect(ml.contains('truncate'), isFalse);
    });

    test('iç helper EXECUTE revoke (definer-only)', () {
      expect(
        mig.contains('revoke execute on function public.has_role_locked_data'),
        isTrue,
      );
    });
  });

  group('role_data_lock UI helper', () {
    test('isRoleDataLockError mesaja göre ayırır', () {
      expect(
        isRoleDataLockError(Exception('role_data_lock: ... block ...')),
        isTrue,
      );
      expect(isRoleDataLockError(Exception('network error')), isFalse);
    });

    testWidgets('davet popup: temizleme açıklaması + Tamam', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold();
        }),
      ));
      showRoleDataLockDialog(ctx, forInvite: true);
      await tester.pumpAndSettle();
      expect(find.text('Önce mevcut kayıtlarını temizlemelisin'), findsOneWidget);
      expect(find.textContaining('Şoför olarak atanırsan'), findsOneWidget);
      expect(find.text('Tamam'), findsOneWidget);
    });

    testWidgets('profil tipi popup: ayrı açıklama', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold();
        }),
      ));
      showRoleDataLockDialog(ctx, forInvite: false);
      await tester.pumpAndSettle();
      expect(find.text('Profil tipi değiştirilemiyor'), findsOneWidget);
      expect(find.textContaining('Profil tipini değiştirmek'), findsOneWidget);
    });
  });

  group('Wiring — role_data_lock yakalama', () {
    test('driver_home_screen davet kabulünde yakalar', () {
      final src =
          _read('lib/features/dealers/screens/driver_home_screen.dart');
      expect(src.contains('isRoleDataLockError'), isTrue);
      expect(src.contains('showRoleDataLockDialog(context, forInvite: true)'),
          isTrue);
    });
    test('profile_edit_sheet account_type değişiminde yakalar', () {
      final src = _read('lib/features/profile/widgets/profile_edit_sheet.dart');
      expect(src.contains('isRoleDataLockError'), isTrue);
      expect(src.contains('showRoleDataLockDialog(context, forInvite: false)'),
          isTrue);
    });
    test('mode: kendi verisi olan bireysel owner kalır', () {
      final src =
          _read('lib/features/dealers/providers/dealer_providers.dart');
      expect(src.contains('individualHasOwnLedgerDataProvider'), isTrue);
      expect(src.contains('if (hasOwnData) return DealerShellMode.owner'),
          isTrue);
    });
  });
}
