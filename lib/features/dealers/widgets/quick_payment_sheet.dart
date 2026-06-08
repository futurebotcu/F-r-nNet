import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';
import 'cash_tendered_calculator.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.quickPaymentPartialHint)),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMsg)));
    } on GuestActionRequiredException {
      if (!mounted) return;
      setState(() => _busy = false);
      await showAuthRequiredSheet(context, ref);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.dealerPaymentSaveError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
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
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.dealerName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppStrings.quickPaymentDebtLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            NumberFormatter.currency(widget.currentBalance),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.copper,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
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
          ),
        ),
      ),
    );
  }
}
