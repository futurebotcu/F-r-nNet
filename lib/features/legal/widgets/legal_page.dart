// Paylaşılan yasal sayfa iskeleti — Gizlilik / Kullanım Şartları / Topluluk
// Kuralları / Hesap & Veri Silme ekranları aynı premium dili kullanır.
//
// White-first, sade hiyerarşi: ferah AppBar + opsiyonel kısa giriş paragrafı +
// numaralı/başlıklı bölümler. Auth akışından (oturumsuz) açılabildiği için geri
// butonu boş back-stack'te authEntry'ye düşer.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// Tek bir yasal bölüm — başlık + gövde.
class LegalSection {
  const LegalSection(this.title, this.body);
  final String title;
  final String body;
}

/// Yasal/legal ekran iskeleti.
class LegalScaffold extends StatelessWidget {
  const LegalScaffold({
    super.key,
    required this.title,
    required this.sections,
    this.intro,
  });

  final String title;
  final List<LegalSection> sections;

  /// Sayfanın başında, bölümlerden önce gösterilen kısa giriş paragrafı.
  final String? intro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.authEntry);
            }
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.l,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [
            if (intro != null) ...[
              Text(
                intro!,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.l),
              const Divider(height: 1, color: AppColors.borderHairline),
              const SizedBox(height: AppSpacing.l),
            ],
            for (var i = 0; i < sections.length; i++)
              _SectionView(section: sections[i]),
          ],
        ),
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});
  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            section.body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
