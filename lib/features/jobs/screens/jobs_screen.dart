import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/firinnet_header.dart';
import '../../../core/widgets/premium/job_opportunity_card.dart';
import '../../../core/widgets/premium/premium_scaffold.dart';
import '../../../core/widgets/premium/section_label.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  int _segmentIndex = 0;

  static const _bakeriesHiring = <_Job>[
    _Job(
      position: 'Taş Fırın Ustası',
      business: 'Konak Fırını',
      city: 'İstanbul · Kadıköy',
      salary: '₺ 38.000 – 45.000',
      experience: '5+ yıl deneyim',
      badge: 'Tam zaman',
      shift: 'Gece vardiyası',
      featured: true,
    ),
    _Job(
      position: 'Pastacı Yardımcısı',
      business: 'Selin Pastane',
      city: 'İzmir · Karşıyaka',
      salary: '₺ 24.000 + servis',
      experience: '1+ yıl',
      badge: 'Tam zaman',
      shift: 'Gündüz · 09–18',
    ),
    _Job(
      position: 'Tezgâh & Sipariş Sorumlusu',
      business: 'Ekmek Sepeti',
      city: 'Ankara · Çankaya',
      salary: '₺ 22.000',
      experience: 'Deneyimsiz olabilir',
      badge: 'Vardiyalı',
      shift: '07–15 / 15–23',
    ),
    _Job(
      position: 'Pide Ustası',
      business: 'Antep Pide Evi',
      city: 'Gaziantep · Şahinbey',
      salary: '₺ 30.000',
      experience: '3+ yıl',
      badge: 'Tam zaman',
      shift: 'Gündüz',
    ),
  ];

  static const _bakersLooking = <_Job>[
    _Job(
      position: '12 yıllık ekşi maya ustası',
      business: 'Hasan Kara',
      city: 'Konya',
      salary: 'Beklenti ₺ 40.000+',
      experience: '12 yıl',
      badge: 'Aktif',
      shift: 'Gece üretimi tercih',
      featured: true,
    ),
    _Job(
      position: 'Pastacı (atölye odaklı)',
      business: 'Selin Ateş',
      city: 'İstanbul',
      salary: 'Beklenti ₺ 32.000',
      experience: '6 yıl',
      badge: 'Aktif',
      shift: 'Gündüz',
    ),
    _Job(
      position: 'Tezgâh & sipariş yardımcısı',
      business: 'Burak D.',
      city: 'İzmir',
      salary: 'Beklenti ₺ 22.000',
      experience: '2 yıl',
      badge: 'Aktif',
      shift: 'Vardiya esnek',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final list = _segmentIndex == 0 ? _bakeriesHiring : _bakersLooking;
    final sectionTitle = _segmentIndex == 0
        ? AppStrings.jobsListHiring
        : AppStrings.jobsListLooking;

    return PremiumScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            FirinNetHeader(
              title: AppStrings.jobsTitle,
              subtitle: AppStrings.jobsSubtitle,
              actions: [
                HeaderActionButton(
                  icon: Icons.add_rounded,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: _Segment(
                index: _segmentIndex,
                onChange: (i) => setState(() => _segmentIndex = i),
              ),
            ),
            SectionLabel(title: sectionTitle, trailingLabel: 'Filtre'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageH,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    JobOpportunityCard(
                      position: list[i].position,
                      business: list[i].business,
                      city: list[i].city,
                      salary: list[i].salary,
                      experience: list[i].experience,
                      badge: list[i].badge,
                      shift: list[i].shift,
                      featured: list[i].featured,
                    ),
                    if (i != list.length - 1)
                      const SizedBox(height: AppSpacing.m),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.index, required this.onChange});

  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: AppColors.borderHairline, width: 0.6),
      ),
      child: Row(
        children: [
          _SegmentTab(
            label: AppStrings.jobsSegHiring,
            selected: index == 0,
            onTap: () => onChange(0),
          ),
          _SegmentTab(
            label: AppStrings.jobsSegLooking,
            selected: index == 1,
            onTap: () => onChange(1),
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          alignment: Alignment.center,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? AppColors.elevatedCard : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.s),
            boxShadow: selected ? AppShadow.subtle : null,
            border: selected
                ? Border.all(
                    color: AppColors.copper.withValues(alpha: 0.22),
                    width: 0.8,
                  )
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13.5,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _Job {
  const _Job({
    required this.position,
    required this.business,
    required this.city,
    required this.salary,
    required this.experience,
    required this.badge,
    this.shift,
    this.featured = false,
  });
  final String position;
  final String business;
  final String city;
  final String salary;
  final String experience;
  final String badge;
  final String? shift;
  final bool featured;
}
