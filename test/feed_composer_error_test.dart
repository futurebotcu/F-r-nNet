// V1.4 P0.1 — FeedComposer hata yönetimi regression.
//
// Foundation Hardening Audit'te bulunan tek P0 bug: önceki sürümde
// `_submit` içindeki `await repo.addPost(...)` çağrısı try/catch'siz idi;
// addPost exception fırlatırsa `_saving` true olarak takılı kalıyor,
// kullanıcıya hiçbir geri bildirim verilmiyor, kullanıcının yazdığı metin
// (tekrar deneyemeden) ekranda kayboluyordu.
//
// Bu test:
//   1) Hata yolunda → Türkçe snackbar görünür,
//      composer expanded kalır, yazılan metin korunur,
//      _saving=false, gönder butonu yeniden basılabilir.
//   2) Başarı yolunda → mevcut "Akışa eklendi." snackbar'ı + composer
//      collapse + metin temizleme regresyon olarak korunur.

import 'dart:async';

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/feed/models/feed_comment.dart';
import 'package:firin_defter/features/feed/models/feed_insight.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/feed_repository.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/feed/widgets/feed_composer.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// addPost daima fırlatan fake repo. Listeleme/insight çağrıları boş döner
/// ki composer üst widget'ından (gerekli olmasa da) tetiklenirse patlamasın.
class _ThrowingFeedRepo implements FeedRepository {
  int addPostCalls = 0;
  final _ctrl = StreamController<void>.broadcast();

  @override
  Future<FeedPost> addPost({
    required PostType type,
    required String author,
    required String role,
    required String text,
    List<String> tags = const <String>[],
  }) {
    addPostCalls++;
    return Future<FeedPost>.error(Exception('network boom'));
  }

  @override
  Future<List<FeedPost>> listPosts({PostType? type}) async => <FeedPost>[];

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<FeedPost> toggleLike(String postId) async =>
      throw UnimplementedError();

  @override
  Future<FeedPost> toggleSave(String postId) async =>
      throw UnimplementedError();

  @override
  Future<List<FeedInsight>> listInsights() async => <FeedInsight>[];

  @override
  Future<List<FeedComment>> listComments(String postId) async =>
      <FeedComment>[];

  @override
  Future<FeedComment> addComment({
    required String postId,
    required String text,
    String? currentAuthorName,
    String? currentAuthorRole,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteComment(String commentId) async {}

  @override
  Stream<void> watch() => _ctrl.stream;
}

/// `profileControllerProvider` üzerinde seed profile ile başlayan stub.
/// `AppConfig.supabaseEnabled` test'te false olduğu için super constructor
/// authRepositoryProvider null görür ve _loadFor çağrısı tetiklenmez;
/// state'i biz tohumlarız.
class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

const _realProfile = BakeryProfile(
  displayName: 'Hasan Usta',
  accountType: AccountType.commercial,
  city: 'Konya',
  roleBadge: 'Fırıncı',
  email: 'hasan@example.com',
);

Widget _wrap({
  required FeedRepository repo,
  BakeryProfile profile = _realProfile,
}) {
  return ProviderScope(
    overrides: [
      feedRepositoryProvider.overrideWithValue(repo),
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, profile),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 360,
            child: const FeedComposer(),
          ),
        ),
      ),
    ),
  );
}

Future<void> _expandAndType(WidgetTester tester, String text) async {
  await tester.tap(find.byType(FeedComposer));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'FeedComposer P0.1 — addPost throws → Türkçe hata snackbar görünür, '
    'composer açık kalır, metin korunur, gönder butonu yeniden basılabilir',
    (tester) async {
      final repo = _ThrowingFeedRepo();
      await tester.pumpWidget(_wrap(repo: repo));

      const userText = 'Bugün 50 kg un yoğurdum, çok yorucuydu.';
      await _expandAndType(tester, userText);
      await _tapSubmit(tester);

      // 1) Repo gerçekten çağrıldı (guard pre-check passed).
      expect(repo.addPostCalls, 1);

      // 2) Türkçe hata snackbar'ı görünür.
      expect(
        find.text(AppStrings.feedPostCreateError),
        findsOneWidget,
        reason: 'addPost fırlattığında kullanıcıya Türkçe hata gösterilmeli.',
      );

      // 3) Composer hâlâ expanded — TextField yerinde, kullanıcı metni korunmuş.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(userText), findsOneWidget);

      // 4) Loading stuck kalmamış — close (vazgeç) butonu yeniden enabled.
      final closeBtn = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.close_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(
        closeBtn.onPressed,
        isNotNull,
        reason: '_saving=true takılı kalsaydı close butonu da disabled olurdu.',
      );

      // 5) Gönder butonu tekrar tıklanabilir — bir kez daha bas, repo
      //    ikinci çağrıyı görmeli.
      await _tapSubmit(tester);
      expect(repo.addPostCalls, 2);
    },
  );

  testWidgets(
    'FeedComposer regression — addPost başarılıysa "Akışa eklendi." snackbar, '
    'composer kapanır, metin temizlenir',
    (tester) async {
      final repo = LocalFeedRepository(seed: false);
      await tester.pumpWidget(_wrap(repo: repo));

      const userText = '60% hidrasyon tam buğdayda harika oldu.';
      await _expandAndType(tester, userText);
      await _tapSubmit(tester);

      // Success snackbar görünür.
      expect(find.text(AppStrings.feedComposerSavedSnack), findsOneWidget);

      // Composer collapse olmuş — TextField artık yok.
      expect(find.byType(TextField), findsNothing);
      // Collapse modunda prompt metni görünür.
      expect(find.text(AppStrings.feedComposerPrompt), findsOneWidget);
    },
  );
}
