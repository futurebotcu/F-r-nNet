// FırınNet Runtime Jank Hardening — mesaj gönderim sonrası invalidation
// storm + loading-flash davranış sözleşmeleri.

import 'dart:async';
import 'dart:io';

import 'package:firin_defter/features/social_groups/models/group_category.dart';
import 'package:firin_defter/features/social_groups/models/group_message.dart';
import 'package:firin_defter/features/social_groups/repositories/supabase_social_group_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Jank — grup mesaj tick ayrımı (storm önleme)', () {
    test(
        'watch (yapısal) ve watchMessages (mesaj) AYRI stream — mesaj '
        'gönderimi metadata/üye/liste tick\'ini tetiklemez', () async {
      // Not: Supabase client gerekmediği için doğrudan repo davranışı yerine
      // kaynak sözleşmesi + ayrı stream varlığı doğrulanır (client mock'suz).
      // Stream kimliği ayrımı: watch() ile watchMessages() farklı controller.
      final src = File(
        'lib/features/social_groups/repositories/'
        'supabase_social_group_repository.dart',
      ).readAsStringSync();
      // İki ayrı broadcast controller + ayrı notify + ayrı watch.
      expect(src.contains('_messageChanges'), isTrue);
      expect(src.contains('void _notifyMessages() => _messageChanges.add(null)'),
          isTrue);
      // postMessage gövdesi (insert ile _notifyMessages arası) mesaj tick'i
      // çağırır. postMessage'dan sonraki ilk _notifyMessages, ondan önce
      // başka write metodunun _notify'ı olmamalı: postMessage→Private join
      // arasında _notify() yok.
      final pmStart = src.indexOf('Future<void> postMessage');
      final pmEnd = src.indexOf('// ──', pmStart);
      final pmBlock = src.substring(pmStart, pmEnd);
      expect(pmBlock.contains('_notifyMessages()'), isTrue,
          reason: 'Mesaj gönderimi yalnız mesaj listesini tazelemeli');
      expect(pmBlock.contains('_notify();'), isFalse,
          reason: 'postMessage yapısal storm tetiklememeli');
    });

    test('groupMessagesProvider mesaj tick\'ini izler', () {
      final src = File(
        'lib/features/social_groups/providers/social_group_providers.dart',
      ).readAsStringSync();
      expect(src.contains('groupMessageChangesProvider'), isTrue);
      expect(src.contains('repo.watchMessages()'), isTrue);
      // groupMessagesProvider mesaj tick'ini watch eder.
      final gmpStart = src.indexOf('final groupMessagesProvider');
      final gmpBlock = src.substring(gmpStart, gmpStart + 320);
      expect(gmpBlock.contains('ref.watch(groupMessageChangesProvider)'),
          isTrue);
    });
  });

  group('Jank — loading-flash önleme (skipLoadingOnReload)', () {
    test('grup mesaj listesi reload\'da flash atmaz', () {
      final src = File(
        'lib/features/social_groups/screens/group_detail_screen.dart',
      ).readAsStringSync();
      // Grup mesaj listesi reload'da flash atmamalı (tek when, mesaj listesi).
      expect(src.contains('skipLoadingOnReload: true'), isTrue);
      expect(src.contains('messagesAsync.when('), isTrue);
      // Üye header son veriyi korur (flicker yok).
      expect(src.contains('membersAsync.valueOrNull'), isTrue);
    });

    test('konuşma listesi reload\'da flash atmaz', () {
      final src = File(
        'lib/features/messages/screens/messages_list_screen.dart',
      ).readAsStringSync();
      expect(src.contains('skipLoadingOnReload: true'), isTrue);
    });
  });

  // Davranış doğrulaması: GroupMessage modeli postMessage round-trip'i
  // (mesaj tick'i sonrası listMessages aynı içeriği döndürmeli — regresyon
  // koruması; gerçek DB yok, model bütünlüğü).
  test('GroupMessage attachments/text bütünlüğü korunur', () {
    final m = GroupMessage(
      id: 'g1',
      groupId: 'grp',
      ownerId: 'u1',
      authorName: 'A',
      authorRole: 'Üye',
      text: 'merhaba',
      createdAt: DateTime(2026, 6, 12),
      attachments: const {'media_type': 'image', 'url': 'x'},
    );
    expect(m.hasImage, isTrue);
    expect(m.text, 'merhaba');
    // GroupCategory enum bozulmadı (provider zinciri importu).
    expect(GroupCategory.bakers.persistKey, isNotEmpty);
  });

  test('Supabase repo iki ayrı StreamController tutar (kaynak)', () {
    // Derleme zamanı garantisi: tip mevcut + watchMessages override var.
    expect(SupabaseSocialGroupRepository, isNotNull);
    final src = File(
      'lib/features/social_groups/repositories/'
      'supabase_social_group_repository.dart',
    ).readAsStringSync();
    expect(src.contains('Stream<void> watchMessages() => _messageChanges.stream'),
        isTrue);
  });
}
