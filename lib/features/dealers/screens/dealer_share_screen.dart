import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../models/dealer.dart';
import '../providers/dealer_providers.dart';

/// PDF dosya adı için Türkçe karakterleri ASCII'ye çevirip slug üretir
/// (ş→s, ğ→g, ı→i, ö→o, ü→u, ç→c). Eski regex Türkçe harfleri siliyordu
/// ("Şahin Fırın" → "ahin_f_r_n"); WhatsApp'ta okunur dosya adı için.
String _asciiSlug(String input) {
  const map = <String, String>{
    'ş': 's', 'Ş': 's', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'İ': 'i',
    'ö': 'o', 'Ö': 'o', 'ü': 'u', 'Ü': 'u', 'ç': 'c', 'Ç': 'c',
  };
  final buf = StringBuffer();
  for (final ch in input.split('')) {
    buf.write(map[ch] ?? ch);
  }
  return buf
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

class DealerShareScreen extends ConsumerStatefulWidget {
  const DealerShareScreen({super.key, required this.dealerId});

  final String dealerId;

  @override
  ConsumerState<DealerShareScreen> createState() => _DealerShareScreenState();
}

class _DealerShareScreenState extends ConsumerState<DealerShareScreen> {
  bool _pdfBusy = false;
  String? _pdfStatus;

  @override
  Widget build(BuildContext context) {
    final dealerAsync = ref.watch(dealerByIdProvider(widget.dealerId));
    final balanceAsync = ref.watch(balanceSummaryProvider(widget.dealerId));
    final txAsync = ref.watch(transactionsByDealerProvider(widget.dealerId));

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.dealerShareTitle)),
      body: SafeArea(
        child: dealerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetryState(
            onRetry: () => ref.invalidate(dealerByIdProvider(widget.dealerId)),
          ),
          data: (dealer) {
            if (dealer == null) {
              return const Center(child: Text('Bayi bulunamadı'));
            }
            return balanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const ErrorRetryState(),
              data: (summary) => txAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const ErrorRetryState(),
                data: (txs) {
                  final shareBuilder = ref.read(dealerShareBuilderProvider);
                  final recent = txs.take(8).toList();
                  final text = shareBuilder.buildPlainText(
                    dealer: dealer,
                    summary: summary,
                    recentTransactions: recent,
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      0,
                      AppSpacing.pageH,
                      AppSpacing.xxl,
                    ),
                    children: [
                      _Header(dealer: dealer, balance: summary.currentBalance),
                      const SizedBox(height: AppSpacing.l),
                      PremiumCard(
                        warm: true,
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: SelectableText(
                          text,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'monospace',
                            fontSize: 13.5,
                            height: 1.6,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.l),
                      AppPrimaryButton(
                        label: AppStrings.copyText,
                        icon: Icons.copy_rounded,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (!context.mounted) return;
                          PremiumTopBannerController.show(
                            context,
                            message: AppStrings.dealerShareCopiedSnack,
                            tone: PremiumTopBannerTone.success,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.s),
                      SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share_rounded),
                          label: const Text(AppStrings.dealerShareWhatsapp),
                          onPressed: () {
                            Share.share(
                              text,
                              subject: 'FırınNet — ${dealer.name} hesap özeti',
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: Text(
                            _pdfBusy
                                ? AppStrings.dealerSharePdfBuilding
                                : AppStrings.dealerSharePdfButton,
                          ),
                          onPressed: _pdfBusy
                              ? null
                              : () =>
                                    _buildAndSharePdf(dealer, summary, recent),
                        ),
                      ),
                      if (_pdfStatus != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.m),
                          child: PremiumCard(
                            padding: const EdgeInsets.all(AppSpacing.m),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpacing.s),
                                Expanded(
                                  child: Text(
                                    _pdfStatus!,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _buildAndSharePdf(Dealer dealer, summary, recent) async {
    setState(() {
      _pdfBusy = true;
      _pdfStatus = null;
    });
    try {
      final pdfBuilder = ref.read(dealerPdfBuilderProvider);
      // Türkçe karakter + ₺ için Roboto bundled font (V1.1).
      final regular = (await rootBundle.load(
        'assets/fonts/Roboto-Regular.ttf',
      )).buffer.asUint8List();
      final bold = (await rootBundle.load(
        'assets/fonts/Roboto-Bold.ttf',
      )).buffer.asUint8List();
      final bytes = await pdfBuilder.build(
        dealer: dealer,
        summary: summary,
        recentTransactions: recent,
        regularFont: regular,
        boldFont: bold,
      );
      final slug = _asciiSlug(dealer.name);
      final namePart = slug.isEmpty ? 'bayi' : slug;
      final now = DateTime.now();
      final datePart = '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final fileName = 'firinnet_${namePart}_hesap_ozeti_$datePart.pdf';
      HapticFeedback.lightImpact();
      await Share.shareXFiles([
        XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf'),
      ], subject: 'FırınNet — ${dealer.name} hesap özeti');
      if (!mounted) return;
      setState(
        () => _pdfStatus = 'PDF hazırlandı${AppStrings.dealerSharePdfSuffix}',
      );
    } catch (_) {
      if (!mounted) return;
      PremiumTopBannerController.show(
        context,
        message: AppStrings.dealerSharePdfErr,
        tone: PremiumTopBannerTone.danger,
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dealer, required this.balance});
  final Dealer dealer;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final tag = balance > 0
        ? 'BORÇ'
        : balance < 0
        ? 'ALACAK'
        : 'KAPALI';
    final color = balance > 0
        ? AppColors.textPrimary
        : balance < 0
        ? AppColors.success
        : AppColors.softGold;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroFrom, AppColors.heroTo],
        ),
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(
          color: AppColors.copper.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: AppShadow.heroGlow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.copper.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppColors.softGold,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dealer.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Bakiye ${NumberFormatter.currency(balance.abs())} · $tag',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
