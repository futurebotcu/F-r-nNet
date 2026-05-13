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
}
