import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/premium_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../models/partner_business.dart';
import '../providers/partner_business_providers.dart';
import '../widgets/partner_business_card.dart' show launchPartnerLink;

/// Anlaşmalı iş yeri detay ekranı — rozet + avantaj + iletişim + haritada aç.
/// Harita gömülü DEĞİL; yalnız map_url harici açılır.
class PartnerBusinessDetailScreen extends ConsumerWidget {
  const PartnerBusinessDetailScreen({super.key, required this.partnerId});

  final String partnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerByIdProvider(partnerId));
    return PremiumScaffold(
      appBar: AppBar(
        title: Text(partner.valueOrNull?.name ?? AppStrings.partnersTitle),
      ),
      body: SafeArea(
        top: false,
        child: partner.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text(
              AppStrings.partnersListError,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ),
          data: (p) => p == null
              ? const Center(
                  child: Text(
                    AppStrings.partnersDetailNotFound,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : _Detail(partner: p),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.partner});
  final PartnerBusiness partner;

  @override
  Widget build(BuildContext context) {
    final p = partner;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageH),
      children: [
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandLemonPale,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: AppColors.brandInk,
                          ),
                          SizedBox(width: 4),
                          Text(
                            AppStrings.partnersBadge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.category} · ${p.city} / ${p.district}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                if (p.address.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s),
                  _InfoRow(icon: Icons.place_outlined, text: p.address),
                ],
              ],
            ),
          ),
        ),
        if (p.benefitSummary.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.m),
          PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(AppStrings.partnersDetailBenefit),
                  const SizedBox(height: 4),
                  Text(
                    p.benefitSummary,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF166534),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (p.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.m),
          PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(AppStrings.partnersDetailAbout),
                  const SizedBox(height: 4),
                  Text(
                    p.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.m),
        PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(AppStrings.partnersDetailContact),
                const SizedBox(height: AppSpacing.s),
                if (p.phone.isNotEmpty)
                  _ContactRow(
                    keyName: 'partner_detail_call',
                    icon: Icons.call_outlined,
                    label: p.phone,
                    onTap: () => launchPartnerLink(
                      context,
                      Uri(scheme: 'tel', path: p.phone),
                    ),
                  ),
                if (p.email.isNotEmpty)
                  _ContactRow(
                    keyName: 'partner_detail_email',
                    icon: Icons.mail_outline_rounded,
                    label: p.email,
                    onTap: () => launchPartnerLink(
                      context,
                      Uri(scheme: 'mailto', path: p.email),
                    ),
                  ),
                if (p.websiteUrl.isNotEmpty)
                  _ContactRow(
                    keyName: 'partner_detail_website',
                    icon: Icons.language_rounded,
                    label: AppStrings.partnersDetailWebsite,
                    onTap: () {
                      final uri = Uri.tryParse(p.websiteUrl);
                      if (uri != null) launchPartnerLink(context, uri);
                    },
                  ),
                if (p.mapUrl.isNotEmpty)
                  _ContactRow(
                    keyName: 'partner_detail_map',
                    icon: Icons.map_outlined,
                    label: AppStrings.partnersOpenMap,
                    onTap: () {
                      final uri = Uri.tryParse(p.mapUrl);
                      if (uri != null) launchPartnerLink(context, uri);
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        // Hatalı bilgi bildirimi → mevcut destek yüzeyi (yeni sistem yok).
        TextButton.icon(
          key: const ValueKey('partner_detail_report'),
          onPressed: () => context.push(AppRoutes.settingsSupport),
          icon: const Icon(Icons.flag_outlined, size: 16),
          label: const Text(
            AppStrings.partnersDetailReportHint,
            style: TextStyle(fontSize: 12.5),
          ),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey(keyName),
      borderRadius: BorderRadius.circular(AppRadius.s),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 17, color: AppColors.brandInk),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
