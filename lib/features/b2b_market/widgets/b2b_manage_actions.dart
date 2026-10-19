// S3 — Ürün/kampanya sahip aksiyonları: silme (onaylı, geri alınamaz) ve
// ürün çoğaltma (taslak kopya). Tek yerde: Mağazam, Ürünler, Kampanyalar
// sekmeleri aynı akışı kullanır. Yetki sunucuda (RLS delete/insert yalnız
// sahip; ürün kotası can_add_b2b_product).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/b2b_campaign.dart';
import '../models/b2b_product.dart';
import '../providers/b2b_providers.dart';
import '../services/b2b_media_upload_service.dart';

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
  // Silmeden ÖNCE: görsel başka ürün/kampanyamda da kullanılıyor mu?
  // (Çoğalt aynı URL'yi paylaşır.) Paylaşılıyorsa storage'a dokunulmaz.
  final imageUrl = product.imageUrl;
  final shared =
      imageUrl != null &&
      await isB2bImageShared(ref, imageUrl, exceptProductId: product.id);
  try {
    await ref
        .read(b2bMarketControllerProvider.notifier)
        .deleteProduct(product.id);
    if (context.mounted) {
      AppFeedback.success(context, AppStrings.b2bDeletedProduct);
    }
  } catch (_) {
    if (context.mounted) AppFeedback.error(context, AppStrings.b2bDeleteError);
    return;
  }
  // DB silme başarılıysa görseli temizle (best-effort; yalnız kendi yolum,
  // yalnız paylaşılmıyorsa). Hata UI'a yansımaz; orphan kalırsa zararsız.
  if (imageUrl != null && !shared) {
    final uid = ref.read(currentAuthUserProvider)?.id;
    if (uid != null) {
      await ref
          .read(b2bMediaUploadServiceProvider)
          ?.deleteIfOwned(userId: uid, oldUrl: imageUrl);
    }
  }
}

/// Görsel URL'si çağıranın başka bir ürün/kampanyasında da kullanılıyor mu?
/// Bilinmeyen durumda (listeler yüklenmemiş) `true` döner → silme ATLANIR
/// (güvenli taraf).
Future<bool> isB2bImageShared(
  WidgetRef ref,
  String url, {
  String? exceptProductId,
}) async {
  try {
    final products = await ref.read(b2bMyProductsProvider.future);
    final campaigns = await ref.read(b2bMyCampaignsProvider.future);
    return products.any((p) => p.id != exceptProductId && p.imageUrl == url) ||
        campaigns.any((c) => c.imageUrl == url);
  } catch (_) {
    return true;
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
