// D-1 (PR-6) — Şoför/davet-edilen kullanıcı hesabını silebilsin.
//
// Migration FK delete-action değişimini + delete-account kontratını STATİK
// kilitler. Gerçek DB silme YAPILMAZ (kaynak-assertion).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('FN D-1 — driver/invite FK → ON DELETE CASCADE', () {
    final mig = _read(
      'supabase/migrations/20260623100000_driver_account_deletion_cascade.sql',
    ).toLowerCase();

    test('dealer_drivers.driver_user_id CASCADE', () {
      expect(
        mig.contains('drop constraint if exists dealer_drivers_driver_user_id_fkey'),
        isTrue,
      );
      expect(
        mig.contains(
          'foreign key (driver_user_id) references public.profiles(id) on delete cascade',
        ),
        isTrue,
      );
    });

    test('dealer_driver_invites.invited_user_id CASCADE', () {
      expect(
        mig.contains(
          'drop constraint if exists dealer_driver_invites_invited_user_id_fkey',
        ),
        isTrue,
      );
      expect(
        mig.contains(
          'foreign key (invited_user_id) references public.profiles(id) on delete cascade',
        ),
        isTrue,
      );
    });

    test('VERİ/TABLO drop yok (yalnız FK constraint değişimi)', () {
      expect(mig.contains('drop table'), isFalse);
      expect(mig.contains('delete from'), isFalse);
      // Yalnız iki driver-FK alter edilir (owner_id/patron FK'leri alter edilmez).
      expect('alter table'.allMatches(mig).length, 4); // 2 drop + 2 add
      expect(mig.contains('alter constraint'), isFalse);
    });
  });

  group('delete-account kontratı — yalnız caller, canlı silme yok', () {
    final fn = _read('supabase/functions/delete-account/index.ts');

    test('caller JWT doğrulanır + yalnız callerId silinir', () {
      expect(fn.contains('getUser()'), isTrue);
      expect(fn.contains('deleteUser(callerId)'), isTrue);
      // confirm zorunlu + body/query user_id KABUL ETMEZ
      expect(fn.contains('confirm'), isTrue);
      expect(fn.contains("'confirm_required'"), isTrue);
    });
  });
}
