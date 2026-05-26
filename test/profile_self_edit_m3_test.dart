// FırınNet Profile Self-Edit M3 — invariant testleri.
//
// Sprint kararı:
//   * profiles.avatar_url update path eklendi (RPC zaten döndürüyordu).
//   * `avatars/` public storage bucket + 4 RLS policy (feed-media şablonu).
//   * AvatarUploadService: galeri → bucket'a `<userId>/avatar_<ts>.<ext>`.
//   * ProfileEditSheet: avatar tile + Ad + Şehir + Hesap tipi + Kaydet +
//     Ustalık linki.
//   * SocialProfilePage `_SelfEditCta` artık /worker/profile yerine sheet
//     açar; Ustalık linki sheet altında ayrı tek satır.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M3 — BakeryProfile.avatarUrl + copyWith', () {
    test('Yeni avatarUrl alanı opsiyonel; default null', () {
      const p = BakeryProfile(
        displayName: 'Hasan',
        accountType: AccountType.individual,
        city: 'İstanbul',
        roleBadge: 'Usta',
        email: 'h@h.com',
      );
      expect(p.avatarUrl, isNull);
    });

    test('copyWith default → avatarUrl korunur', () {
      const p = BakeryProfile(
        displayName: 'Hasan',
        accountType: AccountType.individual,
        city: 'İstanbul',
        roleBadge: 'Usta',
        email: 'h@h.com',
        avatarUrl: 'https://x/a.jpg',
      );
      final c = p.copyWith(city: 'Bursa');
      expect(c.avatarUrl, 'https://x/a.jpg');
      expect(c.city, 'Bursa');
    });

    test('copyWith null geçince → avatarUrl null\'a düşer (sentinel)', () {
      const p = BakeryProfile(
        displayName: 'Hasan',
        accountType: AccountType.individual,
        city: 'İstanbul',
        roleBadge: 'Usta',
        email: 'h@h.com',
        avatarUrl: 'https://x/a.jpg',
      );
      final c = p.copyWith(avatarUrl: null);
      expect(c.avatarUrl, isNull);
    });
  });

  group('M3 — Migration avatars bucket + 4 policy', () {
    late String sql;
    setUpAll(() {
      sql = File(
        'supabase/migrations/20260523120000_avatars_bucket_public.sql',
      ).readAsStringSync();
    });

    test('avatars bucket public=true insert', () {
      expect(
        sql.contains('insert into storage.buckets (id, name, public)'),
        isTrue,
      );
      expect(sql.contains("'avatars', 'avatars', true"), isTrue);
    });

    test('4 storage policy tanımlı (SELECT/INSERT/UPDATE/DELETE)', () {
      expect(sql.contains('avatars_storage_select'), isTrue);
      expect(sql.contains('avatars_storage_insert_owner'), isTrue);
      expect(sql.contains('avatars_storage_update_owner'), isTrue);
      expect(sql.contains('avatars_storage_delete_owner'), isTrue);
    });

    test('SELECT public; write owner-prefix path RLS', () {
      expect(sql.contains('for select to public'), isTrue);
      expect(sql.contains('for insert to authenticated'), isTrue);
      expect(
        sql.contains('(storage.foldername(name))[1] = auth.uid()::text'),
        isTrue,
      );
    });
  });

  group('M3 — SupabaseProfileRepository avatar_url okur ve yazar', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/profile/repositories/supabase_profile_repository.dart',
      ).readAsStringSync();
    });

    test('_fromRow avatar_url okur', () {
      expect(src.contains("row['avatar_url'] as String?"), isTrue);
      expect(src.contains('avatarUrl:'), isTrue);
    });

    test('updateProfile patch avatar_url içerir', () {
      expect(src.contains("'avatar_url':"), isTrue);
    });
  });

  group('M3 — AvatarUploadService path + bucket', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/profile/services/avatar_upload_service.dart',
      ).readAsStringSync();
    });

    test('Bucket adı `avatars`', () {
      expect(src.contains("static const String bucket = 'avatars'"), isTrue);
    });

    test('Path scheme `<userId>/avatar_<ts>.<ext>`', () {
      expect(src.contains("'\$userId/avatar_\$ts.\$ext'"), isTrue);
    });

    test('Galeri kaynaklı pickImage', () {
      expect(src.contains('ImageSource.gallery'), isTrue);
    });

    test('uploadBinary + getPublicUrl', () {
      expect(src.contains('uploadBinary'), isTrue);
      expect(src.contains('getPublicUrl'), isTrue);
    });
  });

  group('M3 — ProfileEditSheet UI invariant', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/profile/widgets/profile_edit_sheet.dart',
      ).readAsStringSync();
    });

    test('Sheet 3 alan + avatar tile + Ustalık link içerir', () {
      expect(src.contains('profileEditNameLabel'), isTrue);
      expect(src.contains('profileEditCityLabel'), isTrue);
      expect(src.contains('profileEditAccountTypeLabel'), isTrue);
      expect(src.contains('_AvatarTile'), isTrue);
      expect(src.contains('_WorkerLinkRow'), isTrue);
      expect(src.contains('AppRoutes.workerProfile'), isTrue);
    });

    test('Guest guard + auth required sheet kullanır', () {
      expect(src.contains('AuthRequiredGuard.canWriteWithRef(ref)'), isTrue);
      expect(src.contains('showAuthRequiredSheet'), isTrue);
    });

    test('Save sonrası publicProfileDetailProvider invalidate', () {
      expect(
        src.contains('ref.invalidate(publicProfileDetailProvider'),
        isTrue,
      );
    });
  });

  group('M3 — SocialProfilePage SelfEditCta sheet\'e bağlı', () {
    late String src;
    setUpAll(() {
      src = File(
        'lib/features/social/profile/profile_page.dart',
      ).readAsStringSync();
    });

    test('isSelf CTA artık ProfileEditSheet.show açar', () {
      expect(src.contains('ProfileEditSheet.show(context)'), isTrue);
    });

    test('Eski "_SelfEditCta → /worker/profile" doğrudan push kaldırıldı',
        () {
      // Sheet içinde worker link var ama _SelfEditCta callback'i artık
      // doğrudan workerProfile push etmiyor. Source'ta hâlâ
      // AppRoutes.workerProfile import edilebilir (başka kullanım için);
      // sadece _SelfEditCta callback'i sheet açmalı.
      final m =
          RegExp(r'_SelfEditCta\(\s*onTap:\s*\(\)\s*=>\s*([^,)]+)')
              .firstMatch(src);
      expect(m, isNotNull, reason: '_SelfEditCta onTap satırı bulunamadı');
      final callback = m!.group(1)!;
      expect(callback.contains('ProfileEditSheet.show'), isTrue);
      expect(callback.contains('context.push(AppRoutes.workerProfile)'),
          isFalse);
    });
  });

  group('M3 — AppStrings yeni edit sabitleri', () {
    test('Sheet + label + cta + error sabitleri tanımlı', () {
      expect(AppStrings.profileEditSheetTitle, isNotEmpty);
      expect(AppStrings.profileEditNameLabel, isNotEmpty);
      expect(AppStrings.profileEditCityLabel, isNotEmpty);
      expect(AppStrings.profileEditAccountTypeLabel, isNotEmpty);
      expect(AppStrings.profileEditAvatarChange, isNotEmpty);
      expect(AppStrings.profileEditAvatarErrorPick, isNotEmpty);
      expect(AppStrings.profileEditAvatarErrorUpload, isNotEmpty);
      expect(AppStrings.profileEditSaveCta, isNotEmpty);
      expect(AppStrings.profileEditSaveSuccess, isNotEmpty);
      expect(AppStrings.profileEditSaveError, isNotEmpty);
      expect(AppStrings.profileEditNameRequired, isNotEmpty);
      expect(AppStrings.profileEditWorkerLink, isNotEmpty);
    });
  });
}
