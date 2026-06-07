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
  patrolTest('app boots and main navigation works', ($) async {
    await _pumpApp($);

    await $(
      AppStrings.authEntryGuest,
    ).waitUntilVisible(timeout: const Duration(seconds: 15));
    await $(AppStrings.authEntryGuest).tap();

    await $(AppStrings.feedTitle).waitUntilVisible();
    expect($('Feed'), findsOneWidget);
    expect($('Gruplar'), findsOneWidget);
    expect($('Market'), findsOneWidget);
    expect($('İlanlar'), findsOneWidget);
    expect($('Panel'), findsOneWidget);

    await $('Gruplar').tap();
    await $(AppStrings.groupsTitle).waitUntilVisible();

    await $('Market').tap();
    await $(AppStrings.marketSubtitle).waitUntilVisible();

    await $('İlanlar').tap();
    await $(AppStrings.jobsTitle).waitUntilVisible();

    await $('Panel').tap();
    await $(RegExp('^${AppStrings.panelGreetingPrefix}')).waitUntilVisible();

    await $('Feed').tap();
    await $(AppStrings.feedComposerPanelPlaceholder).waitUntilVisible();
    expect($(AppStrings.feedTitle), findsOneWidget);
  });
}
