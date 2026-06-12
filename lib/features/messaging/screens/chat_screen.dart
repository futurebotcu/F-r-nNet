// FırınNet V1 Messaging M1.2 — Generic ChatScreen.
//
// Donor: flutter_chat_ui ^2.11.1 (Apache-2.0) — Chat widget; backend
// olarak Supabase repository katmanımız bağlıdır. Vendor kopya yok.
//
// Sprint A polish:
//   * M-4 — Marka teması: paketin ChatTheme yüzeyi lemon-white-brandInk
//     token'larına bağlandı (generic paket görünümünden çıktı).
//   * M-5 — Failed send / retry: gönderim optimistic "sending" bubble ile
//     başlar; başarıda "sent", hatada "error" + üst şerit "Tekrar dene".
//     Mesaj metni kaybolmaz (failed bubble'a dokunma veya banner ile resend).
//   * M-7 — Boş sohbet için marka-uyumlu "İlk mesajı sen yaz" empty state.
//
// Akış:
//   1. initState → mesaj listesini repo.listMessages ile çek, controller'a yükle.
//   2. messagesStreamProvider listen → yeni INSERT geldiğinde controller'a ekle.
//   3. onMessageSend → optimistic insert + repo.sendTextMessage; başarılı INSERT
//      realtime stream üzerinden zaten geri dönecek (kendi mesajı dahil; dedupe).
//   4. open'da markAsRead RPC çağrısı + invalidate.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as fcc;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as fcu;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/premium/chat_media_picker_sheet.dart';
import '../../../core/widgets/premium/premium_top_banner.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/services/auth_required_guard.dart';
import '../models/conversation.dart' as our;
import '../models/message.dart' as our;
import '../../safety/providers/safety_providers.dart';
import '../providers/messaging_providers.dart';
import '../services/chat_media_upload_service.dart';
import '../widgets/chat_video_viewer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final fcc.InMemoryChatController _chatController =
      fcc.InMemoryChatController();
  final Set<String> _seenMessageIds = <String>{};

  // M-5 — Optimistic gönderim defteri. Geçici (local) id → en son bubble
  // nesnesi ve özgün metin. Retry ve fail→sending geçişinde kullanılır.
  final Map<String, fcc.Message> _optimistic = <String, fcc.Message>{};
  final Map<String, String> _pendingText = <String, String>{};
  int _localSeq = 0;

  ProviderSubscription<AsyncValue<our.Message>>? _realtimeSub;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(messagingRepositoryProvider);
    try {
      final list = await repo.listMessages(widget.conversationId);
      final mapped = list.map(_toUiMessage).toList();
      _seenMessageIds.addAll(list.map((m) => m.id));
      await _chatController.setMessages(mapped);
      if (mounted) setState(() => _initialized = true);

      // markAsRead — guarded (guest reddi sessizce yutar).
      try {
        await repo.markAsRead(widget.conversationId);
        if (mounted) {
          ref.invalidate(messagesListProvider(widget.conversationId));
        }
        if (mounted) ref.invalidate(conversationsListProvider);
      } catch (e) {
        debugPrint('[FirinNet][Chat] markAsRead skip: $e');
      }

      // Realtime INSERT listener.
      _realtimeSub = ref.listenManual<AsyncValue<our.Message>>(
        messagesStreamProvider(widget.conversationId),
        (prev, next) {
          next.whenData((m) async {
            if (_seenMessageIds.contains(m.id)) return;
            // UGC Safety — engellenen göndericinin canlı mesajı eklenmez.
            if (ref.read(blockedUserIdsSyncProvider).contains(m.senderId)) {
              return;
            }
            _seenMessageIds.add(m.id);
            // Realtime image mesajı ham gelir (signed url yok) → zenginleştir.
            final enriched = await _enrichForUi(m);
            await _chatController.insertMessage(_toUiMessage(enriched));
          });
        },
      );
    } catch (e) {
      debugPrint('[FirinNet][Chat] bootstrap error: $e');
      if (mounted) setState(() => _initialized = true);
    }
  }

  fcc.Message _toUiMessage(our.Message m) {
    // Sprint G — resim mesajı: signed URL varsa ImageMessage.
    if (m.hasImage && (m.imageUrl ?? '').isNotEmpty) {
      return fcc.ImageMessage(
        id: m.id,
        authorId: m.senderId,
        source: m.imageUrl!,
        createdAt: m.createdAt,
        status: fcc.MessageStatus.sent,
      );
    }
    // V1.1 — video mesajı: signed URL varsa VideoMessage. URL yoksa veya
    // media_type bilinmiyorsa text bubble fallback (eski mesajlar bozulmaz).
    if (m.hasVideo && (m.videoUrl ?? '').isNotEmpty) {
      return fcc.VideoMessage(
        id: m.id,
        authorId: m.senderId,
        source: m.videoUrl!,
        createdAt: m.createdAt,
        status: fcc.MessageStatus.sent,
      );
    }
    return fcc.TextMessage(
      id: m.id,
      authorId: m.senderId,
      text: m.content,
      createdAt: m.createdAt,
      status: fcc.MessageStatus.sent,
    );
  }

  /// Realtime/ham medya mesajına (image/video) signed URL gömer (bootstrap'ta
  /// repo zaten enrich eder; bu yol yalnız stream arrival içindir).
  Future<our.Message> _enrichForUi(our.Message m) async {
    if (!(m.hasImage || m.hasVideo) || (m.imageUrl ?? '').isNotEmpty) return m;
    final svc = ref.read(chatMediaUploadServiceProvider);
    final path = m.imageStoragePath;
    if (svc == null || path == null) return m;
    try {
      final url = await svc.signedUrl(path);
      final next = Map<String, dynamic>.from(m.attachments ?? const {});
      next['url'] = url;
      return m.copyWith(attachments: next);
    } catch (_) {
      return m;
    }
  }

  // ── Sprint G + V1.1 — media attachment flow (image + video) ──────
  /// Medya ikonu (flutter_chat_ui onAttachmentTap) → sheet → seç/çek → yükle.
  Future<void> _onAttach() async {
    final pick = await ChatMediaPickerSheet.show(context);
    if (pick == null || !mounted) return;
    final svc = ref.read(chatMediaUploadServiceProvider);
    if (svc == null) return;
    XFile? file;
    try {
      file = pick.isVideo
          ? await svc.pickVideo(pick.source)
          : await svc.pickImage(pick.source);
    } catch (e) {
      debugLogMediaPick('pick', e);
      if (mounted) {
        _showMediaBanner(
          AppStrings.chatMediaPermissionDenied,
          PremiumTopBannerTone.warning,
        );
      }
      return;
    }
    if (file == null || !mounted) return;
    await _uploadAndSend(file, kind: pick.kind);
  }

  Future<void> _uploadAndSend(
    XFile file, {
    ChatMediaKind kind = ChatMediaKind.image,
  }) async {
    final isVideo = kind == ChatMediaKind.video;
    final svc = ref.read(chatMediaUploadServiceProvider);
    final repo = ref.read(messagingRepositoryProvider);
    if (svc == null) return;
    // Medyaya özel (narrow) auth dayanıklılığı — global guard'a dokunulmaz:
    // native picker resume'unda cache'li currentAuthUserProvider stale-null
    // kalmış olabilir → invalidate ile persist session'dan tazele; böylece
    // guarded sendImageMessage'ın canWriteCheck'i logged-in'i guest sanmaz.
    ref.invalidate(currentAuthUserProvider);
    // Owner path segmenti gerçek uid olmalı (storage RLS auth.uid). Tazelenmiş
    // cache → canlı fallback; local-user-me fallback YOK. İkisi de null ise
    // gerçek oturum yok → guest guard (signOut yok).
    final meId = ref.read(currentAuthUserProvider)?.id ??
        ref.read(authRepositoryProvider)?.currentUser?.id;
    if (meId == null) {
      if (mounted) await showAuthRequiredSheet(context, ref);
      return;
    }
    // Persistan "gönderiliyor" şeridi (upload + insert boyunca).
    PremiumTopBannerController.show(
      context,
      message: isVideo
          ? AppStrings.chatMediaVideoUploading
          : AppStrings.chatMediaUploading,
      tone: PremiumTopBannerTone.info,
      duration: Duration.zero,
    );
    try {
      final res = await svc.upload(
        scope: 'conversations',
        scopeId: widget.conversationId,
        ownerId: meId,
        file: file,
        kind: kind,
      );
      final saved = await repo.sendImageMessage(
        conversationId: widget.conversationId,
        attachments: res.toAttachments(),
      );
      PremiumTopBannerController.dismiss();
      // Insert yalnız başarıda → retry duplicate mesaj üretmez.
      if (!_seenMessageIds.contains(saved.id)) {
        _seenMessageIds.add(saved.id);
        await _chatController.insertMessage(_toUiMessage(saved));
      }
    } on ChatMediaTooLargeException {
      PremiumTopBannerController.dismiss();
      if (mounted) {
        _showMediaBanner(
            isVideo
                ? AppStrings.chatMediaVideoTooLarge
                : AppStrings.chatMediaTooLarge,
            PremiumTopBannerTone.warning);
      }
    } on ChatMediaUnsupportedException {
      PremiumTopBannerController.dismiss();
      if (mounted) {
        _showMediaBanner(
            isVideo
                ? AppStrings.chatMediaVideoUnsupported
                : AppStrings.chatMediaUnsupported,
            PremiumTopBannerTone.warning);
      }
    } on GuestActionRequiredException {
      PremiumTopBannerController.dismiss();
      if (mounted) await showAuthRequiredSheet(context, ref);
    } catch (e) {
      debugLogMediaPick('upload', e);
      PremiumTopBannerController.dismiss();
      if (mounted) {
        // Aynı dosyayla retry; başarısızlıkta hiçbir mesaj eklenmedi (kayıp yok).
        PremiumTopBannerController.show(
          context,
          message: isVideo
              ? AppStrings.chatMediaVideoSendError
              : AppStrings.chatMediaSendError,
          tone: PremiumTopBannerTone.danger,
          actionLabel: AppStrings.messagingRetryCta,
          duration: const Duration(seconds: 6),
          onAction: () => _uploadAndSend(file, kind: kind),
        );
      }
    }
  }

  void _showMediaBanner(String msg, PremiumTopBannerTone tone) {
    PremiumTopBannerController.show(context, message: msg, tone: tone);
  }

  void _openImageViewer(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).maybePop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.surface,
                    size: 48,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.surface),
                  onPressed: () => Navigator.of(ctx).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// onMessageSend callback — boş değilse optimistic gönderim başlatır.
  Future<void> _onSend(String text) async {
    await _trySend(text.trim());
  }

  /// M-5 — Optimistic gönderim + başarı/başarısızlık geçişleri.
  ///
  /// [tempId] verilirse mevcut (failed) bubble retry edilir; verilmezse yeni
  /// bir local bubble eklenir. Hata hâlinde mesaj **silinmez**: error
  /// durumuna geçer, metin saklanır ve üst şerit "Tekrar dene" sunar.
  Future<void> _trySend(String trimmed, {String? tempId}) async {
    if (trimmed.isEmpty) return;
    final repo = ref.read(messagingRepositoryProvider);
    final meId = ref.read(currentAuthUserProvider)?.id ?? 'local-user-me';
    final id =
        tempId ?? 'local_${_localSeq++}_${DateTime.now().microsecondsSinceEpoch}';

    final sending = fcc.TextMessage(
      id: id,
      authorId: meId,
      text: trimmed,
      createdAt: DateTime.now(),
      status: fcc.MessageStatus.sending,
    );
    _pendingText[id] = trimmed;
    final prev = _optimistic[id];
    if (prev == null) {
      await _chatController.insertMessage(sending);
    } else {
      await _chatController.updateMessage(prev, sending);
    }
    _optimistic[id] = sending;

    try {
      final saved = await repo.sendTextMessage(
        conversationId: widget.conversationId,
        content: trimmed,
      );
      _pendingText.remove(id);
      final current = _optimistic.remove(id);
      if (_seenMessageIds.contains(saved.id)) {
        // Realtime kendi INSERT'imizi zaten ekledi → optimistic bubble'ı kaldır.
        if (current != null) await _chatController.removeMessage(current);
      } else {
        _seenMessageIds.add(saved.id);
        final sent = fcc.TextMessage(
          id: saved.id,
          authorId: saved.senderId,
          text: saved.content,
          createdAt: saved.createdAt,
          status: fcc.MessageStatus.sent,
        );
        if (current != null) {
          await _chatController.updateMessage(current, sent);
        } else {
          await _chatController.insertMessage(sent);
        }
      }
    } catch (e) {
      debugPrint('[FirinNet][Chat] send error: $e');
      final failed = fcc.TextMessage(
        id: id,
        authorId: meId,
        text: trimmed,
        createdAt: DateTime.now(),
        status: fcc.MessageStatus.error,
      );
      final current = _optimistic[id];
      if (current != null) {
        await _chatController.updateMessage(current, failed);
        _optimistic[id] = failed;
      }
      if (mounted) {
        PremiumTopBannerController.show(
          context,
          message: AppStrings.messagingSendError,
          tone: PremiumTopBannerTone.danger,
          actionLabel: AppStrings.messagingRetryCta,
          duration: const Duration(seconds: 6),
          onAction: () => _trySend(trimmed, tempId: id),
        );
      }
    }
  }

  /// M-5 deepening — Text bubble builder. Non-error → default SimpleTextMessage.
  /// Error → bubble + görünür satır-içi "Tekrar dene" (aynı local mesajı
  /// resend eder; başarıda error temizlenir, başarısızlıkta error kalır →
  /// duplicate riski yok).
  Widget _buildTextMessage(
    BuildContext context,
    fcc.TextMessage message,
    int index, {
    required bool isSentByMe,
    fcc.MessageGroupStatus? groupStatus,
  }) {
    final bubble = fcu.SimpleTextMessage(message: message, index: index);
    if (message.resolvedStatus != fcc.MessageStatus.error) return bubble;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bubble,
        Padding(
          padding: const EdgeInsets.only(top: 3, right: 4, bottom: 2),
          child: InkWell(
            onTap: () {
              final t = _pendingText[message.id];
              if (t != null) _trySend(t, tempId: message.id);
            },
            borderRadius: BorderRadius.circular(AppRadius.s),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.refresh_rounded,
                  size: 13,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 3),
                Text(
                  AppStrings.messagingRetryCta,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// P0 — Resim mesajı bubble'ı. Paket builder verilmeyince exception
  /// fırlatıyor (resimli sohbet açılınca tüm liste kırmızı ErrorWidget).
  /// Görüntüleme CachedNetworkImage; tam ekran viewer mevcut _onMessageTap
  /// üzerinden açılır.
  Widget _buildImageMessage(
    BuildContext context,
    fcc.ImageMessage message,
    int index, {
    required bool isSentByMe,
    fcc.MessageGroupStatus? groupStatus,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.l),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 300),
        child: CachedNetworkImage(
          imageUrl: message.source,
          fit: BoxFit.cover,
          memCacheWidth: 480, // Perf: bubble ~240px; tam-res decode'u önle.
          placeholder: (_, __) => Container(
            width: 240,
            height: 180,
            color: AppColors.surfaceLine,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 240,
            height: 180,
            color: AppColors.surfaceLine,
            child: const Icon(
              Icons.broken_image_rounded,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  /// V1.1 — Video mesajı bubble'ı: koyu yüzey + play overlay + "Video"
  /// etiketi (thumbnail P2 — yeni dependency eklenmedi). Tap _onMessageTap
  /// üzerinden showChatVideoViewer açar.
  Widget _buildVideoMessage(
    BuildContext context,
    fcc.VideoMessage message,
    int index, {
    required bool isSentByMe,
    fcc.MessageGroupStatus? groupStatus,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.l),
      child: Container(
        width: 240,
        height: 160,
        color: AppColors.imageScrimDark,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surface.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.surface,
                size: 34,
              ),
            ),
            Positioned(
              left: 10,
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.videocam_rounded,
                    color: AppColors.surface,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    AppStrings.chatMediaVideoLabel,
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resim bubble → fullscreen viewer; video bubble → player dialog;
  /// hatalı (error) text bubble → retry.
  void _onMessageTap(
    BuildContext context,
    fcc.Message message, {
    required int index,
    required TapUpDetails details,
  }) {
    if (message is fcc.ImageMessage) {
      final src = message.source;
      if (src.isNotEmpty) _openImageViewer(src);
      return;
    }
    if (message is fcc.VideoMessage) {
      final src = message.source;
      if (src.isNotEmpty) showChatVideoViewer(context, src);
      return;
    }
    if (message.resolvedStatus == fcc.MessageStatus.error) {
      final text = _pendingText[message.id];
      if (text != null) _trySend(text, tempId: message.id);
    }
  }

  @override
  void dispose() {
    _realtimeSub?.close();
    _chatController.dispose();
    super.dispose();
  }

  String _contextSubtitle(our.Conversation? conv) {
    if (conv == null) return '';
    switch (conv.contextType) {
      case 'market_listing':
        return AppStrings.messagingContextMarket;
      case 'job_offer':
        return AppStrings.messagingContextJobOffer;
      case 'job_seek':
        return AppStrings.messagingContextJobSeek;
      case 'profile_direct':
      default:
        return '';
    }
  }

  /// M-4 — Marka teması: paket varsayılan mavi/gri yerine lemon-white-brandInk.
  /// Gönderen bubble = lemon + koyu metin; karşı taraf = açık gri yüzey.
  fcc.ChatTheme _brandChatTheme() {
    final base = fcc.ChatTheme.light();
    return base.copyWith(
      colors: base.colors.copyWith(
        primary: AppColors.brandLemon,
        onPrimary: AppColors.brandInk,
        surface: AppColors.background,
        onSurface: AppColors.textPrimary,
        surfaceContainer: AppColors.surfaceLine,
      ),
      shape: BorderRadius.circular(AppRadius.l),
    );
  }

  @override
  Widget build(BuildContext context) {
    final convAsync = ref.watch(
      conversationByIdProvider(widget.conversationId),
    );
    final me = ref.watch(currentAuthUserProvider);
    final meId = me?.id ?? 'local-user-me';

    final title = convAsync.maybeWhen(
      data: (c) => (c?.otherUserName ?? '').isNotEmpty
          ? c!.otherUserName!
          : AppStrings.messagesUnknownUser,
      orElse: () => AppStrings.messagingDefaultTitle,
    );
    final subtitle = convAsync.maybeWhen(
      data: _contextSubtitle,
      orElse: () => '',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.elevatedCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.softGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderHairline),
        ),
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : fcu.Chat(
              chatController: _chatController,
              currentUserId: meId,
              theme: _brandChatTheme(),
              builders: fcc.Builders(
                emptyChatListBuilder: (_) =>
                    _ChatEmptyState(contextLabel: subtitle),
                // M-5 deepening — Default bubble (SimpleTextMessage) korunur;
                // yalnız error durumundaki bubble'ın altına görünür "Tekrar
                // dene" eklenir. chatMessageBuilder override EDİLMEZ → hizalama
                // ve animasyon paketin varsayılanından gelir (güvenli).
                textMessageBuilder: _buildTextMessage,
                // P0 — paket ImageMessage için builder ZORUNLU: builder yoksa
                // Chat widget exception fırlatır ve resimli sohbetin tüm
                // listesi ErrorWidget'a (kırmızı ekran) döner.
                imageMessageBuilder: _buildImageMessage,
                // V1.1 — VideoMessage için de builder zorunlu (aynı sebep).
                videoMessageBuilder: _buildVideoMessage,
              ),
              resolveUser: (id) async {
                // V1: bilinen 2 katılımcı — direct DM. Detail için sadece
                // id'ye göre dummy User döner; UI bubble'da author adı
                // göstermek istemiyoruz (AppBar zaten karşı tarafı yazıyor).
                return fcc.User(id: id);
              },
              onMessageSend: _onSend,
              onMessageTap: _onMessageTap,
              onAttachmentTap: _onAttach,
            ),
    );
  }
}

/// M-7 — Boş sohbet için marka-uyumlu yönlendirici empty state.
class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.contextLabel});

  final String contextLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          120,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandLemonPale,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.brandLemonPressed.withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.forum_rounded,
                size: 32,
                color: AppColors.brandInk,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text(
              AppStrings.messagingEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              contextLabel.isNotEmpty
                  ? '$contextLabel · ${AppStrings.messagingEmptySubtitle}'
                  : AppStrings.messagingEmptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
