import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/subscription_providers.dart';
import 'supplier_launch_gift_sheet.dart' show formatSupplierLaunchDate;

/// Bireysel Lansman bilgilendirme pop-up'ı.
///
/// YALNIZ bilgilendirir: satın alma, abonelik veya kart akışı BAŞLATMAZ.
/// Bireysel ücretsiz dönem bu pop-up'a bağlı değildir — server bireysel
/// hesaba zaten hiçbir ücret uygulamaz (subscription_purchase_allowed=false,
/// ilan ücreti config'te kapalı). Gerçek bitiş tarihi server config'inden
/// gelir; tarih yoksa bu yüzey hiç gösterilmez (placeholder tarih yok).
Future<void> showIndividualLaunchSheet(
  BuildContext context, {
  required DateTime freeUntil,
  Future<void> Function()? onClosed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => IndividualLaunchSheetBody(freeUntil: freeUntil),
  ).whenComplete(() {
    // Görüldü kaydı kapanış yolundan bağımsız düşer (buton veya kaydırarak
    // kapatma) — pop-up kullanıcı/kampanya bazında yeniden açılmaz.
    final callback = onClosed;
    if (callback != null) callback();
  });
}

/// Bitiş anı HARİÇ, cihaz saat diliminden bağımsız İstanbul günü:
/// 2027-10-01T00:00+03 → "30 Eylül 2027" (formatSupplierLaunchDate paylaşımlı).
String formatIndividualLaunchDate(DateTime until) =>
    formatSupplierLaunchDate(until);

class IndividualLaunchSheetBody extends StatelessWidget {
  const IndividualLaunchSheetBody({super.key, required this.freeUntil});

  final DateTime freeUntil;

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatIndividualLaunchDate(freeUntil);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        // Küçük ekran + büyük yazı boyutunda taşma yerine kaydırma.
        padding: EdgeInsets.only(
          left: AppSpacing.l,
          right: AppSpacing.l,
          top: AppSpacing.s,
          bottom: AppSpacing.l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandLemonPale,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 22,
                    color: AppColors.brandInk,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      AppStrings.individualLaunchTitle,
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Container(
              key: const ValueKey('individual_launch_date_highlight'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s + 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.brandLemonPale,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: AppColors.brandLemon, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 18,
                    color: AppColors.brandInk,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      '$dateLabel ${AppStrings.individualLaunchFreeSuffix}',
                      style: AppTypography.cardTitle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text(
              AppStrings.individualLaunchBody,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    AppStrings.individualLaunchAssurance,
                    style: AppTypography.meta,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              key: const ValueKey('individual_launch_cta'),
              // Yalnız bilgilendirmeyi kapatır — ödeme/abonelik başlatmaz.
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.brandInk,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
              ),
              child: const Text(
                AppStrings.individualLaunchCta,
                style: AppTypography.buttonLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oturum içi çift tetiklemeye karşı koruma — KULLANICI BAZLI: aynı cihazda
/// hesap değişince ikinci kullanıcı bilgilendirmeyi görebilir. Kalıcı
/// "görüldü" kaydı server-side'dadır; geçici bağlantı hatası kalıcı görüldü
/// sayılmaz (yalnız o oturumda tek deneme — kontrolsüz pop-up döngüsü yok).
String? _sessionAttemptedUserId;

@visibleForTesting
void resetIndividualLaunchSessionGuard() {
  _sessionAttemptedUserId = null;
}

/// Bireysel kullanıcıya bilgilendirme pop-up'ını İLK uygun oturumda bir kez
/// gösterir. Koşullar: server bitiş tarihi yapılandırılmış + henüz geçmemiş +
/// kullanıcı daha önce görmemiş (server kaydı). Uygun değilse sessizce çıkar.
Future<void> maybeShowIndividualLaunchSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final userId = ref.read(currentAuthUserProvider)?.id;
  if (userId == null || _sessionAttemptedUserId == userId) return;
  final entitlement = ref.read(myEntitlementProvider).valueOrNull;
  if (entitlement == null) return;
  final freeUntil = entitlement.individualFreeUntil;
  // Tarih yapılandırılmamış (eski backend) veya dönem bitmiş → gösterme.
  if (freeUntil == null ||
      !DateTime.now().toUtc().isBefore(freeUntil.toUtc())) {
    return;
  }
  _sessionAttemptedUserId = userId;

  final repo = ref.read(subscriptionRepositoryProvider);
  try {
    if (await repo.hasSeenIndividualLaunchNotice()) return;
  } catch (_) {
    // Görüldü kaydı okunamadıysa tekrar tekrar açma riskine girme.
    return;
  }
  if (!context.mounted) return;
  await showIndividualLaunchSheet(
    context,
    freeUntil: freeUntil,
    onClosed: () async {
      try {
        await repo.markIndividualLaunchNoticeSeen();
      } catch (_) {
        // Yazım hatası bir sonraki oturumda telafi edilir.
      }
    },
  );
}
