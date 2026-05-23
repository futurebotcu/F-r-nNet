// FırınNet ID Foundation — invariant testleri.
//
// Karar:
//   * Format: FN-YYYY-NNNNNN (örn. FN-2026-000001).
//   * profiles.firinnet_id text UNIQUE + format CHECK regex.
//   * Per-year counter tablosu (firinnet_id_counters) + atomic INSERT
//     ON CONFLICT DO UPDATE + SECURITY DEFINER function.
//   * handle_new_user trigger insert sırasında otomatik atar; conflict'te
//     ezmez.
//   * Mevcut row'lar tek UPDATE ile backfill (her satır farklı counter).
//   * GİZLİLİK: yalnız sahibine gösterilir; public_profile_snapshot ve
//     public_profile_detail RPC'lerinde whitelist'te YOK. profiles RLS
//     owner-only zaten başka kullanıcıya sızdırmaz.
//   * Client UPDATE patch'ine eklenmez (sadece server-side trigger atar).

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FırınNet ID — Migration source', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260524180000_firinnet_id_foundation.sql',
      ).readAsStringSync();
    });

    test('Per-year counter tablosu + RLS açık + policy yok', () {
      expect(
          sql.contains(
              'create table if not exists public.firinnet_id_counters'),
          isTrue);
      expect(
          sql.contains('alter table public.firinnet_id_counters enable row level security'),
          isTrue);
      // policy yok — `create policy ... on public.firinnet_id_counters` aranır
      expect(sql.contains('on public.firinnet_id_counters'), isFalse);
    });

    test('profiles.firinnet_id text + UNIQUE + format CHECK regex', () {
      expect(
          sql.contains(
              'alter table public.profiles\n  add column if not exists firinnet_id text'),
          isTrue);
      expect(
          sql.contains(r"~ '^FN-[0-9]{4}-[0-9]{6}$'"), isTrue,
          reason: 'Format CHECK regex bulunmalı');
      expect(sql.contains('profiles_firinnet_id_unique unique (firinnet_id)'),
          isTrue);
    });

    test('generate_firinnet_id() SECURITY DEFINER + revoke public', () {
      expect(
          sql.contains('create or replace function public.generate_firinnet_id()'),
          isTrue);
      expect(sql.contains('security definer'), isTrue);
      expect(
          sql.contains(
              'revoke all on function public.generate_firinnet_id() from public'),
          isTrue);
      expect(
          sql.contains(
              'revoke all on function public.generate_firinnet_id() from anon, authenticated'),
          isTrue);
    });

    test('handle_new_user trigger firinnet_id insert clause\'ında', () {
      expect(sql.contains('email, firinnet_id'), isTrue);
      expect(sql.contains('public.generate_firinnet_id()'), isTrue);
    });

    test('Backfill: mevcut null row\'lar için generate çağrısı', () {
      expect(
          sql.contains(
              'update public.profiles\n   set firinnet_id = public.generate_firinnet_id()\n where firinnet_id is null'),
          isTrue);
    });
  });

  group('FırınNet ID — Public sızıntı guard (RPC whitelist)', () {
    test('public_profile_snapshot RPC kaynağında firinnet_id YOK', () {
      // M5 + M6A migration'larının değiştirdiği RPC — public_profile_detail
      // ve public_profile_snapshot whitelist'lerinde firinnet_id geçmemeli.
      final detailSql = File(
        'supabase/migrations/20260520170000_unified_profile_public_rpc.sql',
      ).readAsStringSync();
      expect(detailSql.contains('firinnet_id'), isFalse,
          reason:
              'public_profile_detail kaynak migration\'ında firinnet_id yer almamalı');

      // M7 migration RPC'yi son güncelledi.
      final m7Sql = File(
        'supabase/migrations/20260524120000_worker_skill_codes.sql',
      ).readAsStringSync();
      expect(m7Sql.contains('firinnet_id'), isFalse,
          reason:
              'M7 RPC redefine\'ında firinnet_id whitelist\'te olmamalı');
    });

    test('FırınNet ID migration RPC redefine ETMEZ (public_profile_detail değişmiyor)',
        () {
      // Yorum satırlarını ayıkla — kod satırlarında RPC referansı olmamalı.
      final sql = File(
        'supabase/migrations/20260524180000_firinnet_id_foundation.sql',
      ).readAsStringSync();
      final codeOnly = sql
          .split('\n')
          .map((l) => l.trimLeft())
          .where((l) => !l.startsWith('--'))
          .join('\n');
      expect(
          codeOnly.contains('public_profile_detail') ||
              codeOnly.contains('public_profile_snapshot'),
          isFalse,
          reason:
              'FırınNet ID migration RPC\'lere dokunmamalı — sızıntı vektörü olmamalı');
    });
  });

  group('FırınNet ID — Repository update path GÜVENLİK', () {
    test('SupabaseProfileRepository.updateProfile patch\'i firinnet_id YOK',
        () {
      final src = File(
        'lib/features/profile/repositories/supabase_profile_repository.dart',
      ).readAsStringSync();
      // patch map'inde firinnet_id field'ı OLMAMALI — client değiştiremez.
      // updateProfile fonksiyonunun gövdesi içinde "'firinnet_id'" string
      // literal'i geçmemeli (sadece SELECT clause'da geçer).
      final updateBody = src.substring(
        src.indexOf('updateProfile({'),
        src.indexOf('return _fromRow(updated);') + 30,
      );
      expect(updateBody.contains("'firinnet_id'"), isFalse,
          reason:
              'updateProfile patch\'i client-side firinnet_id yazımına izin vermemeli');
      // _fromRow ise firinnet_id parse eder (read-only).
      expect(src.contains("row['firinnet_id'] as String?"), isTrue);
      // SELECT clause'da olmalı (kendi profile fetch için).
      expect(src.contains('firinnet_id'), isTrue);
    });
  });

  group('FırınNet ID — BakeryProfile.firinnetId model', () {
    test('Yeni alan opsiyonel; default null', () {
      const p = BakeryProfile(
        displayName: 'H',
        accountType: AccountType.individual,
        city: 'İst',
        roleBadge: 'X',
        email: '',
      );
      expect(p.firinnetId, isNull);
    });

    test('copyWith default → firinnetId korunur', () {
      const p = BakeryProfile(
        displayName: 'H',
        accountType: AccountType.individual,
        city: 'İst',
        roleBadge: 'X',
        email: '',
        firinnetId: 'FN-2026-000001',
      );
      final c = p.copyWith(displayName: 'Y');
      expect(c.firinnetId, 'FN-2026-000001');
    });

    test('copyWith null geçince → firinnetId null\'a düşer (sentinel)', () {
      const p = BakeryProfile(
        displayName: 'H',
        accountType: AccountType.individual,
        city: 'İst',
        roleBadge: 'X',
        email: '',
        firinnetId: 'FN-2026-000001',
      );
      final c = p.copyWith(firinnetId: null);
      expect(c.firinnetId, isNull);
    });
  });

  group('FırınNet ID — UI: yalnız Settings ekranında, public alanlarda YOK',
      () {
    test('Settings ekranında firinnet_id satırı + kopyala mantığı', () {
      final src = File(
        'lib/features/settings/screens/settings_screen.dart',
      ).readAsStringSync();
      expect(src.contains('settingsFirinnetIdTitle'), isTrue);
      expect(src.contains('profile?.firinnetId'), isTrue);
      // Sadece dolu ise göster.
      expect(src.contains('firinnetId != null && firinnetId.isNotEmpty'),
          isTrue);
      // Kopyala
      expect(src.contains('Clipboard.setData'), isTrue);
      expect(src.contains('settingsFirinnetIdCopied'), isTrue);
    });

    test('SocialProfilePage (public profile) firinnetId\'yi göstermez', () {
      final src = File(
        'lib/features/social/profile/profile_page.dart',
      ).readAsStringSync();
      expect(src.contains('firinnetId'), isFalse);
      expect(src.contains('firinnet_id'), isFalse);
    });

    test('ProfileHeader widget firinnetId\'yi göstermez', () {
      final src = File(
        'lib/features/social/profile/widgets/profile_header.dart',
      ).readAsStringSync();
      expect(src.contains('firinnetId'), isFalse);
    });

    test('SocialPostCard (feed/comment author) firinnetId\'yi göstermez',
        () {
      final src = File(
        'lib/features/social/post/social_post_card.dart',
      ).readAsStringSync();
      expect(src.contains('firinnetId'), isFalse);
    });

    test('ProfileEditSheet firinnetId field göstermez (read-only zaten)',
        () {
      final src = File(
        'lib/features/profile/widgets/profile_edit_sheet.dart',
      ).readAsStringSync();
      // Edit sheet'in firinnetId TextField'ı olmamalı.
      expect(src.contains('firinnetId'), isFalse);
    });
  });

  group('FırınNet ID — AppStrings', () {
    test('Title + kopyalandı snackbar metni var', () {
      expect(AppStrings.settingsFirinnetIdTitle, 'FırınNet ID');
      expect(AppStrings.settingsFirinnetIdCopied, isNotEmpty);
    });
  });
}
