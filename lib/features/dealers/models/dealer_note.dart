/// Bayiye serbest metin notu.
///
/// Supabase şeması:
/// dealer_notes(id, dealer_id, note, created_at)
class DealerNote {
  const DealerNote({
    required this.id,
    required this.dealerId,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String dealerId;
  final String note;
  final DateTime createdAt;
}
