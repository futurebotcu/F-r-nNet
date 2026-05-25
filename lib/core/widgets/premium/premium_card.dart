import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// Kart hiyerarşi katmanı (Visual North Star Sprint 1A).
///
/// - [standard]: liste satırı, post kart, KPI tile — `borderHairline` +
///   `AppShadow.card` + radius `l` (20).
/// - [hero]: featured/öne çıkan içerik — `elevatedCard` bg + `borderHairline`
///   + `AppShadow.heroGlow` + radius `xl` (28). Mevcut `warm=true`
///   bayrağı bu tier'a denk gelir (backward compat).
/// - [compact]: sıralı kart-row (tx satır, comment) — border yok + shadow
///   yok + radius `m` (16).
enum CardTier { standard, hero, compact }

/// Yumuşak premium kart — hairline kenar + sakin gölge ile derinlik.
/// Üç tier: [CardTier.standard] (default), [CardTier.hero], [CardTier.compact].
///
/// Backward compat: `warm: true` ile çağırı, `tier=hero` ile birebir aynı
/// görsel davranışı korur (eski 2-varyantlı API kırılmaz).
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.l),
    this.onTap,
    this.warm = false,
    this.tier = CardTier.standard,
    this.radius,
    this.bordered = true,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Backward compat — `true` ise [CardTier.hero] davranışı (görsel kayma
  /// yok). Yeni kod `tier: CardTier.hero` tercih etmeli.
  final bool warm;

  /// Kart hiyerarşi katmanı. Default [CardTier.standard].
  final CardTier tier;

  /// Tier default'unu override eden opsiyonel radius. `null` ise tier
  /// kendi radius'unu kullanır (`standard=l`, `hero=xl`, `compact=m`).
  final double? radius;

  final bool bordered;
  final bool elevated;

  /// `warm=true` ise hero, aksi halde [tier].
  CardTier get _effectiveTier => warm ? CardTier.hero : tier;

  double get _resolvedRadius {
    if (radius != null) return radius!;
    switch (_effectiveTier) {
      case CardTier.standard:
        return AppRadius.l;
      case CardTier.hero:
        return AppRadius.xl;
      case CardTier.compact:
        return AppRadius.m;
    }
  }

  Color get _resolvedBg {
    switch (_effectiveTier) {
      case CardTier.standard:
        return AppColors.card;
      case CardTier.hero:
        return AppColors.elevatedCard;
      case CardTier.compact:
        return AppColors.card;
    }
  }

  /// Compact tier border + shadow taşımaz (sıralı row'larda divider yeterli).
  bool get _compactCleared => _effectiveTier == CardTier.compact;

  List<BoxShadow>? _resolvedShadow() {
    if (!elevated) return null;
    if (_compactCleared) return null;
    switch (_effectiveTier) {
      case CardTier.hero:
        // Premium card trio sprint — hero kart için warm copper halo
        // (eski heroGlow mat espresso idi; FırınNet referansındaki sıcak
        // bakır kart hissi için copper alpha 0.16 kullanılır). Aynı
        // offset/blur ölçeği; sadece renk ailesi sıcaklığa kayar.
        return AppShadow.copper;
      case CardTier.standard:
      case CardTier.compact:
        return AppShadow.card;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resolvedRadius;
    final showBorder = bordered && !_compactCleared;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(r),
    );

    final content = Container(
      decoration: BoxDecoration(
        color: _resolvedBg,
        borderRadius: BorderRadius.circular(r),
        border: showBorder
            ? Border.all(color: AppColors.borderHairline, width: 0.6)
            : null,
        boxShadow: _resolvedShadow(),
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        splashColor: AppColors.softGold.withValues(alpha: 0.06),
        highlightColor: AppColors.softGold.withValues(alpha: 0.04),
        child: content,
      ),
    );
  }
}
