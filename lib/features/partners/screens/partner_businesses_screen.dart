import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/error_retry_state.dart';
import '../models/partner_business.dart';
import '../providers/partner_business_providers.dart';
import '../widgets/partner_business_card.dart';
import '../widgets/partner_filter_bar.dart';

/// Anlaşmalı İş Yerleri — tüm kullanıcı tipleri için ortak dizin.
///
/// Veri sınırı RLS'te (yalnız is_active=true); filtre V1'de client-side,
/// ilk 50 kayıt üzerinde. Yönetim/yayınlama yüzeyi YOK (backoffice işi).
class PartnerBusinessesScreen extends ConsumerStatefulWidget {
  const PartnerBusinessesScreen({super.key});

  @override
  ConsumerState<PartnerBusinessesScreen> createState() =>
      _PartnerBusinessesScreenState();
}

class _PartnerBusinessesScreenState
    extends ConsumerState<PartnerBusinessesScreen> {
  PartnerBusinessFilter _filter = const PartnerBusinessFilter();

  @override
  Widget build(BuildContext context) {
    final partners = ref.watch(activePartnersProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.partnersTitle)),
      body: SafeArea(
        top: false,
        child: partners.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: ErrorRetryState(
              title: AppStrings.partnersListError,
              onRetry: () => ref.invalidate(activePartnersProvider),
            ),
          ),
          data: (all) {
            final visible = _filter.apply(all);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageH,
                AppSpacing.m,
                AppSpacing.pageH,
                AppSpacing.xxl,
              ),
              children: [
                PartnerFilterBar(
                  all: all,
                  filter: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: AppSpacing.m),
                if (visible.isEmpty)
                  const _PartnersEmpty()
                else
                  for (final p in visible) ...[
                    PartnerBusinessCard(
                      partner: p,
                      onDetail: () =>
                          context.push(AppRoutes.partnerDetail(p.id)),
                    ),
                    const SizedBox(height: AppSpacing.s),
                  ],
                // UX polish: başvuru CTA'sı listeden de erişilir — boş
                // durumda empty metninin altında, dolu listede en altta
                // küçük ama net giriş (destek ekranı girişi aynen durur).
                const SizedBox(height: AppSpacing.m),
                const _ApplyCta(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Anlaşmalı iş yeri olmak istiyorum" → mevcut başvuru formu
/// (/partners/apply). Destek ekranındaki giriş korunur; bu ikinci yoldur.
class _ApplyCta extends StatelessWidget {
  const _ApplyCta();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('partners_apply_cta'),
      onPressed: () => context.push(AppRoutes.partnersApply),
      icon: const Icon(Icons.handshake_outlined, size: 18),
      label: const Text(AppStrings.partnersApplyEntry),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        foregroundColor: AppColors.brandInk,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
      ),
    );
  }
}

class _PartnersEmpty extends StatelessWidget {
  const _PartnersEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: const [
          Icon(Icons.handshake_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: AppSpacing.m),
          Text(
            AppStrings.partnersEmptyTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          SizedBox(height: 6),
          Text(
            AppStrings.partnersEmptyBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
