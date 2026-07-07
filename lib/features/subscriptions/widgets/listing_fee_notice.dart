import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/listing_fee.dart';
import '../providers/subscription_providers.dart';

/// İlan formunda gösterilen ücret bilgilendirme şeridi.
///
/// Ücretsiz ilan → yeşilimsi "ücretsiz" notu. Ücretli ilan → sarı "50 TL,
/// ödeme sonrası yayınlanır" notu. Asıl zorlama server-side (bu yalnız
/// bilgilendirme). Ödeme butonu YOK.
class ListingFeeNotice extends ConsumerWidget {
  const ListingFeeNotice({super.key, required this.kind});

  final ListingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(profileControllerProvider)?.accountType;
    // Ücret muafiyeti yalnız ticari plan'a bağlı; entitlement yalnız ticaride
    // okunur (bireysel/toptancı için gereksiz).
    final entitlements = account == AccountType.commercial
        ? ref.watch(myEntitlementProvider).valueOrNull
        : null;
    final free =
        ListingFee.amountCents(
          kind: kind,
          account: account,
          entitlements: entitlements,
        ) ==
        0;
    final body = ListingFee.noticeBody(
      kind: kind,
      account: account,
      entitlements: entitlements,
    );
    final (bg, border, fg, icon) = free
        ? (
            const Color(0xFFF3FBEF),
            const Color(0xFFCDEBBF),
            const Color(0xFF166534),
            Icons.verified_outlined,
          )
        : (
            const Color(0xFFFFF7E6),
            const Color(0xFFFCD9A0),
            const Color(0xFFB45309),
            Icons.info_outline_rounded,
          );
    return Container(
      key: const ValueKey('listing_fee_notice'),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!free)
                  Text(
                    AppStrings.listingFeePaidTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: fg,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ödeme bekliyor" rozeti — owner kendi ücretli-bekleyen ilanında görür.
class ListingPendingBadge extends StatelessWidget {
  const ListingPendingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('listing_pending_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: const Color(0xFFFCD9A0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.schedule_rounded, size: 11, color: Color(0xFFB45309)),
          SizedBox(width: 3),
          Text(
            AppStrings.listingFeePendingBadge,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }
}
