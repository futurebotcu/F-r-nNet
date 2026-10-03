import 'package:flutter/material.dart';

/// Hikaye medyasının TEK çerçevesi — oluşturma önizlemesi ve izleyici aynı
/// 9:16 kutuyu ve aynı [fit]'i kullanır. Böylece önizlemede görülen kadraj
/// (özne / görsel üstü yazı konumu) izleyicide birebir aynı kalır; önceden
/// önizleme `cover` (kırpılmış), izleyici tam ekran `contain` çiziyordu.
class StoryMediaFrame extends StatelessWidget {
  const StoryMediaFrame({super.key, required this.child, this.borderRadius});

  /// Dikey telefon hikaye oranı.
  static const double aspectRatio = 9 / 16;

  /// Çerçeveyi dolduran ortalanmış kadraj (önizleme = izleyici).
  static const BoxFit fit = BoxFit.cover;

  /// Medya; [fit] ile çizilmeli (ör. `Image.memory(bytes, fit:
  /// StoryMediaFrame.fit)`).
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        key: const ValueKey('story_media_frame'),
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}
