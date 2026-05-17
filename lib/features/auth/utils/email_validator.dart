/// V1.4 — RFC 6761'de reserved test TLD'leri Supabase Auth tarafında
/// `email_address_invalid` ile reddediliyor. UI bunu baştan engellesin diye
/// pure helper. Form validator ve diğer caller'lar buradan paylaşır.
const List<String> _reservedTestTlds = <String>[
  '.test',
  '.example',
  '.invalid',
  '.localhost',
];

/// `true` döner: girilen e-postanın domain bölümü reserved test TLD ile bitiyor.
/// Karşılaştırma case-insensitive ve trim uygulanır.
bool isReservedTestTldEmail(String email) {
  final lower = email.trim().toLowerCase();
  if (lower.isEmpty) return false;
  for (final tld in _reservedTestTlds) {
    if (lower.endsWith(tld)) return true;
  }
  return false;
}
