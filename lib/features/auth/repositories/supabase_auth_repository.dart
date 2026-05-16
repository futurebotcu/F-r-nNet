import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/app_config.dart';
import '../models/auth_user.dart';
import '../models/sign_up_result.dart';
import '../utils/auth_error_translator.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final sb.SupabaseClient _client;

  AuthUser? _from(sb.User? u) =>
      u == null ? null : AuthUser(id: u.id, email: u.email);

  @override
  AuthUser? get currentUser => _from(_client.auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((e) => _from(e.session?.user));
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      final user = res.user;
      if (user == null) {
        // GoTrue normalde user dolu döner; bu beklenmedik bir durum.
        throw Exception('Kayıt tamamlanamadı.');
      }
      // res.session null ise mailer_autoconfirm kapalı; kullanıcı oluşturuldu
      // ama oturum açık değil. Çağıran UI bu flag'e bakıp "E-postanı onayla"
      // akışını tetiklemelidir.
      return SignUpResult(
        user: _from(user)!,
        needsEmailConfirmation: res.session == null,
      );
    } catch (e) {
      throw Exception(translateAuthError(e));
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw Exception('Giriş başarısız.');
      }
      return _from(user)!;
    } catch (e) {
      throw Exception(translateAuthError(e));
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: AppConfig.authRedirectUrl,
      );
    } catch (e) {
      throw Exception(translateAuthError(e));
    }
  }

  @override
  Future<void> signInWithApple() async {
    try {
      await _client.auth.signInWithOAuth(
        sb.OAuthProvider.apple,
        redirectTo: AppConfig.authRedirectUrl,
      );
    } catch (e) {
      throw Exception(translateAuthError(e));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception(translateAuthError(e));
    }
  }

  @override
  Future<void> updateEmail(String email) async {
    try {
      await _client.auth.updateUser(sb.UserAttributes(email: email));
    } catch (e) {
      throw Exception(translateAuthError(e));
    }
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception(translateAuthError(e));
    }
  }

  @override
  Future<void> deleteAccount() async {
    // Önkoşul: caller'ın aktif bir oturumu olmalı (function caller JWT'sini
    // server-side doğrular). Yoksa erken hata ver — Edge'e gereksiz çağrı
    // atılmasın.
    if (_client.auth.currentUser == null) {
      throw Exception('Hesap silmek için giriş yapman gerekiyor.');
    }

    try {
      final res = await _client.functions.invoke(
        'delete-account',
        body: <String, dynamic>{'confirm': true},
      );

      // Supabase FunctionsResponse status alanı 200 dışı bir kod döndürürse
      // function hata raporlamış demektir. Body içeriği client'a açılmaz —
      // function dış dünyaya generic mesaj döner.
      if (res.status != 200) {
        throw Exception('Hesap silinemedi.');
      }

      // Server-side hesap silindiği için mevcut JWT geçersizdir. signOut
      // best-effort; başarısızlık burada blocker değil — local state
      // ProfileScreen tarafından temizlenir.
      try {
        await _client.auth.signOut();
      } catch (_) {
        // user gone — beklenen.
      }
    } catch (e) {
      throw Exception(translateAuthError(e));
    }
  }
}
