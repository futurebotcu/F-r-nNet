import '../models/bakery_profile.dart';

/// `public.profiles` tablosu için CRUD soyutlaması.
///
/// - email asla bu repository üzerinden yazılmaz; Supabase Auth
///   `updateUser(email:)` çağrısı + DB triggerı bunu profiles satırına
///   senkronize eder.
/// - profile satırı `handle_new_user` triggerıyla signup sonrası
///   otomatik oluşur; client INSERT etmez.
abstract class ProfileRepository {
  Future<BakeryProfile?> fetchProfile(String userId);

  /// Sadece kullanıcının değiştirebileceği alanlar:
  /// display_name / account_type / profession_badge / city / avatar_url.
  Future<BakeryProfile> updateProfile({
    required String userId,
    required BakeryProfile profile,
  });
}
