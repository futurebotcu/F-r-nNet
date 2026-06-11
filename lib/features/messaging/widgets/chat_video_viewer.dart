// FırınNet Chat Media V1.1 — paylaşılan video viewer dialog'u.
//
// Generic ChatScreen ve grup chat video bubble'ları tap'te bunu açar.
// Oynatıcı SocialPostVideo (video_player + chewie) yeniden kullanılır —
// loading/error state'leri ve marka progress renkleri oradan gelir;
// yeni dependency yok.

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../social/post/widgets/social_post_video.dart';

/// Tam ekran karartmalı video oynatma dialog'u. Kapatma: sağ üst X.
Future<void> showChatVideoViewer(BuildContext context, String url) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (ctx) => Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SocialPostVideo(url: url),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.surface),
              onPressed: () => Navigator.of(ctx).maybePop(),
            ),
          ),
        ),
      ],
    ),
  );
}
