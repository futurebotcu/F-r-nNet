import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/business_entitlements.dart';
import '../models/pricing_config.dart';
import '../providers/subscription_providers.dart';
import 'supplier_launch_gift_sheet.dart' show formatSupplierLaunchDate;

/// Ticari lansman bilgilendirme pop-up türleri. Görüldü kaydı kullanıcı +
/// tür + kampanya bazında kalıcıdır (server); aynı cihazda hesap değişince
/// ikinci kullanıcı kendi bilgilendirmesini görür.
enum CommercialLaunchNotice {
  welcome('welcome_ack'),
  ending('ending_ack'),
  ended('ended_ack');

  const CommercialLaunchNotice(this.noticeKey);
  final String noticeKey;
}

/// Bitiş anı HARİÇTİR; son ücretsiz GÜN, cihaz saat diliminden bağımsız
/// Europe/Istanbul'a göre gösterilir (tedarikçi kampanyasıyla aynı kural).
String formatCommercialLaunchDay(DateTime until) =>
    formatSupplierLaunchDate(until);

/// YALNIZ bilgilendirir: ödeme, abonelik onayı veya kart akışı BAŞLATMAZ.
/// "Premium'a devam et" yalnız Paketler ekranını açar.
Future<void> showCommercialLaunchSheet(
  BuildContext context, {
  required CommercialLaunchNotice notice,
  required BusinessEntitlements entitlement,
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
    builder: (sheetContext) => CommercialLaunchSheetBody(
      notice: notice,
      entitlement: entitlement,
    ),
  ).whenComplete(() {
    // Görüldü kaydı kapanış yolundan bağımsız düşer.
    final callback = onClosed;
    if (callback != null) callback();
  });
}

class CommercialLaunchSheetBody extends StatelessWidget {
  const CommercialLaunchSheetBody({
    super.key,
    required this.notice,
    required this.entitlement,
  });

  final CommercialLaunchNotice notice;
  final BusinessEntitlements entitlement;

  @override
  Widget build(BuildContext context) {
    final ends = entitlement.freePeriodEndsAt;
    final endDay = ends == null ? '' : formatCommercialLaunchDay(ends);
    final priceUntil = entitlement.launchPriceUntil;
    final ended = notice == CommercialLaunchNotice.ended;

    final String headline;
    switch (notice) {
      case CommercialLaunchNotice.welcome:
        headline = '${AppStrings.commercialWelcomePrefix}$endDay '
            '${AppStrings.commercialWelcomeSuffix}';
      case CommercialLaunchNotice.ending:
        headline = '${AppStrings.commercialEndingPrefix}'
            '${entitlement.freePeriodDaysLeft}'
            '${AppStrings.commercialEndingMid}$endDay '
            '${AppStrings.commercialWelcomeSuffix}';
      case CommercialLaunchNotice.ended:
        headline = AppStrings.commercialEndedTitle;
    }

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
                  child: Icon(
                    ended
                        ? Icons.workspace_premium_outlined
                        : Icons.card_giftcard_rounded,
                    size: 22,
                    color: AppColors.brandInk,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      headline,
                      key: const ValueKey('commercial_launch_headline'),
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              ended
                  ? AppStrings.commercialEndedKeepHeader
                  : AppStrings.commercialBasicsHeader,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final item in AppStrings.commercialBasicsList)
              _BulletRow(item, icon: Icons.check_circle_outline_rounded),
            if (ended) ...[
              const SizedBox(height: AppSpacing.m),
              const Text(
                AppStrings.commercialEndedLockedHeader,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final item in AppStrings.commercialPremiumLockedList)
                _BulletRow(item, icon: Icons.lock_outline_rounded),
            ],
            if (priceUntil != null) ...[
              const SizedBox(height: AppSpacing.m),
              Container(
                key: const ValueKey('commercial_launch_price_box'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.brandLemonPale,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(color: AppColors.brandLemon, width: 1.1),
                ),
                child: Text(
                  '${AppStrings.commercialPricePrefix}'
                  '${formatCommercialLaunchDay(priceUntil)}'
                  '${AppStrings.commercialPriceMid}'
                  '${PricingConfig.premiumMonthlyLabel.replaceAll(' / ay', '')}. '
                  '${AppStrings.commercialPriceAssurance}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandInk,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.l),
            if (ended) ...[
              FilledButton(
                key: const ValueKey('commercial_launch_continue_premium'),
                // Yalnız Paketler ekranını açar — otomatik ücret başlatmaz.
                onPressed: () {
                  Navigator.of(context).pop();
                  GoRouter.of(context).push(AppRoutes.plans);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.brandInk,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
                child: const Text(
                  AppStrings.commercialEndedContinuePremium,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              TextButton(
                key: const ValueKey('commercial_launch_stay_free'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  AppStrings.commercialEndedStayFree,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ] else
              FilledButton(
                key: const ValueKey('commercial_launch_ok'),
                // Yalnız bilgilendirmeyi kapatır — ödeme başlatmaz.
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
                  AppStrings.commercialWelcomeCta,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow(this.text, {required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: AppColors.textMuted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Oturum içi tekrar koruması — KULLANICI+TÜR bazlı (hesap değişiminde
/// ikinci kullanıcı görür; geçici bağlantı hatası kalıcı görüldü sayılmaz,
/// oturum başına tek deneme → kontrolsüz döngü yok).
final Set<String> _sessionAttempted = <String>{};

@visibleForTesting
void resetCommercialLaunchSessionGuard() {
  _sessionAttempted.clear();
}

/// Bitişe yaklaşma eşiği (son 3 gün) — banner ve "ending" pop-up'ı.
bool isCommercialFreePeriodEnding(BusinessEntitlements e) =>
    e.freePeriodActive && e.freePeriodDaysLeft <= 3;

/// Ticari hesaba dönem durumuna göre uygun pop-up'ı İLK uygun oturumda bir
/// kez gösterir: dönem bitti → ended; son 3 gün → ending; aktif → welcome.
/// Tarih yapılandırılmamışsa (ends null) hiçbir şey gösterilmez.
Future<void> maybeShowCommercialLaunchSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final userId = ref.read(currentAuthUserProvider)?.id;
  if (userId == null) return;
  final entitlement = ref.read(myEntitlementProvider).valueOrNull;
  if (entitlement == null) return;
  final ends = entitlement.freePeriodEndsAt;
  if (ends == null) return;

  final CommercialLaunchNotice notice;
  if (entitlement.freePeriodActive) {
    notice = isCommercialFreePeriodEnding(entitlement)
        ? CommercialLaunchNotice.ending
        : CommercialLaunchNotice.welcome;
  } else if (DateTime.now().toUtc().isAfter(ends.toUtc()) ||
      DateTime.now().toUtc().isAtSameMomentAs(ends.toUtc())) {
    notice = CommercialLaunchNotice.ended;
  } else {
    return;
  }

  final guardKey = '$userId:${notice.noticeKey}';
  if (_sessionAttempted.contains(guardKey)) return;
  _sessionAttempted.add(guardKey);

  final repo = ref.read(subscriptionRepositoryProvider);
  try {
    if (await repo.hasSeenCommercialLaunchNotice(notice.noticeKey)) return;
  } catch (_) {
    // Görüldü kaydı okunamadıysa bu oturumda tekrar deneme (döngü yok);
    // kalıcı işaret YAZILMAZ, sonraki oturumda yeniden denenir.
    return;
  }
  if (!context.mounted) return;
  await showCommercialLaunchSheet(
    context,
    notice: notice,
    entitlement: entitlement,
    onClosed: () async {
      try {
        await repo.markCommercialLaunchNoticeSeen(notice.noticeKey);
      } catch (_) {
        // Yazım hatası bir sonraki oturumda telafi edilir.
      }
    },
  );
}
