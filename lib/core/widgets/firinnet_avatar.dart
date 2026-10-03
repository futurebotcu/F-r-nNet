import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../utils/tr_case.dart';

/// Avatarın temsil ettiği kimlik.
enum FirinNetAvatarKind {
  /// Kişi (kullanıcı/usta) — daire.
  person,

  /// İşletme / tedarikçi logosu — yumuşak köşeli kare.
  business,

  /// FırınNet Akademi botu — marka işaretli daire.
  academy,
}

/// Standart avatar boyutları (px).
class FirinNetAvatarSize {
  const FirinNetAvatarSize._();

  static const double xs = 24;
  static const double s = 32;
  static const double m = 40;
  static const double l = 56;
  static const double xl = 88;
}

/// FırınNet ortak avatarı — feed, yorum, mesaj, bildirim, profil, ilan sahibi.
///
/// Davranış her yerde aynı:
///   * geçerli `http(s)` URL → fotoğraf (ekran boyutunda decode),
///   * yüklenirken / hata / URL yok / bozuk URL → baş harfler (kırık ağ
///     resmi ASLA gösterilmez),
///   * Akademi botu → marka işareti.
/// Çerçeve, zemin ve yazı tonu tek yerde; ekranlar yalnız boyut seçer.
class FirinNetAvatar extends StatelessWidget {
  const FirinNetAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.size = FirinNetAvatarSize.m,
    this.kind = FirinNetAvatarKind.person,
    this.semanticLabel,
  });

  final String? name;
  final String? imageUrl;
  final double size;
  final FirinNetAvatarKind kind;
  final String? semanticLabel;

  /// "Ayşe Nur Kaya" → "AN"; "fırın" → "F"; boş → "?".
  static String initialsOf(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where(
          (p) =>
              p.isNotEmpty &&
              RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(p),
        )
        .toList();
    if (parts.isEmpty) return '?';
    String first(String p) {
      final m = RegExp(r'[\p{L}\p{N}]', unicode: true).firstMatch(p);
      return m == null ? '' : m.group(0)!;
    }

    final buf = StringBuffer(first(parts.first));
    if (parts.length > 1) buf.write(first(parts[1]));
    return buf.toString().trUpper;
  }

  static bool isUsableUrl(String? url) {
    if (url == null) return false;
    final u = Uri.tryParse(url.trim());
    return u != null &&
        (u.scheme == 'http' || u.scheme == 'https') &&
        u.host.isNotEmpty;
  }

  BorderRadius get _radius => kind == FirinNetAvatarKind.business
      ? BorderRadius.circular(size * 0.28)
      : BorderRadius.circular(size / 2);

  @override
  Widget build(BuildContext context) {
    final fallback = _fallback();
    final url = imageUrl?.trim();
    final Widget content =
        kind != FirinNetAvatarKind.academy && isUsableUrl(url)
        ? CachedNetworkImage(
            imageUrl: url!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth: (size * 3).round(),
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, __) => fallback,
            errorWidget: (_, __, ___) => fallback,
          )
        : fallback;
    return Semantics(
      label: semanticLabel ?? name,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: _radius,
          border: Border.all(color: _borderColor, width: 0.8),
        ),
        child: ClipRRect(borderRadius: _radius, child: content),
      ),
    );
  }

  static const Color _neutralBg = Color(0xFFF1F2F4);
  static const Color _borderColor = Color(0xFFE6E8EB);

  Widget _fallback() {
    if (kind == FirinNetAvatarKind.academy) {
      return Container(
        key: const ValueKey('avatar_academy'),
        color: AppColors.brandLemonPale,
        alignment: Alignment.center,
        child: Icon(
          Icons.school_rounded,
          size: size * 0.5,
          color: AppColors.brandInk,
        ),
      );
    }
    final initials = initialsOf(name);
    return Container(
      key: const ValueKey('avatar_initials'),
      color: _neutralBg,
      alignment: Alignment.center,
      child: initials == '?'
          ? Icon(
              kind == FirinNetAvatarKind.business
                  ? Icons.storefront_rounded
                  : Icons.person_rounded,
              size: size * 0.52,
              color: AppColors.textMuted,
            )
          : Text(
              initials,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: AppColors.brandInk,
                fontSize: size * (initials.length > 1 ? 0.36 : 0.42),
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0.2,
              ),
            ),
    );
  }
}
