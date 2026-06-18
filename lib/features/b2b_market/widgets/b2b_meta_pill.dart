// B2B Pazar — kartlar arası paylaşılan küçük UI atomları.
//
// Ürün/kampanya/mağaza/teklif kartlarında tekrar eden minik parçalar tek
// yerde: meta pill (ikon + etiket), sahiplik rozeti, durum rozeti. Yeni
// tasarım dili icat etmez; mevcut token + nötr yüzey dilini kullanır.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../models/b2b_quote_request.dart';

/// İkon + etiketli nötr meta pill (kategori, bölge, miktar vb.).
class B2bMetaPill extends StatelessWidget {
  const B2bMetaPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Benim ürünüm / Benim kampanyam" gibi sahiplik rozeti (lemon accent).
class B2bOwnerBadge extends StatelessWidget {
  const B2bOwnerBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandLemon,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.brandInk,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// "Taslak" rozeti — yayınlanmamış ürün/kampanya için (yalnız sahip görür).
class B2bDraftBadge extends StatelessWidget {
  const B2bDraftBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.borderHairline, width: 0.8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded, size: 13, color: AppColors.textMuted),
          SizedBox(width: 3),
          Text(
            'Taslak',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kendi ürün/kampanya kartında yönetim menüsü (⋮): Düzenle + publish toggle.
/// Yalnız sahibe ve verilen callback'lere göre gösterilir.
class B2bManageMenu extends StatelessWidget {
  const B2bManageMenu({
    super.key,
    required this.published,
    this.onEdit,
    this.onTogglePublish,
  });

  final bool published;
  final VoidCallback? onEdit;
  final VoidCallback? onTogglePublish;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: PopupMenuButton<String>(
        tooltip: 'Yönet',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        icon: const Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: AppColors.textSecondary,
        ),
        onSelected: (v) {
          if (v == 'edit') onEdit?.call();
          if (v == 'toggle') onTogglePublish?.call();
        },
        itemBuilder: (_) => <PopupMenuEntry<String>>[
          if (onEdit != null)
            const PopupMenuItem<String>(
              value: 'edit',
              child: _MenuRow(icon: Icons.edit_outlined, label: 'Düzenle'),
            ),
          if (onTogglePublish != null)
            PopupMenuItem<String>(
              value: 'toggle',
              child: _MenuRow(
                icon: published
                    ? Icons.visibility_off_outlined
                    : Icons.public_rounded,
                label: published ? 'Taslağa al' : 'Yayına al',
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.textPrimary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Teklif talebi durum rozeti (Bekliyor / Cevap geldi / Kapandı).
class B2bStatusPill extends StatelessWidget {
  const B2bStatusPill({super.key, required this.status});

  final B2bQuoteStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (status) {
      B2bQuoteStatus.waiting => (
          const Color(0xFFFFF9EB),
          const Color(0xFFB45309),
          Icons.schedule_rounded,
        ),
      B2bQuoteStatus.replied => (
          const Color(0xFFF3FBEF),
          const Color(0xFF166534),
          Icons.mark_chat_read_rounded,
        ),
      B2bQuoteStatus.closed => (
          AppColors.surfaceVariant,
          AppColors.textMuted,
          Icons.check_circle_outline_rounded,
        ),
      B2bQuoteStatus.cancelled => (
          const Color(0xFFFDF2F2),
          const Color(0xFF991B1B),
          Icons.cancel_outlined,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: fg.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
