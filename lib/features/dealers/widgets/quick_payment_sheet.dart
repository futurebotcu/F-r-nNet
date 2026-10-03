import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';
import 'cash_tendered_calculator.dart';
import '../../../core/widgets/app_feedback.dart';

/// Hızlı Tahsilat modal — tam borç kapatma akışı (Sprint 6C).
///
/// Bu modal yalnız **currentBalance > 0** olan bayilerde çağrılır
/// (caller `dealer_detail_screen` chip görünürlüğünü yönetir).
/// Akış:
/// - Modal açılır, üstte bayi adı + BORÇ ₺X,XX pill
/// - Ortada [CashTenderedCalculator] (donor lift)
/// - Kullanıcı verilen tutarı keypad ile girer; calculator para üstünü
///   otomatik hesaplar
/// - Submit (✓ ikonu) → onSubmit fire eder
///   - paid >= price ise: ledger'a **price (borç tutarı)** kadar payment
///     yazılır; verilen tutar (tendered) UI helper olarak kalır; modal
///     kapanır + snackbar (para üstü varsa snackbar'da hatırlatılır)
///   - paid < price ise: kısmi tahsilat hint snackbar; modal AÇIK kalır
///     ("Kısmi tahsilat için Ödeme Al formunu kullan")
class QuickPaymentSheet extends ConsumerStatefulWidget {
  const QuickPaymentSheet({
    super.key,
    required this.dealerId,
    required this.dealerName,
    required this.currentBalance,
  });

  final String dealerId;
  final String dealerName;
  final double currentBalance;

  /// Convenience launcher — `showModalBottomSheet` ile çağırır.
  static Future<void> show({
    required BuildContext context,
    required String dealerId,
    required String dealerName,
    required double currentBalance,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => QuickPaymentSheet(
        dealerId: dealerId,
        dealerName: dealerName,
        currentBalance: currentBalance,
      ),
    );
  }

  @override
  ConsumerState<QuickPaymentSheet> createState() => _QuickPaymentSheetState();
}

class _QuickPaymentSheetState extends ConsumerState<QuickPaymentSheet> {
  late final ValueNotifier<num> _price;
  late final ValueNotifier<num> _paid;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _price = ValueNotifier<num>(widget.currentBalance);
    // Default paid = price (kullanıcı tam tutarı vereceğini varsayar);
    // farklı verirse calculator değeri günceller.
    _paid = ValueNotifier<num>(widget.currentBalance);
  }

  @override
  void dispose() {
    _price.dispose();
    _paid.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_busy) return;

    // Kural #3: paid < price → kısmi tahsilat hint; ledger'a yazma yok.
    if (_paid.value < _price.value) {
      AppFeedback.warning(context, AppStrings.quickPaymentPartialHint);
      return;
    }

    if (!AuthRequiredGuard.canWriteWithRef(ref)) {
      await showAuthRequiredSheet(context, ref);
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(dealerRepositoryProvider);
    final now = DateTime.now();
    // Kural #2: amount = price (borç tutarı), verilen tutar değil.
    final amount = _price.value.toDouble();
    final change = (_paid.value - _price.value).toDouble();

    try {
      await repo.addTransaction(
        DealerTransaction(
          id: 'tx_${now.microsecondsSinceEpoch}',
          dealerId: widget.dealerId,
          type: DealerTransactionType.payment,
          amount: amount,
          paymentMethod: DealerPaymentMethod.cash,
          createdAt: now,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      final successMsg = change > 0
          ? '${AppStrings.quickPaymentSuccess} · '
                '${AppStrings.quickPaymentChangeReturn} '
                '${NumberFormatter.currency(change)}'
          : AppStrings.quickPaymentSuccess;
      AppFeedback.success(context, successMsg);
    } on GuestActionRequiredException {
      if (!mounted) return;
      setState(() => _busy = false);
      await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, AppStrings.dealerPaymentSaveError);
    }
  }

  /// Başlık + hesaplayıcının alanları + tuş takımının en az bir kısmı için
  /// gereken yükseklik. Bu değerin altında tüm içerik dış kaydırmaya geçer
  /// (320px / 1.5x yazı / açık klavye — taşma yok).
  static double minContentHeight(double textScale) => 300 + 120 * textScale;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets;
    final textScale = mq.textScaler.scale(16) / 16;

    // Kök neden (eski): sabit `0.78 × ekran` yükseklik; klavye/viewInsets
    // ve büyük yazıda üst kart + alanlar sığmayıp Column taşıyordu.
    // Şimdi yükseklik kullanılabilir alana göre sınırlanır; yetmezse
    // içerik kaydırılır. Ödeme mantığı değişmedi.
    final available =
        mq.size.height -
        viewInsets.bottom -
        mq.padding.top -
        mq.padding.bottom -
        AppSpacing.l;
    final sheetHeight = math.max(
      0.0,
      math.min(mq.size.height * 0.78, available),
    );
    final minContent = minContentHeight(textScale);

    final content = Column(
      children: [
        // Sheet drag handle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderHairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.xs,
            AppSpacing.pageH,
            AppSpacing.m,
          ),
          child: PremiumCard(
            warm: true,
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.quickPaymentTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.dealerName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardTitle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppStrings.quickPaymentDebtLabel,
                        maxLines: 1,
                        style: AppTypography.labelSmall,
                      ),
                      const SizedBox(height: 2),
                      // Uzun tutar dar ekranda küçülür, kesilmez.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          NumberFormatter.currency(widget.currentBalance),
                          maxLines: 1,
                          style: AppTypography.priceLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: CashTenderedCalculator(
            price: _price,
            paid: _paid,
            onSubmit: _onSubmit,
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          key: const ValueKey('quick_payment_sheet'),
          height: sheetHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight >= minContent) return content;
              return SingleChildScrollView(
                key: const ValueKey('quick_payment_scroll'),
                child: SizedBox(height: minContent, child: content),
              );
            },
          ),
        ),
      ),
    );
  }
}
