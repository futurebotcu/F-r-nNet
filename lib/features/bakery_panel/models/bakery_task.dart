import 'package:flutter/foundation.dart';

/// Fırın Defteri — "Bugün ne yapacağım?" işi (bakery_tasks satırı).
@immutable
class BakeryTask {
  const BakeryTask({
    required this.id,
    required this.businessDate,
    required this.title,
    this.category = '',
    this.note = '',
    this.isDone = false,
    this.sortOrder = 0,
  });

  final String id;
  final DateTime businessDate;
  final String title;
  final String category;
  final String note;
  final bool isDone;
  final int sortOrder;

  factory BakeryTask.fromRow(Map<String, dynamic> row) => BakeryTask(
    id: row['id'] as String,
    businessDate: DateTime.parse(row['business_date'] as String),
    title: (row['title'] as String?) ?? '',
    category: (row['category'] as String?) ?? '',
    note: (row['note'] as String?) ?? '',
    isDone: (row['is_done'] as bool?) ?? false,
    sortOrder: (row['sort_order'] as int?) ?? 0,
  );
}

/// Boş gün için hızlı görev önerileri (deterministik; AI yok).
const List<String> kBakeryTaskSuggestions = [
  'Sabah kontrolü',
  'Üretim planı',
  'Eksik ürün kontrolü',
  'Sipariş hazırlığı',
  'Temizlik / kontrol',
  'Fire kontrolü',
  'Gün sonu kapatma',
];
