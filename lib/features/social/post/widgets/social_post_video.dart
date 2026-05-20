// FırınNet Social V2 Commit 3 — Post video player widget.
//
// Donor: `lib/feed/post/video/post_video_player.dart` muadili. FırınNet
// kuralları:
//   * autoplay zorunlu değil — `Chewie` default autoPlay=false; kullanıcı
//     play butonuna basana kadar oynatmaz.
//   * Network'ten ağırlık gelmesin; küçük poster yerine sade ilk frame
//     `VideoPlayer.initialize()` ile alınır.
//   * Hata durumunda kart kırılmaz; basit hata kutusu gösterilir.

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/app_strings.dart';

class SocialPostVideo extends StatefulWidget {
  const SocialPostVideo({
    super.key,
    required this.url,
    this.aspectRatio = 16 / 9,
  });

  final String url;
  final double aspectRatio;

  @override
  State<SocialPostVideo> createState() => _SocialPostVideoState();
}

class _SocialPostVideoState extends State<SocialPostVideo> {
  VideoPlayerController? _controller;
  ChewieController? _chewie;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      final aspect = c.value.aspectRatio == 0
          ? widget.aspectRatio
          : c.value.aspectRatio;
      _controller = c;
      _chewie = ChewieController(
        videoPlayerController: c,
        autoPlay: false,
        looping: false,
        showControlsOnInitialize: false,
        allowMuting: true,
        allowFullScreen: true,
        aspectRatio: aspect,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.copper,
          handleColor: AppColors.copper,
          bufferedColor: AppColors.borderHairline,
          backgroundColor: AppColors.surface,
        ),
        placeholder: const ColoredBox(color: Colors.black),
      );
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _initFailed = true);
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initFailed) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: AppColors.surface,
          alignment: Alignment.center,
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.m),
            child: Text(
              AppStrings.postVideoPlaybackError,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final chewie = _chewie;
    if (chewie == null) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white70),
            ),
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: chewie.aspectRatio ?? widget.aspectRatio,
      child: Chewie(controller: chewie),
    );
  }
}
