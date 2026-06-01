// Feed Premium Sprint — SocialComposerPage `initialType` ön-seçimi testi.
//
// Inline composer panelindeki Soru/Tarif/Duyuru aksiyonları composer'a
// `?type=` deep-link ile gider; router bunu `initialType`'a çevirir ve
// composer ilgili ChoiceChip'i seçili açar. Bu test o eşlemeyi doğrular:
//   Soru   → PostType.question (label "Soru")
//   Tarif  → PostType.production (label "Üretim")  [default ile aynı]
//   Duyuru → PostType.supply (label "Tedarik")
// initialType null → varsayılan Üretim seçili.

import 'package:firin_defter/features/feed/models/post_type.dart';
import 'package:firin_defter/features/social/composer/social_composer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(PostType? initialType) {
  return ProviderScope(
    child: MaterialApp(
      home: SocialComposerPage(initialType: initialType),
    ),
  );
}

bool _isChipSelected(WidgetTester tester, String label) {
  final chip = tester.widget<ChoiceChip>(
    find.widgetWithText(ChoiceChip, label),
  );
  return chip.selected;
}

void main() {
  group('SocialComposerPage — initialType ön-seçimi', () {
    testWidgets('null → varsayılan Üretim seçili', (tester) async {
      await tester.pumpWidget(_wrap(null));
      await tester.pump();
      expect(_isChipSelected(tester, 'Üretim'), isTrue);
      expect(_isChipSelected(tester, 'Soru'), isFalse);
    });

    testWidgets('Soru aksiyonu → question chip seçili', (tester) async {
      await tester.pumpWidget(_wrap(PostType.question));
      await tester.pump();
      expect(_isChipSelected(tester, 'Soru'), isTrue);
      expect(_isChipSelected(tester, 'Üretim'), isFalse);
    });

    testWidgets('Tarif aksiyonu → production (Üretim) chip seçili',
        (tester) async {
      await tester.pumpWidget(_wrap(PostType.production));
      await tester.pump();
      expect(_isChipSelected(tester, 'Üretim'), isTrue);
    });

    testWidgets('Duyuru aksiyonu → supply (Tedarik) chip seçili',
        (tester) async {
      await tester.pumpWidget(_wrap(PostType.supply));
      await tester.pump();
      expect(_isChipSelected(tester, 'Tedarik'), isTrue);
      expect(_isChipSelected(tester, 'Üretim'), isFalse);
    });
  });
}
