import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// FırınNet markalı sade üst başlık.
/// Sol: ikon + ürün adı. Sağ: opsiyonel actionlar.
class FirinNetHeader extends StatelessWidget {
  const FirinNetHeader({
    super.key,
    this.title = 'FırınNet',
    this.subtitle,
    this.actions = const <Widget>[],
    this.showLogo = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // FirinNetHeader polish sprint — bottom padding m (12) → l (16):
      // header content + caller divider/strip arası daha nefesli.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.l,
        AppSpacing.pageH,
        AppSpacing.l,
      ),
      child: Row(
        children: [
          if (showLogo) ...[
            Container(
              // FirinNetHeader polish sprint — brand mark:
              //  • boyut 38 → 40 (subtle brand presence bump)
              //  • radius s (12) → m (16) (referans tasarımdaki yumuşaklık)
              //  • softGold inner border 0.32α 0.6px (sıcak bakır halo)
              //  • shadow alpha 0.25 → 0.28 (biraz daha belirgin)
              //  • icon 20 → 22 (logo içinde nefes)
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.copper, AppColors.copperMuted],
                ),
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(
                  color: AppColors.softGold.withValues(alpha: 0.32),
                  width: 0.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.copper.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  // FirinNetHeader polish sprint — wordmark:
                  // 22 → 23 + letterSpacing -0.4 → -0.5 (premium sıkılık).
                  // maxLines:1 + ellipsis: küçük ekranda taşma guard'ı.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    // FirinNetHeader polish sprint — subtitle:
                    // fontSize 12.5 → 13 + letterSpacing 0.1 → 0.15 +
                    // w500 → w600 (daha okunabilir). maxLines:1 + ellipsis
                    // guard.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final a in actions) ...[
            const SizedBox(width: AppSpacing.s),
            a,
          ],
        ],
      ),
    );
  }
}

/// Header sağında kullanılan yuvarlak ikon butonu.
class HeaderActionButton extends StatelessWidget {
  const HeaderActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: AppColors.surface,
      shape: CircleBorder(
        side: BorderSide(
          color: AppColors.borderLight,
          width: 0.6,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppColors.copper.withValues(alpha: 0.10),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: AppColors.onBackgroundPrimary),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}
