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
