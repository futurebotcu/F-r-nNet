import '../../../core/constants/app_strings.dart';
import '../../profile/models/bakery_profile.dart';
import 'business_entitlements.dart';

/// İlan türü (fiyat kararı için). Server `get_listing_fee_amount_cents`
/// listing_type parametresiyle birebir.
enum ListingKind { jobSeek, jobOffer, market }

/// İlan yayın ücreti — server `get_listing_fee_amount_cents` mantığının
/// client aynası (YALNIZ görüntüleme/UX; asıl karar + zorlama server-side
/// trigger + SELECT gate'inde).
///
/// Kural: iş arama her zaman ücretsiz; diğer türler commercial + effective
/// plan pro/premium/trial ise ücretsiz, aksi 50 TL.
class ListingFee {
  const ListingFee._();

  /// Sabit ücret (kuruş) — 50 TL.
  static const int feeCents = 5000;

  static int amountCents({
    required ListingKind kind,
    required AccountType? account,
    required BusinessEntitlements? entitlements,
  }) {
    if (kind == ListingKind.jobSeek) return 0;
    final exempt =
        account == AccountType.commercial &&
        entitlements != null &&
        (entitlements.isPro || entitlements.isPremium);
    return exempt ? 0 : feeCents;
  }

  static bool isRequired({
    required ListingKind kind,
    required AccountType? account,
    required BusinessEntitlements? entitlements,
  }) =>
      amountCents(kind: kind, account: account, entitlements: entitlements) > 0;

  /// Form'da gösterilecek bilgilendirme gövdesi (role/plan'a göre).
  static String noticeBody({
    required ListingKind kind,
    required AccountType? account,
    required BusinessEntitlements? entitlements,
  }) {
    if (kind == ListingKind.jobSeek) return AppStrings.listingFeeFreeSeek;
    final free =
        amountCents(kind: kind, account: account, entitlements: entitlements) ==
        0;
    if (free) return AppStrings.listingFeeFreePlan;
    switch (account) {
      case AccountType.wholesaler:
        return AppStrings.listingFeeSupplierBody;
      case AccountType.individual:
        return AppStrings.listingFeeIndividualBody;
      case AccountType.commercial:
      case null:
        return AppStrings.listingFeePaidBody;
    }
  }
}
