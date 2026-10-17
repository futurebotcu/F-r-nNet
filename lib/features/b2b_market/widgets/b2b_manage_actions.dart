// S3 — Ürün/kampanya sahip aksiyonları: silme (onaylı, geri alınamaz) ve
// ürün çoğaltma (taslak kopya). Tek yerde: Mağazam, Ürünler, Kampanyalar
// sekmeleri aynı akışı kullanır. Yetki sunucuda (RLS delete/insert yalnız
// sahip; ürün kotası can_add_b2b_product).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_feedback.dart';
import '../models/b2b_campaign.dart';
import '../models/b2b_product.dart';
import '../providers/b2b_providers.dart';

Future<void> confirmAndDeleteProduct(
  BuildContext context,
  WidgetRef ref,
  B2bProduct product,
) async {
  final ok = await showAppConfirmDialog(
    context,
    title: AppStrings.b2bDeleteProductTitle,
    message: '${product.name} ${AppStrings.b2bDeleteProductMessage}',
    confirmLabel: AppStrings.b2bDeleteConfirm,
    destructive: true,
    icon: Icons.delete_outline_rounded,
  );
  if (!ok || !context.mounted) return;
  try {
    await ref
        .read(b2bMarketControllerProvider.notifier)
        .deleteProduct(product.id);
    if (context.mounted) {
      AppFeedback.success(context, AppStrings.b2bDeletedProduct);
    }
  } catch (_) {
    if (context.mounted) AppFeedback.error(context, AppStrings.b2bDeleteError);
  }
}

Future<void> confirmAndDeleteCampaign(
  BuildContext context,
  WidgetRef ref,
  B2bCampaign campaign,
) async {
  final ok = await showAppConfirmDialog(
    context,
    title: AppStrings.b2bDeleteCampaignTitle,
    message: '${campaign.title} ${AppStrings.b2bDeleteCampaignMessage}',
    confirmLabel: AppStrings.b2bDeleteConfirm,
    destructive: true,
    icon: Icons.delete_outline_rounded,
  );
  if (!ok || !context.mounted) return;
  try {
    await ref
        .read(b2bMarketControllerProvider.notifier)
        .deleteCampaign(campaign.id);
    if (context.mounted) {
      AppFeedback.success(context, AppStrings.b2bDeletedCampaign);
    }
  } catch (_) {
    if (context.mounted) AppFeedback.error(context, AppStrings.b2bDeleteError);
  }
}

Future<void> duplicateProductWithFeedback(
  BuildContext context,
  WidgetRef ref,
  B2bProduct product,
) async {
  try {
    await ref
        .read(b2bMarketControllerProvider.notifier)
        .duplicateProduct(product.id);
    if (context.mounted) {
      AppFeedback.success(context, AppStrings.b2bDuplicatedProduct);
    }
  } catch (_) {
    // Kota dolu (RLS) veya ağ hatası — sunucu kısıtı, UI'da nazik mesaj.
    if (context.mounted) {
      AppFeedback.error(context, AppStrings.b2bDuplicateError);
    }
  }
}
