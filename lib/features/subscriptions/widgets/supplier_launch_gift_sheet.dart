import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/subscription_providers.dart';

/// Tedarikçi Lansman Kampanyası bilgilendirme pop-up'ı.
///
/// YALNIZ bilgilendirir: satın alma, abonelik onayı veya kart ekleme
/// BAŞLATMAZ. Kampanya hakkı bu pop-up'a basılmasına bağlı değildir —
/// server uygun hesaplara doğrudan uygular. Gerçek bitiş tarihi server
/// config'inden gelir; tarih yoksa bu yüzey hiç gösterilmez (placeholder
/// tarih kullanılmaz).
Future<void> showSupplierLaunchGiftSheet(
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
    builder: (sheetContext) => SupplierLaunchGiftSheetBody(
      freeUntil: freeUntil,
    ),
  ).whenComplete(() {
    // Görüldü kaydı kapanış yolundan bağımsız düşer (buton veya kaydırarak
    // kapatma) — pop-up kullanıcı/kampanya bazında yeniden açılmaz.
    final callback = onClosed;
    if (callback != null) callback();
  });
}

String formatSupplierLaunchDate(DateTime date) =>
    DateFormat('d MMMM yyyy', 'tr_TR').format(date.toLocal());

class SupplierLaunchGiftSheetBody extends StatelessWidget {
  const SupplierLaunchGiftSheetBody({super.key, required this.freeUntil});

  final DateTime freeUntil;

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatSupplierLaunchDate(freeUntil);
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
                    Icons.card_giftcard_rounded,
                    size: 22,
                    color: AppColors.brandInk,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      AppStrings.supplierLaunchGiftTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Container(
              key: const ValueKey('supplier_launch_date_highlight'),
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
                      '$dateLabel '
                      '${AppStrings.supplierLaunchGiftFreeSuffix}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandInk,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text(
              AppStrings.supplierLaunchGiftBody,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            const Text(
              AppStrings.supplierLaunchGiftContinueInfo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
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
                    AppStrings.supplierLaunchGiftAssurance,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton(
              key: const ValueKey('supplier_launch_gift_cta'),
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
                AppStrings.supplierLaunchGiftCta,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oturum içi çift tetiklemeye karşı koruma (iki yüzey aynı anda isterse).
/// Kalıcı "görüldü" kaydı server-side'dadır; bu yalnız aynı oturumda async
/// yarışları keser.
bool _sessionAttempted = false;

@visibleForTesting
void resetSupplierLaunchGiftSessionGuard() {
  _sessionAttempted = false;
}

/// Kampanya penceresindeki tedarikçiye pop-up'ı İLK uygun oturumda bir kez
/// gösterir. Koşullar: kampanya server'da aktif + gerçek bitiş tarihi var +
/// kullanıcı daha önce görmemiş (server kaydı). Uygun değilse sessizce çıkar.
Future<void> maybeShowSupplierLaunchGiftSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  if (_sessionAttempted) return;
  final entitlement = ref.read(myEntitlementProvider).valueOrNull;
  if (entitlement == null) return;
  final freeUntil = entitlement.supplierLaunchFreeUntil;
  // Kampanya bitmiş/pasif veya tarih yapılandırılmamış → gösterme.
  if (!entitlement.supplierLaunchFreeActive || freeUntil == null) return;
  _sessionAttempted = true;

  final repo = ref.read(subscriptionRepositoryProvider);
  try {
    if (await repo.hasSeenSupplierLaunchNotice()) return;
  } catch (_) {
    // Görüldü kaydı okunamadıysa tekrar tekrar açma riskine girme.
    return;
  }
  if (!context.mounted) return;
  await showSupplierLaunchGiftSheet(
    context,
    freeUntil: freeUntil,
    onClosed: () async {
      try {
        await repo.markSupplierLaunchNoticeSeen();
      } catch (_) {
        // Yazım hatası bir sonraki oturumda telafi edilir.
      }
    },
  );
}
