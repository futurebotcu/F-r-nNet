/// Kullanıcı hesap türü. Aynı uygulamayı paylaşan üç farklı rolün
/// dashboard kartları bu enum üzerinden ayrışır.
///
/// İleride Supabase'e taşınırken bu enum, profiller tablosundaki
/// `account_type` (text) sütununa map'lenecek; ad/değer aynı tutuldu.
enum AccountType { commercial, individual, wholesaler }

extension AccountTypeLabel on AccountType {
  /// Profil ekranı ve onboarding chip'lerinde gösterilen Türkçe etiket.
  String get label {
    switch (this) {
      case AccountType.commercial:
        return 'Ticari';
      case AccountType.individual:
        return 'Bireysel';
      case AccountType.wholesaler:
        return 'Toptancı';
    }
  }
}

class BakeryProfile {
  const BakeryProfile({
    required this.displayName,
    required this.accountType,
    required this.city,
    required this.roleBadge,
    required this.email,
    this.avatarUrl,
    this.roleBadgeCode,
  });

  final String displayName;
  final AccountType accountType;
  final String city;

  /// Türkçe label (display fallback, backward compat).
  /// Yeni kayıtlarda dual-write — [roleBadgeCode] de doldurulur.
  final String roleBadge;

  final String email;

  /// M3 Profile Self-Edit — Supabase storage `avatars/` bucket public URL.
  /// null veya boş ise ProfileHeader initial fallback gösterir.
  final String? avatarUrl;

  /// M5 — ASCII profession code (`usta_firinci`, `mayaci`, ...). Yeni yazılan
  /// kayıtlarda dual-write yapılır; UI önce code'u taxonomy ile çevirir,
  /// yoksa [roleBadge] label'ına düşer.
  final String? roleBadgeCode;

  /// V1.3 profile completeness sözleşmesi.
  ///
  /// Zorunlu: `displayName`, `accountType` (enum daima dolu), `city`,
  /// `roleBadge`. Eksikse Splash kullanıcıyı `/profile/create`'e yönlendirir.
  ///
  /// Guest profile (in-memory `BakeryProfile.guest`) için bu false döner —
  /// yani Splash guest'i guest mode flag'ine göre değerlendirir, completeness
  /// üzerinden değil.
  bool get isComplete =>
      displayName.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      roleBadge.trim().isNotEmpty;

  BakeryProfile copyWith({
    String? displayName,
    AccountType? accountType,
    String? city,
    String? roleBadge,
    String? email,
    Object? avatarUrl = _sentinel,
    Object? roleBadgeCode = _sentinel,
  }) {
    return BakeryProfile(
      displayName: displayName ?? this.displayName,
      accountType: accountType ?? this.accountType,
      city: city ?? this.city,
      roleBadge: roleBadge ?? this.roleBadge,
      email: email ?? this.email,
      avatarUrl: identical(avatarUrl, _sentinel)
          ? this.avatarUrl
          : avatarUrl as String?,
      roleBadgeCode: identical(roleBadgeCode, _sentinel)
          ? this.roleBadgeCode
          : roleBadgeCode as String?,
    );
  }

  static const Object _sentinel = Object();

  static const BakeryProfile guest = BakeryProfile(
    displayName: 'Misafir',
    accountType: AccountType.individual,
    city: '',
    roleBadge: 'Diğer',
    email: '',
  );
}
