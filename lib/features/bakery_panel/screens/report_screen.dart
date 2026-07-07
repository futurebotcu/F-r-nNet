import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/stat_card.dart';
import '../../profile/models/bakery_profile.dart';
import '../../profile/providers/profile_provider.dart';
import '../../subscriptions/models/business_entitlements.dart';
import '../../subscriptions/models/feature_lock.dart';
import '../../subscriptions/providers/subscription_providers.dart';
import '../../subscriptions/widgets/paywall_sheet.dart';
import '../providers/bakery_providers.dart';
import '../widgets/ledger_tables.dart';

/// Fırın Defteri — basit dönem raporu (Bugün / Dün / 7 Gün / 30 Gün).
/// PDF/Excel/grafik YOK (V2) — sade kart/liste.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  LedgerReportPeriod _period = LedgerReportPeriod.today;

  /// Bir dönem ticari plan tarafından kilitli mi? Free → yalnız 30 gün kilitli
  /// (Pro açar). Entitlement yüklü değilse kilit yok. (Server-side rapor gate
  /// YOK — bu yalnız UX; veri gizlenmez.)
  bool _periodLocked(LedgerReportPeriod p, BusinessEntitlements? e) {
    if (e == null) return false;
    return p == LedgerReportPeriod.month30 && e.isFree;
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(ledgerReportProvider(_period));
    // Rapor kilidi YALNIZ ticari kullanıcıya; bireysel pass-through.
    final isCommercial =
        ref.watch(profileControllerProvider)?.accountType ==
        AccountType.commercial;
    final entitlements = isCommercial
        ? ref.watch(myEntitlementProvider).valueOrNull
        : null;
    final df = DateFormat('d MMM', 'tr_TR');

    return PremiumScaffold(
      appBar: AppBar(title: const Text(AppStrings.ledgerReportTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            0,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          children: [
            // Dönem seçici — dar ekranda taşmasın (Wrap).
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in LedgerReportPeriod.values)
                  Builder(
                    builder: (context) {
                      final locked = _periodLocked(p, entitlements);
                      return ChoiceChip(
                        key: ValueKey('ledger_period_${p.name}'),
                        avatar: locked
                            ? const Icon(
                                Icons.lock_rounded,
                                size: 13,
                                color: AppColors.textMuted,
                              )
                            : null,
                        label: Text(p.label),
                        selected: _period == p,
                        onSelected: (_) {
                          if (locked) {
                            showPaywallSheet(context, FeatureLock.reportPro);
                            return;
                          }
                          setState(() => _period = p);
                        },
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        selectedColor: AppColors.brandLemonPale,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            report.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorRetryState(
                onRetry: () => ref.invalidate(ledgerReportProvider(_period)),
              ),
              data: (r) {
                final empty =
                    r.totalProduction == 0 &&
                    r.totalWaste == 0 &&
                    r.totalRevenue == 0 &&
                    r.closedDays == 0;
                if (empty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                    child: Text(
                      AppStrings.ledgerReportEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  );
                }
                final ratio = r.wasteRatio;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${df.format(r.from)} – ${df.format(r.to)}'.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: Icons.bakery_dining_outlined,
                            label: AppStrings.ledgerEodProduction,
                            value:
                                '${NumberFormatter.integer(r.totalProduction)} adet',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: StatCard(
                            icon: Icons.delete_sweep_outlined,
                            label: AppStrings.ledgerEodWaste,
                            value:
                                '${NumberFormatter.integer(r.totalWaste)} adet',
                            accent: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: Icons.percent_rounded,
                            label: AppStrings.ledgerEodWasteRatio,
                            value: ratio == null
                                ? '—'
                                : '%${(ratio * 100).toStringAsFixed(1)}',
                            accent: const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: StatCard(
                            icon: Icons.payments_outlined,
                            label: AppStrings.ledgerEodRevenue,
                            value: NumberFormatter.currency(r.totalRevenue),
                            accent: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    StatCard(
                      icon: Icons.nightlight_outlined,
                      label: AppStrings.ledgerReportClosedDays,
                      value: NumberFormatter.integer(r.closedDays),
                    ),
                    // Operasyon tabloları (tables polish): gün-gün defter +
                    // ürün bazlı üretim/fire özeti + notlar. Aynı veriden
                    // türetilir; migration/yeni sorgu yok.
                    if (r.dailyRows.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.l),
                      DayBookTable(rows: r.dailyRows),
                    ],
                    if (r.productRows.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.m),
                      // Ürün bazlı özet = ileri tablo → Pro/Premium. Free'de
                      // kilitli teaser (veri gizlenmez; tablo yerine paywall
                      // kartı). Entitlement yüklü değilse açık.
                      if (entitlements != null && entitlements.isFree)
                        _LockedReportTeaser(
                          title: AppStrings.ledgerTableProductSummaryTitle,
                          onTap: () =>
                              showPaywallSheet(context, FeatureLock.reportPro),
                        )
                      else
                        ProductSummaryTable(rows: r.productRows),
                    ],
                    if (r.noteRows.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.m),
                      NotesTable(rows: r.noteRows),
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

/// Free kullanıcıya ileri rapor tablosu yerine gösterilen kilitli teaser
/// (veri gizlenmez; tıklanınca paywall açılır).
class _LockedReportTeaser extends StatelessWidget {
  const _LockedReportTeaser({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('ledger_report_locked_products'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          boxShadow: AppShadow.card,
          border: Border.all(color: AppColors.borderHairline),
        ),
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            const Icon(
              Icons.lock_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    AppStrings.paywallReportProTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brandLemon,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Text(
                AppStrings.paywallProTag,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
