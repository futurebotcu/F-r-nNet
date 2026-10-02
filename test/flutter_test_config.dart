import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// Tüm testler için global kurulum: uygulama `main.dart`'ta olduğu gibi
/// Türkçe tarih biçimi verisini yükler (relativeTimeTr 7 günden eski
/// tarihlerde `DateFormat('d MMM', 'tr_TR')` kullanır).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting('tr_TR');
  await testMain();
}
