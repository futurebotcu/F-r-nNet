import 'package:firin_defter/app/app.dart';
import 'package:firin_defter/core/constants/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('app boots to the guest entry screen', ($) async {
    await initializeDateFormatting('tr_TR');
    await $.pumpWidgetAndSettle(const ProviderScope(child: FirinNetApp()));

    await $(
      AppStrings.authEntryGuest,
    ).waitUntilVisible(timeout: const Duration(seconds: 15));
  });
}
