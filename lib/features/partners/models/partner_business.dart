import 'package:flutter/foundation.dart';

/// Anlaşmalı İş Yerleri V1 — dizin modeli + client-side filtre yardımcıları.
///
/// Kayıtlar yalnız backoffice/service role tarafından yazılır; client salt
/// okur (RLS: is_active=true). Bu yüzden model immutable ve fromRow-only'dir.
@immutable
class PartnerBusiness {
  const PartnerBusiness({
    required this.id,
    required this.name,
    required this.category,
    required this.city,
    required this.district,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.websiteUrl = '',
    this.mapUrl = '',
    this.benefitSummary = '',
    this.description = '',
    this.logoUrl = '',
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String category;
  final String city;
  final String district;
  final String address;
  final String phone;
  final String email;
  final String websiteUrl;
  final String mapUrl;
  final String benefitSummary;
  final String description;
  final String logoUrl;
  final int sortOrder;

  factory PartnerBusiness.fromRow(Map<String, dynamic> row) => PartnerBusiness(
    id: row['id'] as String,
    name: (row['name'] as String?) ?? '',
    category: (row['category'] as String?) ?? '',
    city: (row['city'] as String?) ?? '',
    district: (row['district'] as String?) ?? '',
    address: (row['address'] as String?) ?? '',
    phone: (row['phone'] as String?) ?? '',
    email: (row['email'] as String?) ?? '',
    websiteUrl: (row['website_url'] as String?) ?? '',
    mapUrl: (row['map_url'] as String?) ?? '',
    benefitSummary: (row['benefit_summary'] as String?) ?? '',
    description: (row['description'] as String?) ?? '',
    logoUrl: (row['logo_url'] as String?) ?? '',
    sortOrder: (row['sort_order'] as int?) ?? 0,
  );
}

/// Liste filtresi — V1'de client-side uygulanır (ilk 50 kayıt üzerinde).
/// Şehir/ilçe/kategori seçenekleri sabit Türkiye dataseti yerine AKTİF
/// kayıtlardan türetilir (kapsam kuralı: büyük ilçe dataseti eklenmez).
@immutable
class PartnerBusinessFilter {
  const PartnerBusinessFilter({
    this.city,
    this.district,
    this.category,
    this.query = '',
  });

  final String? city;
  final String? district;
  final String? category;
  final String query;

  bool get isEmpty =>
      city == null && district == null && category == null && query.isEmpty;

  PartnerBusinessFilter copyWith({
    String? Function()? city,
    String? Function()? district,
    String? Function()? category,
    String? query,
  }) => PartnerBusinessFilter(
    city: city == null ? this.city : city(),
    district: district == null ? this.district : district(),
    category: category == null ? this.category : category(),
    query: query ?? this.query,
  );

  bool matches(PartnerBusiness p) {
    if (city != null && p.city != city) return false;
    if (district != null && p.district != district) return false;
    if (category != null && p.category != category) return false;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final haystack = [
        p.name,
        p.category,
        p.city,
        p.district,
        p.benefitSummary,
        p.description,
      ].join(' ').toLowerCase();
      if (!haystack.contains(q)) return false;
    }
    return true;
  }

  List<PartnerBusiness> apply(List<PartnerBusiness> all) =>
      all.where(matches).toList(growable: false);

  /// Aktif kayıtlardan alfabetik tekil şehir listesi.
  static List<String> cityOptions(List<PartnerBusiness> all) =>
      _distinct(all.map((p) => p.city));

  /// Seçili şehre göre ilçe listesi (şehir yoksa tüm ilçeler).
  static List<String> districtOptions(
    List<PartnerBusiness> all, {
    String? city,
  }) => _distinct(
    all.where((p) => city == null || p.city == city).map((p) => p.district),
  );

  static List<String> categoryOptions(List<PartnerBusiness> all) =>
      _distinct(all.map((p) => p.category));

  static List<String> _distinct(Iterable<String> values) {
    final set = <String>{
      for (final v in values)
        if (v.trim().isNotEmpty) v.trim(),
    };
    final list = set.toList()..sort();
    return list;
  }
}

/// Destek başvuru formundaki kategori seçenekleri (V1 sabit listesi).
const List<String> kPartnerApplicationCategories = [
  'Unlu mamul ekipmanları',
  'Hammadde / tedarik',
  'Teknik servis',
  'Paketleme',
  'Lojistik',
  'Muhasebe / danışmanlık',
  'Eğitim',
  'Diğer',
];
