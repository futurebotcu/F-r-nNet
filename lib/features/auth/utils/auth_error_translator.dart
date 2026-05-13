import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth + ağ hatalarını Türkçe, kullanıcıya gösterilebilir
/// mesajlara çevirir. Bilinmeyen hata için makul bir geri dönüş döndürür.
///
/// UI katmanı SnackBar/dialog'ta doğrudan bu string'i gösterir; ek
/// işleme gerek yok.
String translateAuthError(Object error) {
  if (error is AuthApiException) {
    final code = error.code ?? '';
    final msg = error.message.toLowerCase();
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
