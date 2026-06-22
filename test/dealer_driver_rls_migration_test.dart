// FN-AUDIT-005 — Şoför RLS + write-RPC migration zinciri kaynak-assertion'ı.
//
// Şoför yetki sistemi en kritik güvenlik yüzeyi; RLS/RPC Dart'ta runtime test
// edilemez. Bu test migration dosyalarını STATİK okuyup kritik güvenlik
// invariant'larını kilitler — biri `using (true)` yapsa, owner/assigned/permission
// guard'ını veya search_path'i gevşetse CI'da yakalanır. Gerçek DB'ye bağlanmaz.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('Read-only RLS — atanmış şoför yalnız okur', () {
    final src = _read(
      'supabase/migrations/20260619190000_dealer_driver_readonly_rls.sql',
    );
    final lower = src.toLowerCase();

    test('dealer_drivers self-select auth.uid() ile sınırlı', () {
      expect(lower.contains('dealer_drivers_select_self'), isTrue);
      expect(lower.contains('driver_user_id = auth.uid()'), isTrue);
    });

    test('atanmış bayi/hareket SELECT atama + aktiflik gerektirir', () {
      for (final p in [
        'dealers_select_assigned_driver',
        'dealer_transactions_select_assigned_driver',
        'dealer_deliveries_select_assigned_driver',
      ]) {
        expect(lower.contains(p), isTrue, reason: '$p eksik');
      }
      expect(lower.contains('d.driver_user_id = auth.uid()'), isTrue);
      expect(lower.contains('d.is_active'), isTrue);
      // `using (true)` gibi açık politika regresyonu OLMAMALI.
      expect(lower.contains('using (true)'), isFalse);
    });

    test('şoföre INSERT/UPDATE/DELETE politikası YOK (yalnız select)', () {
      expect(lower.contains('for insert'), isFalse);
      expect(lower.contains('for update'), isFalse);
      expect(lower.contains('for delete'), isFalse);
    });
  });

  group('Write-RPC — driver_add_transaction güvenli', () {
    final src = _read(
      'supabase/migrations/20260619210000_dealer_driver_write_rpc.sql',
    );
    final lower = src.toLowerCase();

    test('SECURITY DEFINER + boş search_path', () {
      expect(lower.contains('security definer'), isTrue);
      expect(lower.contains("set search_path = ''"), isTrue);
    });

    test('auth + atanmış şoför + owner-mismatch guard', () {
      expect(lower.contains('v_uid uuid := auth.uid()'), isTrue);
      expect(lower.contains('dealer_driver_assignments'), isTrue);
      expect(lower.contains('dd.driver_user_id = v_uid'), isTrue);
      expect(lower.contains('dd.is_active = true'), isTrue);
      expect(lower.contains("raise exception 'not assigned to this dealer'"),
          isTrue);
      expect(lower.contains('v_dealer_owner <> v_owner'), isTrue);
      expect(lower.contains("raise exception 'owner mismatch'"), isTrue);
    });

    test('owner_id daima patron (v_owner) ile yazılır', () {
      // delivery + transaction insert'leri v_owner taşır (şoförün uid\'i değil).
      expect(lower.contains('insert into public.dealer_deliveries'), isTrue);
      expect(lower.contains('insert into public.dealer_transactions'), isTrue);
      expect(lower.contains('v_owner'), isTrue);
    });

    test('public/anon execute kapalı', () {
      expect(lower.contains('revoke execute on function'), isTrue);
      expect(lower.contains('from public, anon'), isTrue);
    });
  });

  group('Permission levels — half/full ayrımı server-side', () {
    final src = _read(
      'supabase/migrations/20260620130000_dealer_driver_permission_levels.sql',
    );
    final lower = src.toLowerCase();

    test('permission_level kolonu + CHECK(half/full)', () {
      expect(lower.contains('permission_level'), isTrue);
      expect(lower.contains("check (permission_level in ('half','full'))"),
          isTrue);
    });

    test('adjustment + driver_set_price + driver_delete yalnız FULL', () {
      // Üç yetki-kapısı da `<> 'full' → permission required` kullanır.
      final fullGuards = "coalesce(v_perm, 'half') <> 'full'".allMatches(lower).length;
      expect(fullGuards >= 3, isTrue,
          reason: 'adjustment/set_price/delete için full-guard sayısı < 3');
      expect(lower.contains("raise exception 'permission required'"), isTrue);
      expect(lower.contains('driver_set_price'), isTrue);
      expect(lower.contains('driver_delete_transaction'), isTrue);
    });

    test('full-only RPC\'ler SECURITY DEFINER + güvenli search_path', () {
      expect(lower.contains('security definer'), isTrue);
      expect(lower.contains("search_path to ''"), isTrue);
      // atama + aktiflik guard'ı her yetki-kapısında tekrarlanır.
      expect(lower.contains('dd.driver_user_id = v_uid'), isTrue);
      expect(lower.contains('dd.is_active = true'), isTrue);
    });
  });
}
