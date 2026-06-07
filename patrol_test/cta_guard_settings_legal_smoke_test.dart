import 'package:firin_defter/app/app.dart';
import 'package:firin_defter/core/config/app_config.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:patrol/patrol.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _pumpApp(PatrolIntegrationTester $) async {
  await initializeDateFormatting('tr_TR');

  if (AppConfig.supabaseEnabled) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  await $.pumpWidgetAndSettle(const ProviderScope(child: FirinNetApp()));
}

Future<void> _dismissGuestGuard(PatrolIntegrationTester $) async {
  await $(AppStrings.authRequiredTitle).waitUntilVisible();
  expect($(AppStrings.authRequiredSignIn), findsOneWidget);
  await $(AppStrings.authRequiredKeepBrowsing).tap();
}

Future<void> _tapRichTextLink(PatrolIntegrationTester $, String label) async {
  final finder = find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(label),
  );
  expect(finder, findsOneWidget);

  final richText = $.tester.widget<RichText>(finder);
  final plainText = richText.text.toPlainText();
  final start = plainText.indexOf(label);
  final renderParagraph = $.tester.renderObject<RenderParagraph>(finder);
  final boxes = renderParagraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + label.length),
  );
  expect(boxes, isNotEmpty);

  final box = boxes.first;
  final localCenter = Offset(
    (box.left + box.right) / 2,
    (box.top + box.bottom) / 2,
  );
  await $.tester.tapAt(renderParagraph.localToGlobal(localCenter));
  await $.pumpAndSettle();
}

void main() {
  patrolTest('CTA guards, legal pages, and guest profile fallback work', (
    $,
  ) async {
    await _pumpApp($);

    await $(
      AppStrings.authEntryGuest,
    ).waitUntilVisible(timeout: const Duration(seconds: 15));
    await $(AppStrings.authEntryGuest).tap();
    await $(AppStrings.feedTitle).waitUntilVisible();

    await $('Gruplar').tap();
    await $(AppStrings.groupsTitle).waitUntilVisible();
    await $(AppStrings.groupActionJoin).first.tap();
    await _dismissGuestGuard($);
    await $(AppStrings.groupsTitle).waitUntilVisible();

    await $('Market').tap();
    await $(AppStrings.marketEmptyCta).waitUntilVisible();
    await $(AppStrings.marketEmptyCta).tap();
    await _dismissGuestGuard($);
    await $(AppStrings.marketSubtitle).waitUntilVisible();

    await $('İlanlar').tap();
    await $(AppStrings.jobsTitle).waitUntilVisible();
    await $(Icons.add_rounded).first.tap();
    await _dismissGuestGuard($);
    await $(AppStrings.jobsTitle).waitUntilVisible();

    await $('Feed').tap();
    await $(AppStrings.feedTitle).waitUntilVisible();
    await $('M').first.tap();
    await $(AppStrings.authEntryTitle).waitUntilVisible();

    await _tapRichTextLink($, AppStrings.legalTermsTitle);
    await $(AppStrings.legalTermsTitle).waitUntilVisible();
    await $(Icons.arrow_back_rounded).tap();
    await $(AppStrings.authEntryTitle).waitUntilVisible();

    await _tapRichTextLink($, AppStrings.legalPrivacyTitle);
    await $(AppStrings.legalPrivacyTitle).waitUntilVisible();
    await $(Icons.arrow_back_rounded).tap();
    await $(AppStrings.authEntryTitle).waitUntilVisible();

    await $(AppStrings.authEntryGuest).tap();
    await $(AppStrings.feedComposerPanelPlaceholder).waitUntilVisible();
    expect($(AppStrings.feedTitle), findsOneWidget);
  });
}
