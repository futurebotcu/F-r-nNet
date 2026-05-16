import '../models/auth_user.dart';

/// Supabase Auth tabanlı kimlik servisi.
///
/// Implementasyon `handle_new_user` triggerına güvenir: signUp sırasında
/// gönderilen `data` (raw_user_meta_data), backend tarafından
/// `public.profiles` satırına otomatik dönüştürülür. Client BU SINIF
/// üzerinden profil tablosuna asla INSERT yapmaz — yalnız read/update.
abstract class AuthRepository {
  /// Anlık oturum sahibi. Hiç yoksa null.
  AuthUser? get currentUser;

  /// Oturum değişimleri (giriş, çıkış, token refresh).
  Stream<AuthUser?> authStateChanges();

  /// Yeni kullanıcı kaydı.
  ///
  /// [metadata] sözleşmesi (`handle_new_user` ile eşleşir):
  /// ```
  /// {
  ///   'display_name'    : String,
  ///   'account_type'    : 'commercial' | 'individual' | 'wholesaler',
  ///   'profession_badge': String?,
  ///   'city'            : String?,
  /// }
  /// ```
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  });

  Future<AuthUser> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Email değişikliği — `auth.users.email` UPDATE'i triggerla profiles'a
  /// senkronize edilir. Profil tablosuna doğrudan email yazılmaz.
  Future<void> updateEmail(String email);

  /// V1.3.5 — Şifre sıfırlama linki gönderir (Supabase email template).
  /// Tıklanan link Supabase'in default web sayfasına gider; kullanıcı orada
  /// yeni şifresini belirler. Mobile in-app yeni-şifre belirleme akışı
  /// (deep link + UpdatePassword screen) sonraki faza bırakıldı.
  Future<void> resetPasswordForEmail(String email);

  /// V1 — Hesap silme (P0 / KVKK / Play compliance).
  ///
  /// Mimari:
  /// - Client doğrudan `service_role` kullanmaz; bu anahtar mobile binary'ye
  ///   gömülürse RLS bypass edilir.
  /// - Client `delete-account` Supabase Edge Function'ını çağırır.
  /// - Function caller'ın JWT'sini doğrular, **kendi user_id'si dışında bir
  ///   hesabı silemez** ve server-side service_role ile
  ///   `auth.admin.deleteUser(user.id)` çağırır.
  /// - `profiles.id references auth.users(id) on delete cascade` zincirinden
  ///   tüm sosyal/fırın/bayi/worker verisi otomatik temizlenir.
  /// - Başarı sonrası local session signOut edilir; mevcut JWT zaten geçersiz.
  ///
  /// Implementor'lar mutlaka 2-step UI confirmation arkasında çağrılmasını
  /// bekler; tek tıkla silinme olmaz.
  Future<void> deleteAccount();
}
