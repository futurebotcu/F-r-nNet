import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../models/dealer.dart';

/// Bayi avatarı — bayi adının ilk harfini renkli kart/daire içinde
/// gösterir (Quality Patch v2).
///
/// Daha önce `DealerListScreen._DealerCard` ve `DealerReportsTabScreen
/// ._DealerRow` ayrı ayrı `Container + Text` yazıyordu (kare vs daire +
/// farklı renk paleti). Burada paylaşılmış halde — [shape] + [palette]
/// + [size] ile her iki kullanım da karşılanıyor.
///
/// **Not (Quality Patch v2 kapsamı)**: `DealerPickerSheet`'in
/// `CircleAvatar` pattern'i bu widget'a *agresif* taşınmadı (sheet'in
/// kendi görsel grammar'ı bozulmasın diye); ileride v3'te ayrıca
/// değerlendirilebilir.
class DealerAvatar extends StatelessWidget {
  const DealerAvatar({
    super.key,
    required this.dealer,
    this.size = 40,
    this.shape = DealerAvatarShape.roundedSquare,
    this.palette = DealerAvatarPalette.copper,
    this.fallbackChar = 'B',
  });

  final Dealer dealer;
  final double size;
  final DealerAvatarShape shape;
  final DealerAvatarPalette palette;

  /// `dealer.name` boşsa kullanılacak harf. List ekranı 'B', Reports
  /// ekranı '?' tercih ediyordu; default 'B' (DealerListScreen mevcut
  /// davranışı). Reports tarafında fallback nadir olduğu için default
  /// 'B' yeterli.
  final String fallbackChar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _resolveColors(palette, dealer.isActive);
    final initial =
        dealer.name.isNotEmpty ? dealer.name[0].toUpperCase() : fallbackChar;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: shape == DealerAvatarShape.roundedSquare
            ? BorderRadius.circular(AppRadius.s)
            : null,
        shape: shape == DealerAvatarShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        border: colors.border != null
            ? Border.all(color: colors.border!, width: 0.6)
            : null,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: colors.foreground,
          fontWeight: FontWeight.w800,
          // List ekranındaki 17pt ve Reports'taki ~14pt arasında — size
          // ile orantılı.
          fontSize: size * 0.40,
        ),
      ),
    );
  }
}

enum DealerAvatarShape { roundedSquare, circle }

/// Avatar renk paleti.
///
/// - [autoActivity]: bayi `isActive=true` ise softGold tonu; pasifse
///   surfaceLine + textMuted (DealerListScreen davranışı).
/// - [copper]: copper tonu + ince border (Reports row davranışı).
/// - [softGold]: aktif/pasif fark gözetmez; softGold tonu.
enum DealerAvatarPalette { autoActivity, copper, softGold }

class _AvatarColors {
  const _AvatarColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}

_AvatarColors _resolveColors(DealerAvatarPalette palette, bool isActive) {
  switch (palette) {
    case DealerAvatarPalette.autoActivity:
      if (isActive) {
        return _AvatarColors(
          background: AppColors.softGold.withValues(alpha: 0.14),
          foreground: AppColors.softGold,
        );
      }
      return _AvatarColors(
        background: AppColors.surfaceLine.withValues(alpha: 0.5),
        foreground: AppColors.textMuted,
      );
    case DealerAvatarPalette.copper:
      return _AvatarColors(
        background: AppColors.copper.withValues(alpha: 0.10),
        foreground: AppColors.copper,
        border: AppColors.copper.withValues(alpha: 0.25),
      );
    case DealerAvatarPalette.softGold:
      return _AvatarColors(
        background: AppColors.softGold.withValues(alpha: 0.14),
        foreground: AppColors.softGold,
      );
  }
}
