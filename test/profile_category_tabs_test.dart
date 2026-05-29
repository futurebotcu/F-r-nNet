// Profile Visual Placement Sprint — yan yana yatay kategori tabları.
// ProfileCategoryTabs provider'sız → gerçek widget testi (yan yana kanıtı).

import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:firin_defter/features/social/profile/widgets/profile_category_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({required int index, required ValueChanged<int> onChanged}) {
  return MaterialApp(
    home: Scaffold(
      body: ProfileCategoryTabs(index: index, onChanged: onChanged),
    ),
  );
}

void main() {
  group('ProfileCategoryTabs — yan yana yatay kategoriler', () {
    testWidgets('3 kategori görünür: Gönderiler / Reçeteler / Mesleki Bilgi',
        (tester) async {
      await tester.pumpWidget(_wrap(index: 0, onChanged: (_) {}));
      expect(find.text(AppStrings.profileTabPosts), findsOneWidget);
      expect(find.text(AppStrings.profileTabRecipes), findsOneWidget);
      expect(find.text(AppStrings.profileTabCv), findsOneWidget);
    });

    testWidgets('YAN YANA: aynı satırda (aynı y), soldan sağa (artan x)',
        (tester) async {
      await tester.pumpWidget(_wrap(index: 0, onChanged: (_) {}));
      final p = tester.getCenter(find.text(AppStrings.profileTabPosts));
      final r = tester.getCenter(find.text(AppStrings.profileTabRecipes));
      final c = tester.getCenter(find.text(AppStrings.profileTabCv));

      // Artan x → soldan sağa yan yana.
      expect(p.dx < r.dx, isTrue);
      expect(r.dx < c.dx, isTrue);
      // Aynı y (±2px) → tek satır yatay; alt alta DEĞİL.
      expect((p.dy - r.dy).abs() < 2, isTrue);
      expect((r.dy - c.dy).abs() < 2, isTrue);
    });

    testWidgets('segmente dokununca onChanged doğru index ile çağrılır',
        (tester) async {
      int? changed;
      await tester.pumpWidget(_wrap(index: 0, onChanged: (i) => changed = i));
      await tester.tap(find.text(AppStrings.profileTabRecipes));
      expect(changed, 1);
      await tester.tap(find.text(AppStrings.profileTabCv));
      expect(changed, 2);
    });
  });
}
