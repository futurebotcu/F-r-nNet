// FırınNet V1 Messaging M1.2 — Generic ChatScreen.
//
// Donor: flutter_chat_ui ^2.11.1 (Apache-2.0) — Chat widget; backend
// olarak Supabase repository katmanımız bağlıdır. Vendor kopya yok.
//
// Akış:
//   1. initState → mesaj listesini repo.listMessages ile çek, controller'a yükle.
//   2. messagesStreamProvider listen → yeni INSERT geldiğinde controller'a ekle.
//   3. onMessageSend → repo.sendTextMessage; başarılı INSERT realtime stream
//      üzerinden zaten geri dönecek (kendi mesajı dahil).
//   4. open'da markAsRead RPC çağrısı + invalidate.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as fcc;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as fcu;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/conversation.dart' as our;
import '../models/message.dart' as our;
import '../providers/messaging_providers.dart';

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
  ProviderSubscription<AsyncValue<our.Message>>? _realtimeSub;
  bool _initialized = false;
  bool _sending = false;

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
        if (mounted)
          ref.invalidate(messagesListProvider(widget.conversationId));
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
            _seenMessageIds.add(m.id);
            await _chatController.insertMessage(_toUiMessage(m));
          });
        },
      );
    } catch (e) {
      debugPrint('[FirinNet][Chat] bootstrap error: $e');
      if (mounted) setState(() => _initialized = true);
    }
  }

  fcc.Message _toUiMessage(our.Message m) {
    return fcc.TextMessage(
      id: m.id,
      authorId: m.senderId,
      text: m.content,
      createdAt: m.createdAt,
    );
  }

  Future<void> _onSend(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    setState(() => _sending = true);
    final repo = ref.read(messagingRepositoryProvider);
    try {
      final saved = await repo.sendTextMessage(
        conversationId: widget.conversationId,
        content: trimmed,
      );
      // Realtime kendi INSERT'imizi de geri verecek; ama gecikme olursa
      // optimistic insert. Dedupe için _seenMessageIds kontrol edilir.
      if (!_seenMessageIds.contains(saved.id)) {
        _seenMessageIds.add(saved.id);
        await _chatController.insertMessage(_toUiMessage(saved));
      }
    } catch (e) {
      debugPrint('[FirinNet][Chat] send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.messagingSendError)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
              resolveUser: (id) async {
                // V1: bilinen 2 katılımcı — direct DM. Detail için sadece
                // id'ye göre dummy User döner; UI bubble'da author adı
                // göstermek istemiyoruz (AppBar zaten karşı tarafı yazıyor).
                return fcc.User(id: id);
              },
              onMessageSend: _onSend,
            ),
    );
  }
}
