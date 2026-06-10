// FırınNet Chat Media V1 (Sprint G) — image attachments testleri.
//
// Kapsam: model getters, upload validation (boyut/tür), local repo image
// round-trip (generic + grup), source-level UI/repo contracts, migration SQL
// (private bucket + membership-gated storage RLS + group_messages.attachments).

import 'dart:io';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/messaging/models/message.dart';
import 'package:firin_defter/features/messaging/repositories/local_messaging_repository.dart';
import 'package:firin_defter/features/messaging/services/chat_media_upload_service.dart';
import 'package:firin_defter/features/social_groups/models/group_message.dart';
import 'package:firin_defter/features/social_groups/repositories/local_social_group_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  group('Model — image attachment getters', () {
    test('Message.hasImage / imageUrl / imageStoragePath', () {
      final m = Message(
        id: 'm1',
        conversationId: 'c1',
        senderId: 'u1',
        content: '📷 Fotoğraf',
        attachments: const {
          'media_type': 'image',
          'storage_path': 'conversations/c1/u1/m_1.jpg',
          'url': 'https://signed/x.jpg',
        },
        createdAt: DateTime(2026, 6, 10),
      );
      expect(m.hasImage, isTrue);
      expect(m.imageUrl, 'https://signed/x.jpg');
      expect(m.imageStoragePath, 'conversations/c1/u1/m_1.jpg');

      final t = Message(
        id: 'm2',
        conversationId: 'c1',
        senderId: 'u1',
        content: 'merhaba',
        createdAt: DateTime(2026, 6, 10),
      );
      expect(t.hasImage, isFalse);
      expect(t.imageUrl, isNull);
    });

    test('GroupMessage.hasImage / imageUrl', () {
      final g = GroupMessage(
        id: 'gm1',
        groupId: 'g1',
        authorName: 'Ali',
        authorRole: 'Üye',
        text: '📷 Fotoğraf',
        createdAt: _fixedDate,
        attachments: const {
          'media_type': 'image',
          'storage_path': 'groups/g1/u1/m_1.png',
          'url': 'https://signed/y.png',
        },
      );
      expect(g.hasImage, isTrue);
      expect(g.imageUrl, 'https://signed/y.png');
    });
  });

  group('Upload validation — boyut/tür', () {
    late Directory dir;
    setUpAll(() => dir = Directory.systemTemp.createTempSync('chatmedia'));
    tearDownAll(() => dir.deleteSync(recursive: true));

    test('jpg → boyut döner (geçerli)', () async {
      final f = File('${dir.path}/ok.jpg')..writeAsBytesSync([1, 2, 3, 4]);
      final size = await ChatMediaUploadService.validateFile(XFile(f.path));
      expect(size, 4);
    });

    test('txt → ChatMediaUnsupportedException', () async {
      final f = File('${dir.path}/bad.txt')..writeAsBytesSync([1, 2, 3]);
      expect(
        () => ChatMediaUploadService.validateFile(XFile(f.path)),
        throwsA(isA<ChatMediaUnsupportedException>()),
      );
    });

    test('>10MB → ChatMediaTooLargeException', () async {
      final big = File('${dir.path}/big.jpg')
        ..writeAsBytesSync(List<int>.filled(ChatMediaUploadService.maxBytes + 1, 0));
      expect(
        () => ChatMediaUploadService.validateFile(XFile(big.path)),
        throwsA(isA<ChatMediaTooLargeException>()),
      );
    });
  });

  group('LocalMessagingRepository — image round-trip', () {
    test('sendImageMessage → listMessages image taşır', () async {
      final repo = LocalMessagingRepository(meId: 'u_me');
      final convId = await repo.findOrCreateDirectConversation(
        otherUserId: 'u_other',
      );
      final saved = await repo.sendImageMessage(
        conversationId: convId,
        attachments: const {
          'media_type': 'image',
          'storage_path': 'conversations/x/u_me/m_1.jpg',
          'size_bytes': 1234,
        },
      );
      expect(saved.hasImage, isTrue);
      // Local'de url = storage_path fallback.
      expect(saved.imageUrl, 'conversations/x/u_me/m_1.jpg');
      final msgs = await repo.listMessages(convId);
      expect(msgs.where((m) => m.hasImage).length, 1);
    });

    test('sendImageMessage non-participant → throws', () async {
      final repo = LocalMessagingRepository(meId: 'u_me');
      expect(
        () => repo.sendImageMessage(
          conversationId: 'nonexistent',
          attachments: const {'media_type': 'image', 'storage_path': 'x'},
        ),
        throwsStateError,
      );
    });
  });

  group('LocalSocialGroupRepository — image attachment', () {
    test('postMessage(attachments) → listMessages hasImage', () async {
      final repo = LocalSocialGroupRepository(seed: false);
      await repo.postMessage(
        GroupMessage(
          id: 'gm1',
          groupId: 'g1',
          authorName: 'Ali',
          authorRole: 'Üye',
          text: '📷 Fotoğraf',
          createdAt: _fixedDate,
          attachments: const {
            'media_type': 'image',
            'storage_path': 'groups/g1/u1/m_1.jpg',
            'url': 'groups/g1/u1/m_1.jpg',
          },
        ),
      );
      final msgs = await repo.listMessages('g1');
      expect(msgs.length, 1);
      expect(msgs.first.hasImage, isTrue);
    });
  });

  group('Source contracts — UI/repo wiring', () {
    test('ChatScreen: onAttachmentTap + ImageMessage + viewer', () {
      final src = File('lib/features/messaging/screens/chat_screen.dart')
          .readAsStringSync();
      expect(src.contains('onAttachmentTap: _onAttach'), isTrue);
      expect(src.contains('fcc.ImageMessage('), isTrue);
      expect(src.contains('_openImageViewer'), isTrue);
      expect(src.contains('ChatMediaPickerSheet.show'), isTrue);
      expect(src.contains('sendImageMessage'), isTrue);
    });

    test('GroupComposer: medya butonu + _attach + image bubble', () {
      final src =
          File('lib/features/social_groups/screens/group_detail_screen.dart')
              .readAsStringSync();
      expect(src.contains('Icons.add_photo_alternate_rounded'), isTrue);
      expect(src.contains('_attach'), isTrue);
      expect(src.contains('class _GroupImageBubble'), isTrue);
      expect(src.contains("scope: 'groups'"), isTrue);
    });

    test('Picker sheet: galeri + kamera seçenekleri', () {
      final src =
          File('lib/core/widgets/premium/chat_media_picker_sheet.dart')
              .readAsStringSync();
      expect(src.contains('ImageSource.gallery'), isTrue);
      expect(src.contains('ImageSource.camera'), isTrue);
    });

    test('Upload service: private bucket + path scheme + signed url', () {
      final src = File(
        'lib/features/messaging/services/chat_media_upload_service.dart',
      ).readAsStringSync();
      expect(src.contains("bucket = 'chat-media'"), isTrue);
      expect(src.contains('createSignedUrl'), isTrue);
      expect(src.contains(r"'$scope/$scopeId/$ownerId/m_$ts.$ext'"), isTrue);
      expect(src.contains('uploadBinary'), isTrue);
    });
  });

  group('Migration SQL — chat_media_v1 contract', () {
    late String sql;
    setUpAll(() {
      sql = File('supabase/migrations/20260610170000_chat_media_v1.sql')
          .readAsStringSync();
    });

    test('PRIVATE bucket chat-media (public=false)', () {
      expect(sql.contains("'chat-media', 'chat-media', false"), isTrue);
      expect(sql.contains("'chat-media', 'chat-media', true"), isFalse,
          reason: 'Chat medyası public bucket OLMAMALI');
    });

    test('group_messages.attachments kolonu', () {
      expect(
        sql.contains('add column if not exists attachments jsonb'),
        isTrue,
      );
    });

    test('storage.objects membership-gated policies', () {
      expect(sql.contains('chat_media_storage_select'), isTrue);
      expect(sql.contains('chat_media_storage_insert'), isTrue);
      expect(sql.contains('chat_media_storage_update_owner'), isTrue);
      expect(sql.contains('chat_media_storage_delete_owner'), isTrue);
      // Participant (conversation) + group member gating.
      expect(sql.contains('is_in_conversation('), isTrue);
      expect(sql.contains('public.group_members'), isTrue);
      // Owner segment yazma kontrolü.
      expect(
        sql.contains('(storage.foldername(name))[3] = auth.uid()::text'),
        isTrue,
      );
    });
  });

  group('AppStrings — chat media sabitleri', () {
    test('tanımlı ve dolu', () {
      expect(AppStrings.chatMediaSheetTitle, isNotEmpty);
      expect(AppStrings.chatMediaPickGallery, isNotEmpty);
      expect(AppStrings.chatMediaTakePhoto, isNotEmpty);
      expect(AppStrings.chatMediaUploading, isNotEmpty);
      expect(AppStrings.chatMediaSendError, isNotEmpty);
      expect(AppStrings.chatMediaTooLarge, isNotEmpty);
      expect(AppStrings.chatMediaUnsupported, isNotEmpty);
      expect(AppStrings.messagingImageFallback, isNotEmpty);
    });
  });
}

final DateTime _fixedDate = DateTime(2026, 6, 10, 12);
