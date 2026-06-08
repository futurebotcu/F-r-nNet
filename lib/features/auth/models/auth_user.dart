/// Supabase Auth kullanıcısının minimal yansıması.
/// UI / repository sınırında [auth.users] tablosundaki tam satır
/// yerine kullanılır — gizlilik için yalnız id ve email tutulur.
class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String? email;
}
