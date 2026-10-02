import 'package:intl/intl.dart';

/// Tek göreli zaman dili (feed, ilan, yorum, mesaj, bildirim):
///   < 1 dk   → "şimdi"
///   < 60 dk  → "12 dk önce"
///   < 24 sa  → "3 sa önce"
///   dün      → "dün"
///   < 7 gün  → "4 gün önce"
///   aynı yıl → "12 Eyl"
///   önceki   → "12 Eyl 2025"
///
/// 7 günden eski içerik gün sayısıyla değil tarihle gösterilir: "45 gün
/// önce" gibi belirsiz/eski görünen ifadeler yerine net tarih.
String relativeTimeTr(DateTime time, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final t = time.toLocal();
  final d = ref.difference(t);
  if (d.isNegative || d.inMinutes < 1) return 'şimdi';
  if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
  if (d.inHours < 24) return '${d.inHours} sa önce';
  final today = DateTime(ref.year, ref.month, ref.day);
  final day = DateTime(t.year, t.month, t.day);
  final days = today.difference(day).inDays;
  if (days <= 1) return 'dün';
  if (days < 7) return '$days gün önce';
  if (t.year == ref.year) return DateFormat('d MMM', 'tr_TR').format(t);
  return DateFormat('d MMM y', 'tr_TR').format(t);
}

/// Kısa biçim (sohbet listesi gibi dar satırlar): "şimdi", "5 dk", "3 sa",
/// "dün", "4 gün", "12 Eyl".
String relativeTimeShortTr(DateTime time, {DateTime? now}) {
  final full = relativeTimeTr(time, now: now);
  return full.endsWith(' önce') ? full.substring(0, full.length - 5) : full;
}
