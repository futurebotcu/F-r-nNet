// B2B Pazar — detay ekranları için paylaşılan küçük parçalar.
//
// Ürün / kampanya / mağaza detay ekranları aynı dili kullansın diye: tedarikçi
// satırı (tıklanabilir), açıklama bloğu, birincil/ikincil aksiyon butonları.

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';

/// Tedarikçi mağaza adı satırı; [onTap] doluysa "mağazayı gör" gibi tıklanır.
class B2bSupplierLine extends StatelessWidget {
  const B2bSupplierLine({super.key, required this.name, this.onTap});
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.storefront_rounded,
            size: 15, color: AppColors.brandLemonPressed),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: onTap != null
                  ? AppColors.brandLemonPressed
                  : AppColors.textSecondary,
            ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.brandLemonPressed),
        ],
      ],
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

class B2bDetailDescription extends StatelessWidget {
  const B2bDetailDescription({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class B2bPrimaryAction extends StatelessWidget {
  const B2bPrimaryAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandLemon,
          foregroundColor: AppColors.brandInk,
          disabledBackgroundColor: AppColors.brandLemonSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}

class B2bSecondaryAction extends StatelessWidget {
  const B2bSecondaryAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderHairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }
}

/// Detay ekranı bölüm başlığı (ör. "Mağazanın ürünleri").
class B2bDetailSectionHeader extends StatelessWidget {
  const B2bDetailSectionHeader({super.key, required this.title, this.count});
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Text(
      (count != null && count! > 0) ? '$title ($count)' : title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}
