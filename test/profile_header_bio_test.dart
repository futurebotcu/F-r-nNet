// PR-A — Profile Reference Placement: header'da kısa bio + (self + boş) CV CTA.
// ProfileHeader provider'sız doğrudan pump edilebilir → gerçek widget testi.

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/profile/models/public_profile_detail.dart';
import 'package:firin_defter/features/social/models/social_profile.dart';
import 'package:firin_defter/features/social/profile/widgets/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = SocialProfile(
  id: 'u1',
  displayName: 'Fatih Usta',
  professionBadge: 'Usta Fırıncı',
  city: 'Manisa',
);

PublicProfileDetail _detailWithBio(String? bio) => PublicProfileDetail(
      header: const PublicProfileHeader(id: 'u1'),
      worker: PublicWorkerInfo(bio: bio),
    );

Widget _wrap({
  required SocialProfile profile,
  PublicProfileDetail? detail,
  required bool isSelf,
  VoidCallback? onAddBio,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ProfileHeader(
        profileAsync: AsyncData<SocialProfile>(profile),
        detailAsync: AsyncData<PublicProfileDetail?>(detail),
        isSelf: isSelf,
        onAddBio: onAddBio,
      ),
    ),
  );
}

void main() {
  group('PR-A — ProfileHeader bio', () {
    testWidgets('bio doluysa header\'da görünür', (tester) async {
      await tester.pumpWidget(_wrap(
        profile: _profile,
        detail: _detailWithBio('20 yıldır ekşi mayalı ekmek üretiyorum.'),
        isSelf: false,
      ));
      expect(
        find.text('20 yıldır ekşi mayalı ekmek üretiyorum.'),
        findsOneWidget,
      );
      // Header temel alanları korunur.
      expect(find.text('Fatih Usta'), findsOneWidget);
      expect(find.text('Usta Fırıncı'), findsOneWidget);
      expect(find.text('Manisa'), findsOneWidget);
    });

    testWidgets('başkasının profilinde bio yoksa boş bio alanı / CTA yok',
        (tester) async {
      await tester.pumpWidget(_wrap(
        profile: _profile,
        detail: _detailWithBio(null),
        isSelf: false,
      ));
      expect(find.text(AppStrings.profileHeaderAddBioCta), findsNothing);
      // Header yine ad/meslek/şehir gösterir.
      expect(find.text('Fatih Usta'), findsOneWidget);
      expect(find.text('Usta Fırıncı'), findsOneWidget);
    });

    testWidgets('self + bio boş → /profile/cv CTA görünür ve tıklanır',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        profile: _profile,
        detail: _detailWithBio(null),
        isSelf: true,
        onAddBio: () => tapped = true,
      ));
      final cta = find.text(AppStrings.profileHeaderAddBioCta);
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('self + bio dolu → CTA yerine bio görünür', (tester) async {
      await tester.pumpWidget(_wrap(
        profile: _profile,
        detail: _detailWithBio('Manisa\'da aile fırınıyız.'),
        isSelf: true,
        onAddBio: () {},
      ));
      expect(find.text('Manisa\'da aile fırınıyız.'), findsOneWidget);
      expect(find.text(AppStrings.profileHeaderAddBioCta), findsNothing);
    });
  });
}
