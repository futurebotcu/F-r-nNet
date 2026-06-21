// Feed sprint — kart gövdesi tap → detay (Twitter/X) + action ikon çakışmaz.
//
// Kart gövdesine (metin/medya) dokunmak SocialCommentsPage'i push eder.
// Action ikonlarına (beğeni vb.) basmak detayı AÇMAZ — kendi işini yapar
// (canWrite=true → beğeni toggle; navigation tetiklenmez).

import 'package:firin_defter/features/auth/providers/auth_providers.dart';
import 'package:firin_defter/features/auth/providers/guest_mode_provider.dart';
import 'package:firin_defter/features/feed/models/feed_post.dart';
import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/feed/providers/feed_providers.dart';
import 'package:firin_defter/features/feed/repositories/local_feed_repository.dart';
import 'package:firin_defter/features/profile/models/bakery_profile.dart';
import 'package:firin_defter/features/profile/providers/profile_provider.dart';
import 'package:firin_defter/features/social/post/social_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PushRecorder extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

const _profile = BakeryProfile(
  displayName: 'Hasan Kara',
  accountType: AccountType.individual,
  city: 'Konya',
  roleBadge: 'Usta Fırıncı',
  email: 'hasan@example.com',
);

class _SeededProfileController extends ProfileController {
  _SeededProfileController(super.ref, BakeryProfile initial) {
    state = initial;
  }
}

FeedPost _post() => FeedPost(
      id: 'p1',
      ownerId: 'owner-1',
      type: PostType.production,
      author: 'Hasan Kara',
      role: 'Usta Fırıncı · Konya',
      text: 'Tam buğday simit denemeleri.',
      createdAt: DateTime(2026, 1, 1),
      gradient: const [Color(0xFFCCCCCC), Color(0xFFDDDDDD)],
    );

Widget _wrap(_PushRecorder rec) {
  return ProviderScope(
    overrides: [
      feedRepositoryProvider.overrideWith(
        (_) => LocalFeedRepository(seed: false),
      ),
      currentAuthUserProvider.overrideWith((_) => null),
      guestModeProvider.overrideWith(
        (_) => GuestModeNotifier()..setGuest(false),
      ),
      // canWrite=true (local mode + profil) → beğeni tap auth-sheet açmaz.
      profileControllerProvider.overrideWith(
        (ref) => _SeededProfileController(ref, _profile),
      ),
    ],
    child: MaterialApp(
      navigatorObservers: [rec],
      home: Scaffold(
        body: SingleChildScrollView(child: SocialPostCard(post: _post())),
      ),
    ),
  );
}

void main() {
  testWidgets('Kart gövdesine (metin) dokununca detay route push edilir',
      (tester) async {
    final rec = _PushRecorder();
    await tester.pumpWidget(_wrap(rec));
    await tester.pump();
    final baseline = rec.pushes; // home route push'u

    // Caption metnine dokun → SocialCommentsPage.show senkron push eder.
    await tester.tap(find.text('Tam buğday simit denemeleri.'));
    expect(rec.pushes, baseline + 1);
  });

  testWidgets('Action ikona (beğeni) dokununca detay AÇILMAZ (çakışma yok)',
      (tester) async {
    final rec = _PushRecorder();
    await tester.pumpWidget(_wrap(rec));
    await tester.pump();
    final baseline = rec.pushes;

    // Beğeni ikonu kendi InkWell'i ile tap'i alır; hiçbir route push edilmez
    // (canWrite=true → toggle yolu; detay/auth-sheet açılmaz).
    await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined));
    await tester.pump();
    expect(rec.pushes, baseline);
  });
}
