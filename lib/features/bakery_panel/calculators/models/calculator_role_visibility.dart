import '../../../profile/models/bakery_profile.dart';

/// Bir hesaplama aracının hangi hesap türlerine görüneceğini tanımlar.
///
/// Görünürlük kararları ileride değişebilir; bu yüzden araçların kendisi
/// sabit rol listesi gömmez. Görünürlük registry'de [CalculatorRoleVisibility]
/// ile tanımlanır ve hub filtrelemesi tek noktadan yapılır.
class CalculatorRoleVisibility {
  const CalculatorRoleVisibility(this.accountTypes);

  /// Aracın görüneceği hesap türleri kümesi.
  final Set<AccountType> accountTypes;

  /// Tüm rollere açık.
  static const CalculatorRoleVisibility all = CalculatorRoleVisibility(
    <AccountType>{
      AccountType.commercial,
      AccountType.individual,
      AccountType.wholesaler,
    },
  );

  /// Yalnız ticari (fırın / işletme).
  static const CalculatorRoleVisibility commercialOnly =
      CalculatorRoleVisibility(<AccountType>{AccountType.commercial});

  /// Yalnız bireysel (usta / çalışan).
  static const CalculatorRoleVisibility individualOnly =
      CalculatorRoleVisibility(<AccountType>{AccountType.individual});

  /// Üretim yapan roller — ticari + bireysel (toptancı hariç).
  static const CalculatorRoleVisibility producers = CalculatorRoleVisibility(
    <AccountType>{AccountType.commercial, AccountType.individual},
  );

  bool isVisibleTo(AccountType type) => accountTypes.contains(type);
}
