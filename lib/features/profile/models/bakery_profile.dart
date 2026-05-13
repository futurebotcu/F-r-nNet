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
  });

  final String displayName;
  final AccountType accountType;
  final String city;
  final String roleBadge;
  final String email;

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
  }) {
    return BakeryProfile(
      displayName: displayName ?? this.displayName,
      accountType: accountType ?? this.accountType,
      city: city ?? this.city,
      roleBadge: roleBadge ?? this.roleBadge,
      email: email ?? this.email,
    );
  }

  static const BakeryProfile guest = BakeryProfile(
    displayName: 'Misafir',
    accountType: AccountType.individual,
    city: '',
    roleBadge: 'Diğer',
    email: '',
  );
}
