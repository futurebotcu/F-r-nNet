import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_strings.dart';

/// Supabase Auth + ağ hatalarını Türkçe, kullanıcıya gösterilebilir
/// mesajlara çevirir. Bilinmeyen hata için makul bir geri dönüş döndürür.
///
/// UI katmanı SnackBar/dialog'ta doğrudan bu string'i gösterir; ek
/// işleme gerek yok.
String translateAuthError(Object error) {
  if (error is AuthApiException) {
    final code = error.code ?? '';
    final msg = error.message.toLowerCase();
    // V1.4 — OAuth provider Dashboard'da etkin değilse.
    if (code == 'provider_disabled' ||
        msg.contains('provider is not enabled')) {
      return AppStrings.authProviderDisabled;
    }
    // V1.4 — Kullanıcı browser'da OAuth'u iptal etti.
    if (code == 'oauth_provider_not_supported' ||
        msg.contains('oauth') && msg.contains('cancel')) {
      return AppStrings.authOAuthCancelled;
    }
    if (code == 'invalid_credentials' || msg.contains('invalid login')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
      return 'E-posta adresin henüz onaylanmadı. Gelen kutunu kontrol et.';
    }
    if (code == 'user_already_exists' || msg.contains('already registered')) {
      return 'Bu e-posta zaten kayıtlı. Giriş yapmayı dene.';
    }
    if (code == 'weak_password' || msg.contains('password')) {
      return 'Şifre çok zayıf. En az 6 karakter olmalı.';
    }
    if (msg.contains('rate limit') || code == 'over_request_rate_limit') {
      return 'Çok fazla deneme. Birkaç dakika sonra tekrar dene.';
    }
    return 'Sunucu hatası: ${error.message}';
  }
  // 5xx veya geçici fetch hatası: gotrue retryable olarak işaretler.
  if (error is AuthRetryableFetchException) {
    return 'Sunucuya ulaşılamadı. Birkaç saniye sonra tekrar dene.';
  }
  // 4xx + non-JSON body (yanlış SUPABASE_URL, proxy/gateway HTML, vb.).
  // Ham 'Failed to decode error response' kullanıcıya gösterilmez.
  if (error is AuthUnknownException) {
    return 'Sunucu bağlantısı yapılandırılamadı. Lütfen daha sonra tekrar dene.';
  }
  if (error is AuthException) {
    return error.message.isEmpty
        ? 'Kimlik doğrulama hatası.'
        : error.message;
  }
  final s = error.toString();
  if (s.contains('SocketException') || s.contains('Failed host lookup')) {
    return 'İnternet bağlantısı yok. Bağlantını kontrol et.';
  }
  return 'Beklenmeyen bir hata oluştu. Tekrar dene.';
}
