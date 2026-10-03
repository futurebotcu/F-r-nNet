import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/payment_service.dart';
import '../providers/payment_providers.dart';

/// Ücretli ilan (50 TL) ödeme butonu — owner'ın kendi pending ilanında görünür.
/// Ödeme kullanılamıyorsa "hazırlanıyor" gösterir (SAHTE purchase yok). Başarılı
/// ödeme sonrası ilan backend'de doğrulanıp public yapılır.
class ListingPaymentButton extends ConsumerStatefulWidget {
  const ListingPaymentButton({
    super.key,
    required this.listingKind,
    required this.listingId,
    this.onPaid,
  });

  final String listingKind;
  final String listingId;
  final VoidCallback? onPaid;

  @override
  ConsumerState<ListingPaymentButton> createState() =>
      _ListingPaymentButtonState();
}

class _ListingPaymentButtonState extends ConsumerState<ListingPaymentButton> {
  bool _busy = false;

  Future<void> _pay() async {
    if (_busy) return;
    final userId = ref.read(currentAuthUserProvider)?.id;
    if (userId == null) {
      _snack(AppStrings.authGuestDataWriteBlock);
      return;
    }
    final service = ref.read(paymentServiceProvider);
    if (!service.isAvailable) {
      _snack(AppStrings.storePaymentPreparing);
      return;
    }
    setState(() => _busy = true);
    var result = PaymentResult.error;
    try {
      // configure/logIn platform istisnası butonu kalıcı kilitlememeli;
      // kullanıcıya ham hata değil yerelleştirilmiş mesaj gösterilir.
      await service.initialize(userId: userId);
      result = await service.purchaseListingFee(
        listingKind: widget.listingKind,
        listingId: widget.listingId,
      );
    } catch (_) {
      result = PaymentResult.error;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    switch (result) {
      case PaymentResult.success:
      case PaymentResult.pending:
        AppFeedback.success(context, AppStrings.storePaymentSuccess);
        widget.onPaid?.call();
      case PaymentResult.unavailable:
        AppFeedback.info(context, AppStrings.storePaymentPreparing);
      case PaymentResult.cancelled:
      case PaymentResult.error:
        AppFeedback.error(context, AppStrings.storePaymentFailed);
    }
  }

  void _snack(String msg) => AppFeedback.info(context, msg);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey('listing_pay_button'),
        onPressed: _busy ? null : _pay,
        icon: const Icon(Icons.lock_open_rounded, size: 17),
        label: const Text(AppStrings.storeListingPayCta),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandInk,
          foregroundColor: AppColors.brandLemon,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
        ),
      ),
    );
  }
}
