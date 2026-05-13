/// Grup oluşturma form validasyonu.
class GroupValidator {
  const GroupValidator();

  static const int minLimit = 5;

  /// Grup adı boş olamaz, en az 2 karakter.
  String? validateName(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return 'Grup adı gerekli';
    if (v.length < 2) return 'Grup adı çok kısa';
    return null;
  }

  /// Açıklama boş olamaz.
  String? validateDescription(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return 'Kısa bir açıklama yaz';
    return null;
  }

  /// Limit `null` (sınırsız) ise OK; aksi halde [minLimit] altında olamaz.
  String? validateLimit(int? limit) {
    if (limit == null) return null; // sınırsız
    if (limit < minLimit) return 'En az $minLimit kişilik bir grup oluştur';
    return null;
  }
}
