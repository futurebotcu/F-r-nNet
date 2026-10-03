import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

class FirinNetHeader extends StatelessWidget {
  const FirinNetHeader({
    super.key,
    this.title = 'FırınNet',
    this.subtitle,
    this.actions = const <Widget>[],
    this.showLogo = true,
    this.showBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showLogo;

  /// null = otomatik: push ile açılmış (geri dönülebilir) sayfada logo yerine
  /// geri butonu. Sekme köklerinde logo kalır. "Buradan nasıl çıkarım?"
  /// sorusu kalmaz (Akademi, Paketler vb.).
  final bool? showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final back = showBack ?? (ModalRoute.of(context)?.canPop ?? false);
    // Opak yüzey üstünde blur görsel fark üretmiyordu; yalnız GPU maliyeti.
    return Container(
      color: AppColors.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          back ? AppSpacing.xs : AppSpacing.pageH,
          AppSpacing.m,
          AppSpacing.pageH,
          AppSpacing.m,
        ),
        child: Row(
          children: [
            if (back) ...[
              IconButton(
                key: const ValueKey('firinnet_header_back'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: AppSpacing.xs),
            ] else if (showLogo) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.brandLemonPale,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(
                    color: AppColors.brandLemonSoft,
                    width: 0.6,
                  ),
                  boxShadow: AppShadow.subtle,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.brandLemonPressed,
                  size: 18,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.15,
                      height: 1.15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: AppSpacing.xs),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

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
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppColors.brandLemonPressed.withValues(alpha: 0.08),
        // 40px: rahat dokunma alanı (34px parmakla zor tutturuluyordu).
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: AppColors.brandInk),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}
