import 'package:firin_defter/app/app.dart';
import 'package:firin_defter/core/config/app_config.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
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

void main() {
  patrolTest('guest guard, empty states, and profile fallback work', ($) async {
    await _pumpApp($);

    await $(
      AppStrings.authEntryGuest,
    ).waitUntilVisible(timeout: const Duration(seconds: 15));
    await $(AppStrings.authEntryGuest).tap();

    await $(AppStrings.feedComposerPanelPlaceholder).waitUntilVisible();
    expect($(AppStrings.feedComposerActionShare).first, findsOneWidget);

    await $(AppStrings.feedComposerActionShare).first.tap();
    await $(AppStrings.authRequiredTitle).waitUntilVisible();
    expect($(AppStrings.authRequiredSignIn), findsOneWidget);
    await $(AppStrings.authRequiredKeepBrowsing).tap();
    await $(AppStrings.feedTitle).waitUntilVisible();

    await $('Market').tap();
    await $(AppStrings.marketSubtitle).waitUntilVisible();
    await $(AppStrings.marketEmptyTitle).waitUntilVisible();
    expect($(AppStrings.marketEmptyCta), findsOneWidget);

    await $('İlanlar').tap();
    await $(AppStrings.jobsTitle).waitUntilVisible();
    expect($(AppStrings.jobsSegHiring), findsOneWidget);
    expect($(AppStrings.jobsSegLooking), findsOneWidget);
    await $(AppStrings.jobOfferEmptyGuest).waitUntilVisible();

    await $(AppStrings.jobsSegLooking).tap();
    await $(AppStrings.jobsLookingEmptyGuest).waitUntilVisible();

    await $('Feed').tap();
    await $(AppStrings.feedTitle).waitUntilVisible();
    await $('M').first.tap();
    await $(AppStrings.authEntryTitle).waitUntilVisible();

    await $(AppStrings.authEntryGuest).tap();
    await $(AppStrings.feedComposerPanelPlaceholder).waitUntilVisible();
    expect($(AppStrings.feedTitle), findsOneWidget);
  });
}
