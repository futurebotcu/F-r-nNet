import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
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
    final service = ref.read(paymentServiceProvider);
    if (!service.isAvailable) {
      _snack(AppStrings.storePaymentPreparing);
      return;
    }
    setState(() => _busy = true);
    final result = await service.purchaseListingFee(
      listingKind: widget.listingKind,
      listingId: widget.listingId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case PaymentResult.success:
      case PaymentResult.pending:
        _snack(AppStrings.storePaymentSuccess);
        widget.onPaid?.call();
      case PaymentResult.unavailable:
        _snack(AppStrings.storePaymentPreparing);
      case PaymentResult.cancelled:
      case PaymentResult.error:
        _snack(AppStrings.storePaymentFailed);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

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
