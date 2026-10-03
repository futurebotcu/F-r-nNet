import 'package:firin_defter/core/utils/relative_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  final now = DateTime(2026, 10, 3, 15, 0);

  test('göreli zaman kademeleri', () {
    expect(
      relativeTimeTr(now.subtract(const Duration(seconds: 20)), now: now),
      'şimdi',
    );
    expect(
      relativeTimeTr(now.subtract(const Duration(minutes: 12)), now: now),
      '12 dk önce',
    );
    expect(
      relativeTimeTr(now.subtract(const Duration(hours: 3)), now: now),
      '3 sa önce',
    );
    expect(relativeTimeTr(DateTime(2026, 10, 2, 9), now: now), 'dün');
    expect(relativeTimeTr(DateTime(2026, 9, 29, 9), now: now), '4 gün önce');
    expect(relativeTimeTr(DateTime(2026, 8, 12), now: now), '12 Ağu');
    expect(relativeTimeTr(DateTime(2025, 8, 12), now: now), '12 Ağu 2025');
  });

  test('kısa biçim', () {
    expect(
      relativeTimeShortTr(now.subtract(const Duration(minutes: 5)), now: now),
      '5 dk',
    );
    expect(relativeTimeShortTr(DateTime(2026, 10, 2, 9), now: now), 'dün');
  });
}
