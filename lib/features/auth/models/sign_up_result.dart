import 'auth_user.dart';

/// `AuthRepository.signUp` çağrısının sonucu.
///
/// Supabase Auth iki farklı response biçimi döndürür:
/// - `mailer_autoconfirm = true` (veya OAuth) → response içinde hem `user`
///   hem `session` dolu; kullanıcı doğrulanmış sayılır, oturum açılmıştır.
/// - `mailer_autoconfirm = false` → response yalnız `user` döner, `session`
///   null'dır; kullanıcı e-posta linkini onaylayana kadar oturum açmaz.
///
/// UI tarafı [needsEmailConfirmation] flag'ine bakarak akışı doğru yönlendirir
/// (alert + login ekranı vs. doğrudan splash/feed).
class SignUpResult {
  const SignUpResult({
    required this.user,
    required this.needsEmailConfirmation,
  });

  final AuthUser user;

  /// `true` → response'da session null gelmiştir; kullanıcı kayıt oldu ama
  /// e-posta onayı bekleniyor. App bu durumda kullanıcıyı Feed/Splash'a
  /// göndermez; "E-postanı onayla" bilgisi gösterip Login ekranına yönlendirir.
  final bool needsEmailConfirmation;
}
