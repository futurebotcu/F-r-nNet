import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../providers/bakery_providers.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySummaryProvider);
    final builder = ref.read(reportBuilderProvider);

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.getReport)),
      body: SafeArea(
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (s) {
            if (s.isEmpty) {
              return EmptyState(
                title: 'Henüz paylaşacak rapor yok',
                subtitle:
                    'Üretim ve bayi kayıtların oluştukça gün sonu özetin burada paylaşıma hazır olur.',
                icon: Icons.share_outlined,
                actionLabel: 'Üretim Gir',
                onAction: () => GoRouter.of(context).push(AppRoutes.production),
              );
            }
            final text = builder.buildPlainText(s);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                0,
                AppSpacing.pageH,
                AppSpacing.xxl,
              ),
              children: [
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Metin panoya kopyalandı.')),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s),
                SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_rounded),
                    label: const Text(AppStrings.shareWhatsapp),
                    onPressed: () {
                      Share.share(text, subject: 'FırınNet — Gün Sonu');
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text(AppStrings.pdfReport),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PDF V2\'de aktif olacak.'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
