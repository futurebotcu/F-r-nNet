// FırınNet Chat Media V1.1 — video attachment testleri.
//
// Kapsam:
//   1. Validation — video boyut (≤25MB) + tür (mp4/mov) limitleri.
//   2. Upload result — media_type 'video' serialize edilir.
//   3. Model — Message/GroupMessage hasVideo/videoUrl + bilinmeyen
//      media_type her iki getter'da false (text fallback, eski mesaj korunur).
//   4. LocalMessagingRepository — video attachment round-trip + fallback
//      content '🎬 Video'.
//   5. Source contracts — picker sheet 4 seçenek, generic/group ekranlar
//      pickVideo + video bubble + viewer wiring, local-user-me fallback yok.

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/messaging/models/message.dart';
import 'package:firin_defter/features/messaging/repositories/local_messaging_repository.dart';
import 'package:firin_defter/features/messaging/services/chat_media_upload_service.dart';
import 'package:firin_defter/features/social_groups/models/group_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V1.1 — video validation (boyut + tür)', () {
    late Directory tmp;

    setUpAll(() async {
      tmp = await Directory.systemTemp.createTemp('firinnet_video_test');
    });

    tearDownAll(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    Future<XFile> makeFile(String name, int bytes) async {
      final f = File('${tmp.path}/$name');
      await f.writeAsBytes(List<int>.filled(bytes, 7));
      return XFile(f.path, name: name);
    }

    test('mp4 ≤25MB → boyut döner (geçerli)', () async {
      final file = await makeFile('clip.mp4', 1024);
      expect(await ChatMediaUploadService.validateVideoFile(file), 1024);
    });

    test('mov ≤25MB → geçerli', () async {
      final file = await makeFile('clip.mov', 2048);
      expect(await ChatMediaUploadService.validateVideoFile(file), 2048);
    });

    test('avi → ChatMediaUnsupportedException', () async {
      final file = await makeFile('clip.avi', 1024);
      expect(
        () => ChatMediaUploadService.validateVideoFile(file),
        throwsA(isA<ChatMediaUnsupportedException>()),
      );
    });

    test('jpg video olarak → ChatMediaUnsupportedException', () async {
      final file = await makeFile('photo.jpg', 1024);
      expect(
        () => ChatMediaUploadService.validateVideoFile(file),
        throwsA(isA<ChatMediaUnsupportedException>()),
      );
    });

    test('>25MB → ChatMediaTooLargeException', () async {
      final file = await makeFile(
        'big.mp4',
        ChatMediaUploadService.maxVideoBytes + 1,
      );
      expect(
        () => ChatMediaUploadService.validateVideoFile(file),
        throwsA(isA<ChatMediaTooLargeException>()),
      );
    });

    test('video limiti 25 MB; image limiti 10 MB değişmedi', () {
      expect(ChatMediaUploadService.maxVideoBytes, 25 * 1024 * 1024);
      expect(ChatMediaUploadService.maxBytes, 10 * 1024 * 1024);
    });
  });

  group('V1.1 — upload result media_type serialize', () {
    test('video result → attachments media_type=video', () {
      const res = ChatMediaUploadResult(
        storagePath: 'conversations/c1/u1/m_1.mp4',
        sizeBytes: 999,
        mediaType: 'video',
      );
      final att = res.toAttachments();
      expect(att['media_type'], 'video');
      expect(att['storage_path'], 'conversations/c1/u1/m_1.mp4');
      expect(att['size_bytes'], 999);
    });

    test('default result image kalır (V1 davranışı korunur)', () {
      const res = ChatMediaUploadResult(
        storagePath: 'conversations/c1/u1/m_1.jpg',
        sizeBytes: 100,
      );
      expect(res.toAttachments()['media_type'], 'image');
    });
  });

  group('V1.1 — model getters (Message / GroupMessage)', () {
    Message msg(Map<String, dynamic>? att) => Message(
          id: 'm1',
          conversationId: 'c1',
          senderId: 'u1',
          content: 'x',
          messageType: 'text',
          attachments: att,
          createdAt: DateTime(2026, 6, 11),
        );

    test('media_type=video → hasVideo true, hasImage false', () {
      final m = msg({'media_type': 'video', 'url': 'https://x/v.mp4'});
      expect(m.hasVideo, isTrue);
      expect(m.hasImage, isFalse);
      expect(m.videoUrl, 'https://x/v.mp4');
    });

    test('media_type=image → hasImage true, hasVideo false (regresyon)', () {
      final m = msg({'media_type': 'image', 'url': 'https://x/p.jpg'});
      expect(m.hasImage, isTrue);
      expect(m.hasVideo, isFalse);
    });

    test('bilinmeyen media_type → ikisi de false (text fallback güvenli)', () {
      final m = msg({'media_type': 'audio', 'url': 'https://x/a.mp3'});
      expect(m.hasImage, isFalse);
      expect(m.hasVideo, isFalse);
    });

    test('attachments null → güvenli', () {
      final m = msg(null);
      expect(m.hasImage, isFalse);
      expect(m.hasVideo, isFalse);
      expect(m.videoUrl, isNull);
    });

    test('GroupMessage video getters', () {
      final g = GroupMessage(
        id: 'g1',
        groupId: 'grp',
        authorName: 'A',
        authorRole: 'Üye',
        text: '🎬 Video',
        createdAt: DateTime(2026, 6, 11),
        attachments: const {
          'media_type': 'video',
          'url': 'https://x/v.mp4',
          'storage_path': 'groups/g/u/m.mp4',
        },
      );
      expect(g.hasVideo, isTrue);
      expect(g.hasImage, isFalse);
      expect(g.videoUrl, 'https://x/v.mp4');
    });

    test('GroupMessage bilinmeyen media_type → fallback false/false', () {
      final g = GroupMessage(
        id: 'g2',
        groupId: 'grp',
        authorName: 'A',
        authorRole: 'Üye',
        text: 'mesaj',
        createdAt: DateTime(2026, 6, 11),
        attachments: const {'media_type': 'file'},
      );
      expect(g.hasImage, isFalse);
      expect(g.hasVideo, isFalse);
    });
  });

  group('V1.1 — LocalMessagingRepository video round-trip', () {
    test('sendImageMessage(video attachments) → hasVideo + 🎬 fallback',
        () async {
      final repo = LocalMessagingRepository();
      final convId = await repo.findOrCreateDirectConversation(
        otherUserId: 'u2',
      );
      final sent = await repo.sendImageMessage(
        conversationId: convId,
        attachments: const {
          'media_type': 'video',
          'storage_path': 'conversations/c/u/m.mp4',
          'size_bytes': 5,
        },
      );
      expect(sent.hasVideo, isTrue);
      expect(sent.content, AppStrings.messagingVideoFallback);
      final list = await repo.listMessages(convId);
      expect(list.last.hasVideo, isTrue);
      expect((list.last.videoUrl ?? ''), isNotEmpty);
    });
  });

  group('V1.1 — source contracts', () {
    test('picker sheet 4 seçenek: foto galeri/çek + video seç/çek', () {
      final src = File(
        'lib/core/widgets/premium/chat_media_picker_sheet.dart',
      ).readAsStringSync();
      expect(src.contains('AppStrings.chatMediaPickGallery'), isTrue);
      expect(src.contains('AppStrings.chatMediaTakePhoto'), isTrue);
      expect(src.contains('AppStrings.chatMediaPickVideoGallery'), isTrue);
      expect(src.contains('AppStrings.chatMediaRecordVideo'), isTrue);
      expect(src.contains('ChatMediaKind.video'), isTrue);
      expect(src.contains('class ChatMediaPick'), isTrue);
    });

    test('ChatScreen: pickVideo + videoMessageBuilder + viewer wiring', () {
      final src = File('lib/features/messaging/screens/chat_screen.dart')
          .readAsStringSync();
      expect(src.contains('svc.pickVideo(pick.source)'), isTrue);
      expect(src.contains('videoMessageBuilder: _buildVideoMessage'), isTrue);
      expect(src.contains('fcc.VideoMessage('), isTrue);
      expect(src.contains('showChatVideoViewer'), isTrue);
      // P0 sözleşmesi korunur: local-user-me fallback medya yolunda YOK.
      expect(
        src.contains('ref.read(authRepositoryProvider)?.currentUser?.id'),
        isTrue,
      );
    });

    test('GroupComposer: pickVideo + _GroupVideoBubble + viewer wiring', () {
      final src =
          File('lib/features/social_groups/screens/group_detail_screen.dart')
              .readAsStringSync();
      expect(src.contains('svc.pickVideo(pick.source)'), isTrue);
      expect(src.contains('class _GroupVideoBubble'), isTrue);
      expect(src.contains('showChatVideoViewer'), isTrue);
      expect(src.contains('AppStrings.messagingVideoFallback'), isTrue);
    });

    test('upload service: video MIME + kind parametresi', () {
      final src = File(
        'lib/features/messaging/services/chat_media_upload_service.dart',
      ).readAsStringSync();
      expect(src.contains("'video/mp4'"), isTrue);
      expect(src.contains("'video/quicktime'"), isTrue);
      expect(src.contains('ChatMediaKind kind = ChatMediaKind.image'), isTrue);
      expect(src.contains('pickVideo'), isTrue);
    });

    test('viewer SocialPostVideo (chewie/video_player) kullanır — yeni '
        'dependency yok', () {
      final src = File(
        'lib/features/messaging/widgets/chat_video_viewer.dart',
      ).readAsStringSync();
      expect(src.contains('SocialPostVideo'), isTrue);
    });

    test('AppStrings V1.1 sabitleri tanımlı ve dolu', () {
      expect(AppStrings.chatMediaPickVideoGallery, isNotEmpty);
      expect(AppStrings.chatMediaRecordVideo, isNotEmpty);
      expect(AppStrings.chatMediaVideoUploading, isNotEmpty);
      expect(AppStrings.chatMediaVideoSendError, isNotEmpty);
      expect(AppStrings.chatMediaVideoTooLarge, isNotEmpty);
      expect(AppStrings.chatMediaVideoUnsupported, isNotEmpty);
      expect(AppStrings.messagingVideoFallback, isNotEmpty);
    });
  });
}
