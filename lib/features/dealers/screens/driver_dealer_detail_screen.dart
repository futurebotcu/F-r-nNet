import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/dealer_transaction.dart';
import '../providers/dealer_providers.dart';

/// Şoför için READ-ONLY bayi detayı (Sprint 3).
///
/// Bayi temel bilgisi + son bakiye + son hareketler. Hiçbir patron/işlem
/// aksiyonu (teslimat/tahsilat/iade/düzeltme/gün sonu/rapor) YOK. Veriye erişim
/// atama-bazlı RLS ile sınırlıdır.
class DriverDealerDetailScreen extends ConsumerWidget {
  const DriverDealerDetailScreen({super.key, required this.dealerId});
  final String dealerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealerAsync = ref.watch(dealerByIdProvider(dealerId));
    final balanceAsync = ref.watch(balanceSummaryProvider(dealerId));
    final txAsync = ref.watch(transactionsByDealerProvider(dealerId));

    return PremiumScaffold(
      appBar: AppBar(
        title: Text(dealerAsync.valueOrNull?.name ?? 'Bayi'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.m,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            // ── Bayi bilgisi ──
            dealerAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (d) {
                if (d == null) return const SizedBox.shrink();
                final loc =
                    [d.city, d.area].where((e) => e.isNotEmpty).join(' · ');
                return PremiumCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        if (d.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(d.phone,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ],
                        if (loc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(loc,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.m),

            // ── Bakiye özeti (read-only) ──
            balanceAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.m),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (b) => PremiumCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Güncel Bakiye',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ),
                      Text(
                        '₺${b.currentBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: b.currentBalance > 0
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // ── İşlem ekle (Sprint 4 — RPC ile; sadece atanmış bayi) ──
            _DriverActions(dealerId: dealerId),
            const SizedBox(height: AppSpacing.l),

            const Text('Son Hareketler',
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.s),

            // ── Hareketler (read-only) ──
            txAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.m),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text('Hareketler yüklenemedi.',
                  style: TextStyle(color: AppColors.textSecondary)),
              data: (txs) {
                if (txs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(
                          color: AppColors.borderHairline, width: 0.8),
                    ),
                    child: const Text('Henüz hareket yok.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600)),
                  );
                }
                return Column(
                  children: [
                    for (final t in txs.take(50)) ...[
                      _TxRow(tx: t),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Şoför işlem ekleme aksiyonları — yalnız delivery/payment/return.
class _DriverActions extends StatelessWidget {
  const _DriverActions({required this.dealerId});
  final String dealerId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActBtn(
            icon: Icons.bakery_dining_rounded,
            label: 'Teslimat',
            onTap: () => _showSheet(context, DealerTransactionType.delivery),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: _ActBtn(
            icon: Icons.payments_rounded,
            label: 'Tahsilat',
            onTap: () => _showSheet(context, DealerTransactionType.payment),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: _ActBtn(
            icon: Icons.assignment_return_rounded,
            label: 'İade',
            onTap: () => _showSheet(context, DealerTransactionType.returned),
          ),
        ),
      ],
    );
  }

  void _showSheet(BuildContext context, DealerTransactionType type) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriverTxSheet(dealerId: dealerId, type: type),
    );
  }
}

class _ActBtn extends StatelessWidget {
  const _ActBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.borderHairline),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: AppColors.brandLemonPressed),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Şoför işlem formu (bottom sheet). delivery/return: ürün+adet+birim fiyat;
/// payment: tutar + ödeme yöntemi. addDriverTransaction → RPC.
class _DriverTxSheet extends ConsumerStatefulWidget {
  const _DriverTxSheet({required this.dealerId, required this.type});
  final String dealerId;
  final DealerTransactionType type;

  @override
  ConsumerState<_DriverTxSheet> createState() => _DriverTxSheetState();
}

class _DriverTxSheetState extends ConsumerState<_DriverTxSheet> {
  final _product = TextEditingController();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DealerPaymentMethod _method = DealerPaymentMethod.cash;
  bool _saving = false;
  String? _error;

  bool get _isPayment => widget.type == DealerTransactionType.payment;

  @override
  void dispose() {
    _product.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    int? qty;
    double? price;
    double amount = 0;
    if (_isPayment) {
      amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
      if (amount <= 0) {
        setState(() => _error = 'Geçerli bir tutar gir.');
        return;
      }
    } else {
      qty = int.tryParse(_quantity.text);
      price = double.tryParse(_unitPrice.text.replaceAll(',', '.'));
      if (qty == null || qty <= 0 || price == null || price < 0) {
        setState(() => _error = 'Adet ve birim fiyatı gir.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(dealerRepositoryProvider).addDriverTransaction(
            dealerId: widget.dealerId,
            type: widget.type,
            amount: amount,
            quantity: qty,
            unitPrice: price,
            paymentMethod: _isPayment ? _method : null,
            productName: _isPayment ? null : _product.text.trim(),
            note: _note.text.trim(),
          );
      ref.invalidate(transactionsByDealerProvider(widget.dealerId));
      ref.invalidate(balanceSummaryProvider(widget.dealerId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.type.label} eklendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is StateError ? e.message : 'İşlem eklenemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.l),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.type.label} Ekle',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.m),
              if (_isPayment) ...[
                _input(_amount, 'Tutar (₺)',
                    keyboardType: TextInputType.number),
                const SizedBox(height: AppSpacing.s),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final m in DealerPaymentMethod.values)
                      ChoiceChip(
                        label: Text(m.label),
                        selected: _method == m,
                        onSelected: (_) => setState(() => _method = m),
                      ),
                  ],
                ),
              ] else ...[
                _input(_product, 'Ürün'),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: [
                    Expanded(
                      child: _input(_quantity, 'Adet',
                          keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: _input(_unitPrice, 'Birim Fiyat (₺)',
                          keyboardType: TextInputType.number),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.s),
              _input(_note, 'Not (opsiyonel)'),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: AppSpacing.m),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandLemon,
                    foregroundColor: AppColors.brandInk,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                  child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide:
              const BorderSide(color: AppColors.borderHairline, width: 0.8),
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx});
  final DealerTransaction tx;

  @override
  Widget build(BuildContext context) {
    final negative = tx.type == DealerTransactionType.payment ||
        tx.type == DealerTransactionType.returned;
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.productName?.isNotEmpty == true
                        ? '${tx.type.label} · ${tx.productName}'
                        : tx.type.label,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  if (tx.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(tx.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              '${negative ? '−' : '+'}₺${tx.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: negative ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
